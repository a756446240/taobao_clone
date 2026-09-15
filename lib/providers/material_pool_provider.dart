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
  /// 抓包素材自带的真实售价（v1.9.116 起持久化，0 = 未知走估价）。
  /// 推荐/收藏列表优先用它，避免估价与商品真实价差离谱。
  final double price;

  const MaterialEntry({
    required this.imagePath,
    this.title = '',
    this.bundled = false,
    this.price = 0,
  });
}

/// 商品素材池：
/// - 打包内置素材：assets/materials/ + materials.json（file/title 对照）
/// - 用户导入素材：App 文档目录 materials/（我的淘宝页"地址"按钮进入管理）
/// 每次打开 App 时，订单商品图从池中随机抽取展示。
class MaterialPoolProvider extends ChangeNotifier {
  static const _assetJson = 'assets/materials/materials.json';
  static const _titlesKey = 'material_titles'; // 用户导入素材的文件名→名称
  static const _pricesKey = 'material_prices'; // 用户导入素材的文件名→真实售价

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
          price: (m['price'] as num?)?.toDouble() ?? 0,
        ));
      }
    } catch (_) {}
    // 2. 用户导入素材（应用已保存的名称 + 真实售价）
    try {
      final titles = await _loadTitles();
      final prices = await _loadPrices();
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
          price: prices[name] ?? 0,
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

  /// 文件名 → 真实售价（抓包素材 JSON 自带 price 字段，v1.9.116 起持久化）
  static Future<Map<String, double>> _loadPrices() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_pricesKey);
      if (raw == null || raw.isEmpty) return {};
      return (jsonDecode(raw) as Map).map(
          (k, v) => MapEntry(k.toString(), (v as num).toDouble()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _savePrices(Map<String, double> prices) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_pricesKey, jsonEncode(prices));
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
      price: e.price,
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

  /// 从电脑端抓包 JSON 导入素材：[{"imageUrl":..., "title":..., "price":..., "spec":...}]
  /// 图片下载到 materials/ 目录持久化；按标题去重（已有同名的跳过）。
  /// 返回 (新增数, 跳过数, 首条错误)
  Future<(int, int, String)> importFromJson(String raw,
      {void Function(String)? onProgress}) async {
    List<dynamic> list;
    try {
      final decoded = jsonDecode(raw);
      list = decoded is List ? decoded : (decoded['materials'] as List? ?? []);
    } catch (e) {
      return (0, 0, 'JSON 解析失败：$e');
    }
    final dir = await _materialsDir();
    final titles = await _loadTitles();
    final prices = await _loadPrices();
    var added = 0, skipped = 0;
    var firstErr = '';
    for (var i = 0; i < list.length; i++) {
      final m = list[i] as Map<String, dynamic>;
      final url = m['imageUrl']?.toString() ?? '';
      final title = m['title']?.toString() ?? '';
      final price = (m['price'] as num?)?.toDouble() ?? 0;
      if (url.isEmpty) {
        skipped++;
        continue;
      }
      // 同名素材已存在（内置或导入过）→ 跳过；
      // v1.9.116：已有素材没存过真实售价而本次 JSON 带价格时，回填价格
      if (title.isNotEmpty && _entries.any((e) => e.title == title)) {
        if (price > 0) {
          final idx = _entries.indexWhere((e) => e.title == title);
          final old = _entries[idx];
          if (old.price <= 0) {
            _entries[idx] = MaterialEntry(
              imagePath: old.imagePath,
              title: old.title,
              bundled: old.bundled,
              price: price,
            );
            if (!old.bundled) prices[_fileName(old.imagePath)] = price;
          }
        }
        skipped++;
        continue;
      }
      onProgress?.call('下载素材 ${i + 1}/${list.length}…');
      try {
        final req = await HttpClient().getUrl(Uri.parse(url));
        req.headers.set('Referer', 'https://www.taobao.com/');
        req.headers.set('User-Agent',
            'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15');
        final resp = await req.close().timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) {
          skipped++;
          if (firstErr.isEmpty) firstErr = 'HTTP ${resp.statusCode}';
          continue;
        }
        final bytes = await consolidateHttpClientResponseBytes(resp);
        if (bytes.length < 500) {
          skipped++;
          continue;
        }
        var ext = '.jpg';
        final u = url.toLowerCase();
        if (u.contains('.png')) ext = '.png';
        if (u.contains('.webp')) ext = '.webp';
        final name =
            'mat_${DateTime.now().millisecondsSinceEpoch}_$added$ext';
        final f = File('${dir.path}/$name');
        await f.writeAsBytes(bytes, flush: true);
        _entries.add(MaterialEntry(imagePath: f.path, title: title, price: price));
        if (title.isNotEmpty) titles[name] = title;
        if (price > 0) prices[name] = price;
        added++;
      } catch (e) {
        skipped++;
        if (firstErr.isEmpty) firstErr = e.toString();
      }
    }
    await _saveTitles(titles);
    await _savePrices(prices);
    notifyListeners();
    return (added, skipped, firstErr);
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
      final prices = await _loadPrices();
      prices.remove(_fileName(e.imagePath));
      await _savePrices(prices);
    } catch (_) {}
    notifyListeners();
  }

  /// 随机取一条
  MaterialEntry? randomOne(Random rand) =>
      _entries.isEmpty ? null : _entries[rand.nextInt(_entries.length)];

  // ============ 购物车商品素材随机分配（图+名严格对应） ============

  /// 为购物车商品 key 列表分配素材条目：
  /// - 每次 load() 后重新随机（参与随机），会话内保持稳定
  /// - 素材数不足时循环使用；调用方在 build 中调用是安全的（不触发 notify）
  void assignCartMaterials(List<String> keys) {
    if (_entries.isEmpty || keys.isEmpty) return;
    // 清理已不存在商品的旧分配
    _cartAssignments.removeWhere((k, _) => !keys.contains(k));
    final missing = keys.where((k) => !_cartAssignments.containsKey(k)).toList();
    if (missing.isEmpty) return;
    final pool = [..._entries]..shuffle(Random());
    for (var i = 0; i < missing.length; i++) {
      _cartAssignments[missing[i]] = pool[i % pool.length];
    }
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

  /// 按商品标题估计合理市场价区间（v1.9.75：替换原纯随机 0~1200 的离谱价格）。
  /// 返回 (最低价, 最高价)，按品类关键词匹配，都不命中给日百常见区间。
  static (double, double) _priceRangeOf(String title) {
    final t = title.toLowerCase();
    bool has(List<String> kws) => kws.any((k) => t.contains(k));
    // v1.9.128 用户口径「很多离谱价格」根因有二：
    // ①高端品牌被品类区间压扁（SK-II精华落入护肤 49-229、大牌香水 159-599）
    // ②数量词倍乘 7.5x 无封顶（一箱抽纸¥299、6瓶VC¥800）
    // 对策：品牌档放最前（先命中先赢），倍乘降温+品类上限 2.2x 硬封顶
    const luxuryBeauty = [
      'sk-ii', 'skii', 'sk2', '神仙水', '前男友', '雅诗兰黛', '小棕瓶', '兰蔻', '小黑瓶',
      '海蓝之谜', 'lamer', '赫莲娜', '黑绷带', '白绷带', '绿宝瓶', '资生堂',
      '红腰子', '娇兰', '复原蜜', 'cpb', '肌肤之钥', '雪花秀', 'whoo', '天气丹',
      '拱辰享', '黛珂', '莱珀妮', 'laprairie', '希思黎', 'sisley', '修丽可',
      '法尔曼', 'valmont', '香缇卡', 'pola',
    ];
    const luxuryPerfume = [
      '香奈儿', 'chanel', '迪奥', 'dior', '爱马仕', 'hermes', '祖玛珑', '祖马龙',
      'jo malone', '汤姆福特', 'tom ford', 'creed', 'byredo', '百瑞德',
      'diptyque', '蒂普提克', '潘海利根', '马吉拉', '芦丹氏', '阿蒂仙',
      '馥马尔', '古驰', 'gucci', '宝格丽', '范思哲', '圣罗兰', 'ysl', '阿玛尼',
      'armani', '纪梵希', '罗意威', 'loewe',
    ];
    const hairPremium = [
      '卡诗', 'kerastase', '馥绿德雅', 'olaplex', '摩洛哥油', 'aveda', '艾凡达',
    ];
    if (has(luxuryBeauty)) return (269, 1399);
    if (has(luxuryPerfume)) {
      if (has(['香水', '香氛', '淡香精', '香精', 'edt', 'edp', '古龙'])) {
        return (399, 1599);
      }
      if (has(['口红', '唇釉', '唇膏', '唇泥'])) {
        return (259, 520); // 大牌口红（迪奥999 ~¥380），别给彩妆全档
      }
      return (219, 899); // 同品牌粉底/气垫等彩妆
    }
    if (has(hairPremium)) return (129, 459);
    if (has(['戴森', 'dyson'])) return (1799, 3499);
    if (has(['宙斯', 'dr.arrivo', 'drarrivo', '雅萌', 'yaman', 'tripollar',
      'silkn', '妞娃', 'newa', '初普'])) {
      return (1299, 6999); // 高端美容仪（宙斯/雅萌真价数千）
    }
    if (has(['美容仪', '射频', '按摩仪', '按摩椅', '颈椎按摩', '筋膜枪'])) {
      return (199, 1699);
    }
    if (has(['电动牙刷', '冲牙器', '剃须刀', '卷发棒', '吹风机'])) {
      return (159, 899);
    }
    if (has(['红参', '高丽参', '正官庄', '参液', '参片'])) return (159, 699);
    if (has(['燕窝', '花胶', '海参', '虫草', '西洋参', '灵芝'])) {
      return (199, 1599);
    }
    if (has(['威士忌', '白兰地', '伏特加', '朗姆', '龙舌兰', '清酒', '烧酒', '红酒', '葡萄酒', '香槟', '洋酒'])) {
      return (69, 699);
    }
    // v1.9.119 真实淘宝校准线（zirkulin蜂胶¥266、Noromega 6瓶海豹油¥2041、
    // 陪伴机器人¥9800、小青柠果汁¥78.81、fit防护乳膏¥87.81）
    if (has(['机器人'])) return (1599, 9999);
    if (has(['海豹油'])) return (399, 2299);
    if (has(['蜂胶', '润喉糖', '润嗓'])) return (39, 269);
    if (has(['口腔喷雾', '口喷', '喷剂'])) return (29, 129);
    if (has(['含片', '咀嚼片', '泡腾片'])) return (19.9, 79);
    if (has(['乳膏', '防护膏', '热身膏'])) return (39, 129);
    if (has(['果汁', '小青柠', '柠檬饮', '饮料'])) return (19.9, 89);
    if (has(['手帕纸', '抽纸', '纸巾', '湿巾', '卷纸', '棉柔巾', '洗脸巾'])) {
      return (9.9, 39.9);
    }
    if (has(['牙膏', '牙刷', '漱口水', '牙线'])) return (19, 99);
    if (has(['口罩', '消毒', '洗手'])) return (15, 69);
    if (has(['褪黑素', '睡眠糖', '助眠'])) return (69, 189);
    if (has(['氨糖', '骨胶原', '软骨素', '维骨力'])) return (109, 429);
    if (has(['辅酶', 'q10'])) return (99, 299);
    if (has(['鱼油', 'dha', '磷虾油'])) return (99, 399);
    if (has(['益生菌', '活菌', '通便', 'miralax', '酵素', '酵母'])) {
      return (69, 329);
    }
    if (has(['蛋白粉', '乳清'])) return (129, 469);
    if (has(['维生素', '钙片', '维c', ' vc', 'vc ', '维b', '甲钴胺', '叶黄素',
      '胶囊', '片剂', '保健', '护肝', '葡萄籽', '蔓越莓', '月见草'])) {
      return (59, 259);
    }
    if (has(['面膜'])) return (39, 129);
    if (has(['眼霜'])) return (89, 329);
    if (has(['面霜', '乳液', '精华', '爽肤水', '喷雾', '保湿', '护肤', '防晒', '洁面', '洗面奶', '卸妆'])) {
      return (49, 229);
    }
    if (has(['洗发水', '洗发露', '护发', '沐浴', '身体乳', '发膜', '精油', '磨砂膏'])) {
      return (39, 169);
    }
    if (has(['洗衣液', '洗洁精', '清洁剂', '洗衣凝珠'])) return (19.9, 79.9);
    if (has(['奶粉'])) return (158, 398);
    if (has(['纸尿裤', '尿不湿', '拉拉裤'])) return (69, 189);
    if (has(['香水', '香氛'])) return (159, 599);
    if (has(['口红', '唇膏', '唇釉', '粉底', '气垫', '眼影', '腮红', '彩妆', '睫毛膏', '眉笔'])) {
      return (49, 329);
    }
    if (has(['咖啡'])) return (29, 189);
    if (has(['奶茶', '茶饮', '零食', '饼干', '巧克力', '坚果', '麦片', '糖果', '软糖'])) {
      return (19.9, 99);
    }
    if (has(['眼镜', '隐形眼镜', '美瞳', '滴眼液', '人工泪液'])) return (49, 269);
    if (has(['净化器'])) return (399, 2999);
    if (has(['挂脖'])) return (29, 159);
    if (has(['保温杯', '焖烧杯', '水杯'])) return (59, 269);
    if (has(['膏', '贴'])) return (29, 89);
    return (29, 159);
  }

  /// 数量词倍乘：标题含「6瓶/2盒/3罐」等多件装时价格上浮
  /// （真实淘宝 6 瓶海豹油¥2041 vs 单瓶~¥349）。每件按 0.55 折算累进，
  /// 上限 4 倍；低价品类（区间下限<100）才乘，中高价区间本身已含多瓶装。
  /// v1.9.128 降温（原 0.72/上限7.5 会把一箱抽纸推到¥299、6瓶燕窝¥3517）；
  /// 调用处另有品类 hi×1.8 硬封顶，任何情况价格不飞出品类合理范围
  static double _qtyFactorOf(String title, double lo) {
    if (lo >= 100) return 1;
    final matches =
        RegExp(r'(\d{1,2})\s*(瓶|盒|罐|袋|支|条|件|组|箱)').allMatches(title);
    var n = 1;
    for (final m in matches) {
      final v = int.tryParse(m.group(1) ?? '1') ?? 1;
      if (v > n) n = v;
    }
    if (n <= 1) return 1;
    final f = 1 + 0.55 * (n - 1);
    return f > 4 ? 4 : f;
  }

  /// 推荐价：按标题哈希确定性取区间内的价格（同一商品各处展示一致），
  /// 尾数用 .9 / .9x 电商常见定价
  static String marketPriceOf(String title) {
    final (lo, hi) = _priceRangeOf(title);
    final h = title.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    var base = lo + (hi - lo) * (h % 1000) / 1000;
    base *= _qtyFactorOf(title, lo);
    final cap = hi * 1.8; // v1.9.128 硬封顶：倍乘后也不许飞出品类区间
    if (base > cap) base = cap;
    // 取整到个位再减 0.1，得到 x9 / x9.9 风格定价
    final whole = base.floor();
    final price = base < 100 ? whole + 0.9 * ((h ~/ 7) % 2 == 0 ? 1 : 0.9) : whole.toDouble();
    return price < 100 ? price.toStringAsFixed(2) : price.toStringAsFixed(0);
  }

  /// 真实售价格式化（抓包素材自带的 price）：去尾零，279.04→279.04、89.0→89
  static String fmtPrice(double p) {
    if (p <= 0) return '';
    final s = p.toStringAsFixed(2);
    if (s.endsWith('.00')) return s.substring(0, s.length - 3);
    if (s.endsWith('0')) return s.substring(0, s.length - 1);
    return s;
  }

  /// 素材展示价：有真实售价格式化返回，没有走品类估价（对外统一入口）
  static String displayPriceOf(MaterialEntry e) =>
      e.price > 0 ? fmtPrice(e.price) : marketPriceOf(e.title);

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
        result.add(SearchResultItem(
          imageUrl: e.imagePath,
          title: e.title,
          shopName: '${_brandOf(e.title)}${_shopSuffixes[r.nextInt(_shopSuffixes.length)]}',
          price: displayPriceOf(e),
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
