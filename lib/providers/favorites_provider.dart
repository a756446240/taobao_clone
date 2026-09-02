import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 商品收藏状态全局管理（Provider + 本地持久化）
///
/// 商品详情页收藏按钮写这里，收藏夹页读这里：
/// 一处收藏全局生效，重启 App 不丢。按商品标题作 key。
class FavoritesProvider extends ChangeNotifier {
  static const _key = 'favorite_goods_v1';

  /// title -> 商品快照（imageUrl/shopName/price/commentCount/goodRate/shipFrom）
  final Map<String, SearchResultItem> _items = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  /// 收藏的宝贝列表（最近收藏的在前）
  List<SearchResultItem> get items => _items.values.toList().reversed.toList();

  bool isFav(String title) => _items.containsKey(title);

  Map<String, dynamic> _toJson(SearchResultItem e) => {
        'imageUrl': e.imageUrl,
        'title': e.title,
        'shopName': e.shopName,
        'price': e.price,
        'commentCount': e.commentCount,
        'goodRate': e.goodRate,
        'shipFrom': e.shipFrom,
      };

  SearchResultItem _fromJson(Map<String, dynamic> j) => SearchResultItem(
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
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in map.entries) {
          _items[entry.key] =
              _fromJson(Map<String, dynamic>.from(entry.value as Map));
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
        jsonEncode({for (final e in _items.entries) e.key: _toJson(e.value)}),
      );
    } catch (_) {}
  }

  /// 切换收藏，返回切换后的收藏状态
  bool toggle(SearchResultItem item) {
    final now = !_items.containsKey(item.title);
    if (now) {
      _items[item.title] = item;
    } else {
      _items.remove(item.title);
    }
    notifyListeners();
    _save();
    return now;
  }

  void remove(String title) {
    if (_items.remove(title) != null) {
      notifyListeners();
      _save();
    }
  }
}
