import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/doc_paths.dart';

/// 商品图片替换 Provider：
/// 长按商品图从相册选择新图后，以商品标题为 key 持久化本地文件路径，
/// 重启 App 后依然生效。
///
/// v1.9.102：持久化一律存「相对 Documents 的路径」（如 order_images/xx.jpg），
/// 加载时用当前沙盒根目录现场拼绝对路径——iOS 自签重装容器 UUID 变化后
/// 旧绝对路径全部失效，这是"更新 IPA 后手动换的图全丢"的根因。
/// 旧数据（绝对路径）加载时自动迁移：抠出已知子目录部分转相对路径。
class ProductImageProvider extends ChangeNotifier {
  static const _prefKey = 'product_image_overrides';

  /// title -> 本地文件路径（存储为相对 Documents 路径）
  final Map<String, String> _overrides = {};

  Map<String, String> get overrides => Map.unmodifiable(_overrides);

  /// 根据 title 获取替换后的图片路径（无替换则返回 null）
  /// 返回值可直接喂给 AppImage（它会现场解析相对路径）
  String? imageFor(String title) => _overrides[title];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _overrides.clear();
        var migrated = false;
        map.forEach((k, v) {
          final rel = DocPaths.relativize(v.toString());
          if (rel != v.toString()) migrated = true;
          // 用当前沙盒根目录解析后校验文件是否还在
          if (File(DocPaths.resolve(rel)).existsSync()) {
            _overrides[k] = rel;
          }
        });
        // 有旧绝对路径被迁移时立即回写，避免每次启动重复迁移
        if (migrated) {
          await prefs.setString(_prefKey, jsonEncode(_overrides));
        }
      }
    } catch (_) {
      // 忽略反序列化失败
    }
    notifyListeners();
  }

  Future<void> setOverride(String title, String filePath) async {
    // 存相对路径：自签重装后依然能解析回正确位置
    _overrides[title] = DocPaths.relativize(filePath);
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
