import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 一条足迹：商品 + 浏览时间戳
class Footprint {
  final SearchResultItem item;
  final int ts; // millisecondsSinceEpoch
  const Footprint(this.item, this.ts);
}

/// 浏览足迹全局管理（Provider + 本地持久化）
///
/// 进入商品详情页即记录（同标题去重提前），足迹页按日期分组展示，
/// 重启 App 不丢，上限 200 条。
class FootprintsProvider extends ChangeNotifier {
  static const _key = 'footprints_v1';
  static const _cap = 200;

  final List<Footprint> _records = [];
  bool _loaded = false;

  bool get loaded => _loaded;

  /// 最近的足迹在前
  List<Footprint> get records => List.unmodifiable(_records);

  Map<String, dynamic> _itemToJson(SearchResultItem e) => {
        'imageUrl': e.imageUrl,
        'title': e.title,
        'shopName': e.shopName,
        'price': e.price,
        'commentCount': e.commentCount,
        'goodRate': e.goodRate,
        'shipFrom': e.shipFrom,
      };

  SearchResultItem _itemFromJson(Map<String, dynamic> j) => SearchResultItem(
        imageUrl: j['imageUrl'] ?? '',
        title: j['title'] ?? '',
        shopName: j['shopName'] ?? '',
        price: j['price'] ?? '0',
        commentCount: j['commentCount'] ?? '',
        goodRate: j['goodRate'] ?? '',
        shipFrom: j['shipFrom'] ?? '',
      );

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final r in list) {
          final m = Map<String, dynamic>.from(r as Map);
          _records.add(Footprint(
            _itemFromJson(Map<String, dynamic>.from(m['item'] as Map)),
            m['ts'] as int? ?? 0,
          ));
        }
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(
        _key,
        jsonEncode([
          for (final r in _records)
            {'item': _itemToJson(r.item), 'ts': r.ts},
        ]),
      );
    } catch (_) {}
  }

  /// 记录一次浏览（同标题去重提前，时间刷新为当前）
  void add(SearchResultItem item) {
    _records.removeWhere((r) => r.item.title == item.title);
    _records.insert(
        0, Footprint(item, DateTime.now().millisecondsSinceEpoch));
    if (_records.length > _cap) {
      _records.removeRange(_cap, _records.length);
    }
    notifyListeners();
    _save();
  }

  void clear() {
    if (_records.isEmpty) return;
    _records.clear();
    notifyListeners();
    _save();
  }
}
