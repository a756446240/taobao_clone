import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 商品图片替换 Provider：
/// 长按商品图从相册选择新图后，以商品标题为 key 持久化本地文件路径，
/// 重启 App 后依然生效。
class ProductImageProvider extends ChangeNotifier {
  static const _prefKey = 'product_image_overrides';

  /// title -> 本地文件路径
  final Map<String, String> _overrides = {};

  Map<String, String> get overrides => Map.unmodifiable(_overrides);

  /// 根据 title 获取替换后的图片路径（无替换则返回 null）
  String? imageFor(String title) => _overrides[title];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        // 清理已不存在的文件
        _overrides
          ..clear()
          ..addAll(map.map((k, v) => MapEntry(k, v.toString())));
        _overrides.removeWhere((_, path) => !File(path).existsSync());
      }
    } catch (_) {
      // 忽略反序列化失败
    }
    notifyListeners();
  }

  Future<void> setOverride(String title, String filePath) async {
    _overrides[title] = filePath;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_overrides));
    } catch (_) {}
  }

  Future<void> removeOverride(String title) async {
    _overrides.remove(title);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_overrides));
    } catch (_) {}
  }
}
