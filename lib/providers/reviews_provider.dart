import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户发布的一条评价（发表评价页写入，商品评价列表页展示）
class UserReview {
  final String productTitle; // 关联商品标题
  final String shopName; // 店铺名
  final String content; // 评价正文
  final int stars; // 综合星级（三项取平均，四舍五入）
  final String spec; // 规格
  final List<String> photoPaths; // 晒图本地路径
  final bool anonymous; // 是否匿名
  final int createdAt; // 发布时间（毫秒时间戳）

  const UserReview({
    required this.productTitle,
    required this.shopName,
    required this.content,
    required this.stars,
    required this.spec,
    required this.photoPaths,
    required this.anonymous,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'productTitle': productTitle,
        'shopName': shopName,
        'content': content,
        'stars': stars,
        'spec': spec,
        'photoPaths': photoPaths,
        'anonymous': anonymous,
        'createdAt': createdAt,
      };

  factory UserReview.fromJson(Map<String, dynamic> j) => UserReview(
        productTitle: j['productTitle'] ?? '',
        shopName: j['shopName'] ?? '',
        content: j['content'] ?? '',
        stars: j['stars'] ?? 5,
        spec: j['spec'] ?? '',
        photoPaths: (j['photoPaths'] as List? ?? [])
            .map((e) => e.toString())
            .toList(),
        anonymous: j['anonymous'] ?? true,
        createdAt: j['createdAt'] ?? 0,
      );
}

/// 全局用户评价库：发布后立即出现在商品评价列表，重启不丢
class ReviewsProvider extends ChangeNotifier {
  static const _key = 'user_reviews_v1';

  final List<UserReview> _reviews = [];

  /// 某商品的用户评价（最新在前）
  List<UserReview> reviewsFor(String productTitle) => _reviews
      .where((r) => r.productTitle == productTitle)
      .toList(growable: false);

  /// 全部用户评价（最新在前，供"我的评价"页展示）
  List<UserReview> get all => List.unmodifiable(_reviews);

  /// 发布一条评价
  void add(UserReview r) {
    _reviews.insert(0, r);
    notifyListeners();
    _save();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => UserReview.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _reviews
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _key, jsonEncode(_reviews.map((e) => e.toJson()).toList()));
  }
}
