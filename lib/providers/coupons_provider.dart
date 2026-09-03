import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 已领取的优惠券（领券中心 / 二楼福利券共用）
class ClaimedCoupon {
  final String value; // 面额数字，如 61
  final String name; // 名称，如 消费券 / 二楼狂欢券
  final String condition; // 门槛，如 满599元可用
  final String scope; // 使用范围
  final String expiry; // 有效期文案
  final int bg; // 面额块背景色值
  final int fg; // 面额块前景色值
  final int claimedAt; // 领取时间（毫秒时间戳）

  const ClaimedCoupon({
    required this.value,
    required this.name,
    required this.condition,
    required this.scope,
    required this.expiry,
    required this.bg,
    required this.fg,
    required this.claimedAt,
  });

  Map<String, dynamic> toJson() => {
        'value': value,
        'name': name,
        'condition': condition,
        'scope': scope,
        'expiry': expiry,
        'bg': bg,
        'fg': fg,
        'claimedAt': claimedAt,
      };

  factory ClaimedCoupon.fromJson(Map<String, dynamic> j) => ClaimedCoupon(
        value: j['value'] ?? '',
        name: j['name'] ?? '',
        condition: j['condition'] ?? '',
        scope: j['scope'] ?? '',
        expiry: j['expiry'] ?? '',
        bg: j['bg'] ?? 0xFFFFF1E8,
        fg: j['fg'] ?? 0xFFFF5000,
        claimedAt: j['claimedAt'] ?? 0,
      );
}

/// 全局卡券包：跨页面共享领取状态，重启不丢
class CouponsProvider extends ChangeNotifier {
  static const _key = 'claimed_coupons_v1';

  /// 领券中心预置券目录（claimedAt=0 表示未领取）。
  /// 领券中心 / 购物车券条 / AI 省钱助手共用同一份数据，不再各写各的文案。
  static const catalog = <ClaimedCoupon>[
    ClaimedCoupon(
        value: '61',
        name: '消费券',
        condition: '满599元可用',
        scope: '全平台实物商品通用',
        expiry: '领取后 3 天内有效',
        bg: 0xFFFFF1E8,
        fg: 0xFFFF5000,
        claimedAt: 0),
    ClaimedCoupon(
        value: '10',
        name: '超市加补券',
        condition: '满99元可用',
        scope: '天猫超市指定商品',
        expiry: '领取后 7 天内有效',
        bg: 0xFFE8F8EE,
        fg: 0xFF12A150,
        claimedAt: 0),
    ClaimedCoupon(
        value: '50',
        name: '珠宝加补券',
        condition: '满999元可用',
        scope: '珠宝配饰类目指定商品',
        expiry: '领取后 7 天内有效',
        bg: 0xFFF3EBFF,
        fg: 0xFF7C3AED,
        claimedAt: 0),
    ClaimedCoupon(
        value: '45',
        name: '玩具加补券',
        condition: '满399元可用',
        scope: '玩具乐器类目指定商品',
        expiry: '领取后 7 天内有效',
        bg: 0xFFE8F1FF,
        fg: 0xFF2B6DEF,
        claimedAt: 0),
    ClaimedCoupon(
        value: '20',
        name: '服饰加补券',
        condition: '满199元可用',
        scope: '服饰鞋包类目指定商品',
        expiry: '领取后 5 天内有效',
        bg: 0xFFFFEEF3,
        fg: 0xFFE03A6C,
        claimedAt: 0),
    ClaimedCoupon(
        value: '30',
        name: '数码加补券',
        condition: '满599元可用',
        scope: '手机数码类目指定商品',
        expiry: '领取后 5 天内有效',
        bg: 0xFFE8F7FA,
        fg: 0xFF0E8A9E,
        claimedAt: 0),
  ];

  final List<ClaimedCoupon> _claimed = [];
  List<ClaimedCoupon> get claimed => List.unmodifiable(_claimed);

  /// 是否已领过同名同面额的券（防重复领取）
  bool isClaimed(String name, String value) =>
      _claimed.any((c) => c.name == name && c.value == value);

  /// 目录中尚未领取的券
  List<ClaimedCoupon> get unclaimed =>
      catalog.where((c) => !isClaimed(c.name, c.value)).toList();

  /// 领取一张券；重复领取返回 false
  bool claim(ClaimedCoupon c) {
    if (isClaimed(c.name, c.value)) return false;
    _claimed.insert(0, c);
    notifyListeners();
    _save();
    return true;
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => ClaimedCoupon.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _claimed
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _key, jsonEncode(_claimed.map((e) => e.toJson()).toList()));
  }
}
