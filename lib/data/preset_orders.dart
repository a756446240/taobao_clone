import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/models.dart';
import '../providers/persistence_service.dart';

/// 预置订单加载器
/// 打包时把 assets/data/preset_orders.json 内置进 App。
/// 支持两种格式：
///   1) 纯数组 [shop, shop, ...]（旧版，version 视为 0）
///   2) {"version": 1, "orders": [shop, ...]}（带版本号，供增量导入）
/// 首次启动（本地无持久化数据）时优先加载预置订单；
/// 老用户启动时由 CartProvider 按版本号增量合并新订单。
class PresetOrders {
  PresetOrders._();

  static const String _assetPath = 'assets/data/preset_orders.json';

  /// 预置数据（版本号 + 店铺列表）
  static Future<({int version, List<ShoppingCartShop> shops})?>
      loadWithVersion() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      int version = 0;
      List<dynamic> list;
      if (decoded is Map<String, dynamic>) {
        version = (decoded['version'] as num?)?.toInt() ?? 0;
        final orders = decoded['orders'];
        if (orders is! List) return null;
        list = orders;
      } else if (decoded is List) {
        list = decoded;
      } else {
        return null;
      }
      if (list.isEmpty) return null;
      final shops = list
          .map((e) => PersistenceService.shopFromJson(e as Map<String, dynamic>))
          .toList();
      // 过滤掉没有任何商品的店铺
      final valid = shops.where((s) => s.items.isNotEmpty).toList();
      if (valid.isEmpty) return null;
      return (version: version, shops: valid);
    } catch (_) {
      return null;
    }
  }

  /// 返回 null 表示没有可用预置数据（旧接口，首装全量加载用）
  static Future<List<ShoppingCartShop>?> tryLoad() async {
    final data = await loadWithVersion();
    return data?.shops;
  }
}
