import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 首页 banner 素材池（与商品素材池完全独立，不接 AI 素材，全部由用户导入）：
/// - 用户导入的 banner 存应用文档目录 banner_materials/
/// - 双击首页 banner 进入管理页，增删后首页按素材数量轮播滚动
/// - 池为空时首页回退展示内置大促 banner，避免空白
class BannerPoolProvider extends ChangeNotifier {
  final List<String> _entries = [];
  bool _loading = true;

  List<String> get entries => List.unmodifiable(_entries);
  bool get loading => _loading;

  Future<void> load() async {
    _entries.clear();
    try {
      final dir = await _bannerDir();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => _isImage(f.path))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      _entries.addAll(files.map((f) => f.path));
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  static bool _isImage(String p) {
    final s = p.toLowerCase();
    return s.endsWith('.jpg') ||
        s.endsWith('.jpeg') ||
        s.endsWith('.png') ||
        s.endsWith('.webp');
  }

  static Future<Directory> _bannerDir() async {
    final doc = await getApplicationDocumentsDirectory();
    final dir = Directory('${doc.path}/banner_materials');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 从相册多选导入 banner，返回成功导入数量
  Future<int> importFromGallery() async {
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isEmpty) return 0;
      final dir = await _bannerDir();
      var count = 0;
      for (final x in picked) {
        final ext = x.path.contains('.')
            ? x.path.substring(x.path.lastIndexOf('.'))
            : '.jpg';
        final name = 'banner_${DateTime.now().millisecondsSinceEpoch}_$count$ext';
        await File(x.path).copy('${dir.path}/$name');
        _entries.add('${dir.path}/$name');
        count++;
      }
      notifyListeners();
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// 删除一条 banner 素材
  Future<void> remove(String path) async {
    _entries.remove(path);
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {}
    notifyListeners();
  }
}
