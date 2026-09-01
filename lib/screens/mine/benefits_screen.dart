import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'coupon_center_screen.dart';

/// 我的权益钱包页（我的页钱包区/全部权益/领红包 Banner 入口）
/// 5 个标签：红包 / 优惠券 / 淘金币 / 天猫积分 / 充值金
class BenefitsScreen extends StatefulWidget {
  /// 初始标签：0 红包 / 1 优惠券 / 2 淘金币 / 3 天猫积分 / 4 充值金
  final int initialIndex;

  const BenefitsScreen({super.key, this.initialIndex = 0});

  @override
  State<BenefitsScreen> createState() => _BenefitsScreenState();
}

class _BenefitsScreenState extends State<BenefitsScreen> {
  static const _tabs = ['红包', '优惠券', '淘金币', '天猫积分', '充值金'];

  late int _tab = widget.initialIndex.clamp(0, _tabs.length - 1);
  bool _signedIn = false; // 淘金币今日签到状态

  // ============ 数据（稳定）============
  static const _redPackets = [
    ('¥2.88', '无门槛红包', '全场通用', '有效期至 09-05', true),
    ('¥5.00', '满59元可用', '部分商品可用', '有效期至 09-10', true),
    ('¥8.88', '满99元可用', '大促专享', '有效期至 09-15', true),
    ('¥1.68', '无门槛红包', '全场通用', '已过期', false),
  ];

  static const _myCoupons = [
    ('¥10', '无门槛优惠券', '全场通用 · 本周日到期'),
    ('¥20', '满199减20', '服饰美妆类目可用 · 09-12 到期'),
    ('¥5', '满39减5', '食品类目可用 · 09-08 到期'),
  ];

  static const _coinRecords = [
    ('每日签到', '+10', '今天'),
    ('购物返利', '+26', '昨天'),
    ('逛会场任务', '+15', '昨天'),
    ('金币抵扣', '-130', '09-01'),
    ('每日签到', '+10', '09-01'),
  ];

  static const _pointRecords = [
    ('购物返积分', '+5', '昨天'),
    ('签到抽奖', '+2', '09-01'),
    ('积分兑换优惠券', '-20', '08-30'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('全部权益', style: AppTextStyles.appBarTitleBlack),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: switch (_tab) {
              0 => _buildRedPacketTab(),
              1 => _buildCouponTab(),
              2 => _buildCoinTab(),
              3 => _buildPointTab(),
              _ => _buildRechargeTab(),
            },
          ),
        ],
      ),
    );
  }

  // ============ 标签栏 ============
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _tab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: _tab == i
                        ? AppColors.primary
                        : AppColors.searchBarBg,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _tabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: _tab == i ? Colors.white : Colors.black87,
                      fontWeight:
                          _tab == i ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ 红包 ============
  Widget _buildRedPacketTab() {
    final total = _redPackets
        .where((r) => r.$5)
        .fold<double>(0, (s, r) => s + double.parse(r.$1.substring(1)));
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _balanceCard('红包余额', '¥${total.toStringAsFixed(2)}', '共 ${_redPackets.where((r) => r.$5).length} 个可用红包'),
        const SizedBox(height: 12),
        for (final r in _redPackets)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 88,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: r.$5 ? const Color(0xFFe6432e) : AppColors.cartDisable,
                    borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(10)),
                  ),
                  child: Column(
                    children: [
                      Text(r.$1,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(r.$2,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.$3, style: AppTextStyles.smallBold),
                        const SizedBox(height: 4),
                        Text(r.$4, style: AppTextStyles.minSub),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: r.$5
                      ? GestureDetector(
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content: Text('已为你跳转可用商品（演示）'))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: const Color(0xFFe6432e)),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Text('去使用',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFe6432e))),
                          ),
                        )
                      : const Text('已过期',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.subLightText)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ============ 优惠券 ============
  Widget _buildCouponTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _balanceCard('我的优惠券', '${_myCoupons.length} 张', '优惠券在结算时自动抵扣'),
        const SizedBox(height: 12),
        for (final c in _myCoupons)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text(c.$1,
                    style: AppTextStyles.price.copyWith(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.$2, style: AppTextStyles.smallBold),
                      const SizedBox(height: 4),
                      Text(c.$3, style: AppTextStyles.minSub),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CouponCenterScreen())),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Text('去领券中心逛逛',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ============ 淘金币 ============
  Widget _buildCoinTab() {
    final balance = 130 + (_signedIn ? 10 : 0);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _balanceCard('淘金币余额', '$balance', '100 金币 ≈ 1 元，下单可抵扣'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('每日签到', style: AppTextStyles.smallBold),
                    SizedBox(height: 4),
                    Text('签到领 10 金币，连续签到有惊喜',
                        style: AppTextStyles.minSub),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _signedIn
                    ? null
                    : () {
                        setState(() => _signedIn = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('签到成功，金币 +10')));
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 7),
                  decoration: BoxDecoration(
                    color: _signedIn
                        ? AppColors.cartDisable
                        : const Color(0xFFff8f00),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(_signedIn ? '已签到' : '签到',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _recordSection('金币明细', _coinRecords),
      ],
    );
  }

  // ============ 天猫积分 ============
  Widget _buildPointTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _balanceCard('天猫积分', '5', '积分可兑换优惠券与权益'),
        const SizedBox(height: 12),
        _recordSection('积分明细', _pointRecords),
      ],
    );
  }

  // ============ 充值金 ============
  Widget _buildRechargeTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _balanceCard('充值金余额', '¥0.00', '充值金全场通用，永不过期'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择充值面额', style: AppTextStyles.smallBold),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final v in const ['¥50', '¥100', '¥200']) ...[
                    if (v != '¥50') const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                                content: Text('充值 $v（演示环境，未真实扣款）'))),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: AppColors.primary),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(v,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text('暂无充值记录', style: AppTextStyles.smallSubLight),
          ),
        ),
      ],
    );
  }

  // ============ 共用组件 ============
  Widget _balanceCard(String title, String value, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(sub,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _recordSection(
      String title, List<(String, String, String)> records) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text(title, style: AppTextStyles.smallBold),
          ),
          for (final r in records)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(r.$1, style: AppTextStyles.small),
                  ),
                  Text(
                    r.$2,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: r.$2.startsWith('+')
                          ? const Color(0xFFe6432e)
                          : AppColors.subText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(r.$3, style: AppTextStyles.min),
                ],
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
