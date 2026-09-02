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

  final List<ClaimedCoupon> _claimed = [];
  List<ClaimedCoupon> get claimed => List.unmodifiable(_claimed);

  /// 是否已领过同名同面额的券（防重复领取）
  bool isClaimed(String name, String value) =>
      _claimed.any((c) => c.name == name && c.value == value);

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
