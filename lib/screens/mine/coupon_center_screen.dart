import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 优惠券条目
class _Coupon {
  final String value; // 面额，如 ¥61
  final String name; // 名称，如 消费券
  final String condition; // 门槛，如 满599元可用
  final String scope; // 使用范围
  final String expiry; // 有效期
  final Color bg;
  final Color fg;
  bool claimed = false;

  _Coupon({
    required this.value,
    required this.name,
    required this.condition,
    required this.scope,
    required this.expiry,
    required this.bg,
    required this.fg,
  });
}

/// 淘宝式领券中心完整页：精选好券 / 已领取 双 Tab
class CouponCenterScreen extends StatefulWidget {
  const CouponCenterScreen({super.key});

  @override
  State<CouponCenterScreen> createState() => _CouponCenterScreenState();
}

class _CouponCenterScreenState extends State<CouponCenterScreen> {
  int _tab = 0; // 0=精选好券 1=已领取

  final List<_Coupon> _coupons = [
    _Coupon(
        value: '61',
        name: '消费券',
        condition: '满599元可用',
        scope: '全平台实物商品通用',
        expiry: '领取后 3 天内有效',
        bg: const Color(0xFFFFF1E8),
        fg: const Color(0xFFFF5000)),
    _Coupon(
        value: '10',
        name: '超市加补券',
        condition: '满99元可用',
        scope: '天猫超市指定商品',
        expiry: '领取后 7 天内有效',
        bg: const Color(0xFFE8F8EE),
        fg: const Color(0xFF12A150)),
    _Coupon(
        value: '50',
        name: '珠宝加补券',
        condition: '满999元可用',
        scope: '珠宝配饰类目指定商品',
        expiry: '领取后 7 天内有效',
        bg: const Color(0xFFF3EBFF),
        fg: const Color(0xFF7C3AED)),
    _Coupon(
        value: '45',
        name: '玩具加补券',
        condition: '满399元可用',
        scope: '玩具乐器类目指定商品',
        expiry: '领取后 7 天内有效',
        bg: const Color(0xFFE8F1FF),
        fg: const Color(0xFF2B6DEF)),
    _Coupon(
        value: '20',
        name: '服饰加补券',
        condition: '满199元可用',
        scope: '服饰鞋包类目指定商品',
        expiry: '领取后 5 天内有效',
        bg: const Color(0xFFFFEEF3),
        fg: const Color(0xFFE03A6C)),
    _Coupon(
        value: '30',
        name: '数码加补券',
        condition: '满599元可用',
        scope: '手机数码类目指定商品',
        expiry: '领取后 5 天内有效',
        bg: const Color(0xFFE8F7FA),
        fg: const Color(0xFF0E8A9E)),
  ];

  List<_Coupon> get _available => _coupons.where((c) => !c.claimed).toList();
  List<_Coupon> get _claimed => _coupons.where((c) => c.claimed).toList();

  void _claim(_Coupon c) {
    setState(() => c.claimed = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${c.name} ¥${c.value} 领取成功，已放入卡券包'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _tab == 0 ? _available : _claimed;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('领券中心',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: list.isEmpty
                ? _empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _couponCard(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          _tabCapsule('精选好券', 0, count: _available.length),
          const SizedBox(width: 8),
          _tabCapsule('已领取', 1, count: _claimed.length),
        ],
      ),
    );
  }

  Widget _tabCapsule(String label, int index, {required int count}) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 券卡：左面额块 + 中信息 + 右按钮
  Widget _couponCard(_Coupon c) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧面额
            Container(
              width: 96,
              color: c.bg,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('¥',
                          style: TextStyle(
                              color: c.fg,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text(c.value,
                          style: TextStyle(
                              color: c.fg,
                              fontSize: 30,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                  Text(c.condition,
                      style: TextStyle(
                          color: c.fg.withValues(alpha: 0.7), fontSize: 10)),
                ],
              ),
            ),
            // 中间信息
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(c.scope,
                        style: const TextStyle(
                            color: Color(0xFF999999), fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(c.expiry,
                        style: const TextStyle(
                            color: Color(0xFFBBBBBB), fontSize: 10)),
                  ],
                ),
              ),
            ),
            // 右侧按钮
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: c.claimed
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text('去使用',
                            style: TextStyle(color: c.fg, fontSize: 12)),
                      )
                    : GestureDetector(
                        onTap: () => _claim(c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: c.fg,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Text('立即领取',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.confirmation_number_outlined,
              color: Colors.grey.shade300, size: 64),
          const SizedBox(height: 12),
          Text(_tab == 0 ? '好券已被抢光，明天再来看看' : '还没有已领取的券',
              style:
                  const TextStyle(color: Color(0xFF999999), fontSize: 13)),
        ],
      ),
    );
  }
}
