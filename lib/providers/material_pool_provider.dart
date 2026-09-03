import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/doubao_service.dart';
import '../data/mock_data.dart';
import '../models/models.dart';

/// 素材条目：一张商品图 + 可选的对应商品名称
class MaterialEntry {
  final String imagePath; // assets/... 或本地文件绝对路径
  final String title; // 空串表示未匹配名称（沿用原商品名）
  final bool bundled; // 是否打包内置（内置不可删除）

  const MaterialEntry({
    required this.imagePath,
    this.title = '',
    this.bundled = false,
  });
}

/// 商品素材池：
/// - 打包内置素材：assets/materials/ + materials.json（file/title 对照）
/// - 用户导入素材：App 文档目录 materials/（我的淘宝页"地址"按钮进入管理）
/// 每次打开 App 时，订单商品图从池中随机抽取展示。
class MaterialPoolProvider extends ChangeNotifier {
  static const _assetJson = 'assets/materials/materials.json';
  static const _titlesKey = 'material_titles'; // 用户导入素材的文件名→名称

  final List<MaterialEntry> _entries = [];
  bool _loading = true;

  /// 豆包批量命名进度（null = 未在跑）
  String? aiProgress;

  /// 购物车商品 → 素材条目的会话级分配（key 为订单编号，图+名严格对应）
  final Map<String, MaterialEntry> _cartAssignments = {};

  /// 正在 AI 识别中的素材路径（防止购物车重复触发）
  final Set<String> _aiInFlight = {};

  /// 已识别失败过的素材路径（未配置 Key 等情况，避免每次构建都重试）
  final Set<String> _aiFailed = {};

  List<MaterialEntry> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;
  bool get isEmpty => _entries.isEmpty;

  Future<void> load() async {
    _entries.clear();
    _cartAssignments.clear();
    // 1. 打包内置素材（含名称对照）
    try {
      final raw = await rootBundle.loadString(_assetJson);
      final list = jsonDecode(raw) as List;
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final file = m['file']?.toString() ?? '';
        if (file.isEmpty) continue;
        _entries.add(MaterialEntry(
          imagePath: 'assets/materials/$file',
          title: m['title']?.toString() ?? '',
          bundled: true,
        ));
      }
    } catch (_) {}
    // 2. 用户导入素材（应用已保存的名称）
    try {
      final titles = await _loadTitles();
      final dir = await _materialsDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => _isImage(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final f in files) {
        final name = f.uri.pathSegments.last;
        _entries.add(MaterialEntry(
          imagePath: f.path,
          title: titles[name] ?? '',
        ));
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  static Future<Map<String, String>> _loadTitles() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_titlesKey);
      if (raw == null || raw.isEmpty) return {};
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveTitles(Map<String, String> titles) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_titlesKey, jsonEncode(titles));
  }

  static String _fileName(String path) =>
      path.replaceAll('\\', '/').split('/').last;

  /// 设置某条素材的名称（内置素材只改内存，导入素材会持久化）
  Future<void> setTitle(MaterialEntry e, String title) async {
    final i = _entries.indexOf(e);
    if (i < 0) return;
    _entries[i] = MaterialEntry(
      imagePath: e.imagePath,
      title: title,
      bundled: e.bundled,
    );
    if (!e.bundled) {
      final titles = await _loadTitles();
      titles[_fileName(e.imagePath)] = title;
      await _saveTitles(titles);
    }
    notifyListeners();
  }

  /// 用豆包视觉模型给所有"没有名称"的素材批量命名。
  /// 返回 (成功数, 失败数, 首条错误消息)
  Future<(int, int, String)> aiNameUntitled() async {
    final targets =
        _entries.where((e) => e.title.isEmpty).toList(growable: false);
    if (targets.isEmpty) return (0, 0, '所有素材都已有名称');
    var ok = 0, fail = 0;
    var firstErr = '';
    for (var i = 0; i < targets.length; i++) {
      final e = targets[i];
      aiProgress = '豆包识别中 ${i + 1}/${targets.length}…';
      notifyListeners();
      try {
        final name = await DoubaoService.recognizeProductName(e.imagePath);
        await setTitle(e, name);
        ok++;
      } catch (err) {
        fail++;
        if (firstErr.isEmpty) firstErr = err.toString();
        // Key 无效/欠费这类错误没必要继续刷
        final msg = err.toString();
        if (msg.contains('401') ||
            msg.contains('403') ||
            msg.contains('API Key') ||
            msg.contains('余额') ||
            msg.contains('quota')) {
          break;
        }
      }
    }
    aiProgress = null;
    notifyListeners();
    return (ok, fail, firstErr);
  }

  static bool _isImage(String p) {
    final s = p.toLowerCase();
    return s.endsWith('.jpg') ||
        s.endsWith('.jpeg') ||
        s.endsWith('.png') ||
        s.endsWith('.webp');
  }

  static Future<Directory> _materialsDir() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory('${doc.path}/materials');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 从相册多选导入，返回成功导入数量
  Future<int> importFromGallery() async {
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return 0;
      final dir = await _materialsDir();
      var count = 0;
      for (final x in picked) {
        final ext = x.path.contains('.')
            ? x.path.substring(x.path.lastIndexOf('.'))
            : '.jpg';
        final name = 'mat_${DateTime.now().millisecondsSinceEpoch}_$count$ext';
        await File(x.path).copy('${dir.path}/$name');
        _entries.add(MaterialEntry(imagePath: '${dir.path}/$name'));
        count++;
      }
      notifyListeners();
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// 删除一条素材（仅用户导入的可删）
  Future<void> remove(MaterialEntry e) async {
    if (e.bundled) return;
    _entries.remove(e);
    try {
      final f = File(e.imagePath);
      if (f.existsSync()) await f.delete();
      final titles = await _loadTitles();
      titles.remove(_fileName(e.imagePath));
      await _saveTitles(titles);
    } catch (_) {}
    notifyListeners();
  }

  /// 随机取一条
  MaterialEntry? randomOne(Random rand) =>
      _entries.isEmpty ? null : _entries[rand.nextInt(_entries.length)];

  // ============ 购物车商品素材随机分配（图+名严格对应） ============

  /// 为购物车商品 key 列表分配素材条目：
  /// - 洗牌种子按待分配 key + 素材池规模确定性派生，跨重启分配结果一致
  /// - 素材数不足时循环使用；调用方在 build 中调用是安全的（不触发 notify）
  void assignCartMaterials(List<String> keys) {
    if (_entries.isEmpty || keys.isEmpty) return;
    // 清理已不存在商品的旧分配
    _cartAssignments.removeWhere((k, _) => !keys.contains(k));
    final missing = keys.where((k) => !_cartAssignments.containsKey(k)).toList();
    if (missing.isEmpty) return;
    final pool = [..._entries]..shuffle(Random(_assignSeed(missing)));
    for (var i = 0; i < missing.length; i++) {
      _cartAssignments[missing[i]] = pool[i % pool.length];
    }
  }

  /// 分配种子：素材池规模与待分配 key 内容共同决定
  int _assignSeed(List<String> keys) {
    var h = _entries.length * 31 + 7;
    for (final k in keys) {
      for (final c in k.codeUnits) {
        h = (h * 31 + c) & 0x7fffffff;
      }
    }
    return h;
  }

  /// 取某个购物车商品分配到的素材（未分配返回 null）
  MaterialEntry? cartMaterialFor(String key) => _cartAssignments[key];

  /// 单条素材 AI 命名（购物车商品图自动匹配名称用）：
  /// 识别中/已失败/已有名称的跳过；成功后会 notifyListeners 刷新界面
  Future<void> aiNameEntry(MaterialEntry e) async {
    if (e.title.isNotEmpty) return;
    if (_aiFailed.contains(e.imagePath)) return;
    if (!_aiInFlight.add(e.imagePath)) return;
    try {
      final name = await DoubaoService.recognizeProductName(e.imagePath);
      if (name.isNotEmpty) await setTitle(e, name);
    } catch (_) {
      // 未配置 Key / 网络错误：记录失败避免每次构建重试，界面保留原标题
      _aiFailed.add(e.imagePath);
    } finally {
      _aiInFlight.remove(e.imagePath);
    }
  }

  static const _shopSuffixes = ['官方旗舰店', '旗舰店', '海外旗舰店', '专营店'];
  static const _sales = [
    '已售1万+',
    '已售8000+',
    '已售5000+',
    '2000人付款',
    '500人付款',
    '全网热销100+',
  ];

  /// 从素材标题猜品牌词（英文取首单词，中文取前 2-4 字）
  static String _brandOf(String title) {
    final t = title.trim();
    final m = RegExp(r'^[A-Za-z][A-Za-z0-9\-]+').firstMatch(t);
    if (m != null) return m.group(0)!;
    final runes = t.runes.take(4).toList();
    return String.fromCharCodes(runes.take(runes.length > 3 ? 3 : runes.length));
  }

  /// 品牌词（对外暴露：我的淘宝-我的收藏列表等复用）
  static String brandOf(String title) => _brandOf(title);

  /// 推荐区商品流：优先用素材池（图+名严格对应，按名称去重），不足时用内置 mock 补齐
  List<SearchResultItem> recommendGoods(int count, {Random? rand}) {
    final r = rand ?? Random();
    // 推荐流顺手渐进触发未命名素材的 AI 起名（每次最多 3 条，识别中/失败过的自动跳过；
    // 不 await，识别完成后 setTitle → notifyListeners 会自动刷新界面）
    for (final e
        in _entries.where((e) => e.title.isEmpty).take(3)) {
      // ignore: unawaited_futures
      aiNameEntry(e);
    }
    final pool = _entries.where((e) => e.title.isNotEmpty).toList()
      ..shuffle(r);
    // 同名素材只保留一条（内置与用户导入可能重复）
    final seen = <String>{};
    final unique = pool.where((e) => seen.add(e.title)).toList();
    final result = <SearchResultItem>[];
    final usedMock = <int>{};
    for (var i = 0; i < count; i++) {
      if (i < unique.length) {
        final e = unique[i];
        final price = (3 + r.nextInt(3000)) / 10 + r.nextInt(900);
        result.add(SearchResultItem(
          imageUrl: e.imagePath,
          title: e.title,
          shopName: '${_brandOf(e.title)}${_shopSuffixes[r.nextInt(_shopSuffixes.length)]}',
          price: price.toStringAsFixed(price < 100 ? 2 : 1),
          commentCount: _sales[r.nextInt(_sales.length)],
          goodRate: '${96 + r.nextInt(4)}%好评',
        ));
      } else {
        // mock 补齐时也避免重复同一条
        var idx = r.nextInt(MockData.guessLikeGoods.length);
        if (usedMock.length < MockData.guessLikeGoods.length) {
          while (usedMock.contains(idx)) {
            idx = r.nextInt(MockData.guessLikeGoods.length);
          }
        }
        usedMock.add(idx);
        result.add(MockData.guessLikeGoods[idx]);
      }
    }
    return result;
  }
}
