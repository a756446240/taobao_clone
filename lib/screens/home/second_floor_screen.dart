import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../widgets/app_image.dart';
import '../../widgets/product_card.dart';

/// 淘宝「二楼」活动页：首页顶部继续下拉超过阈值进入。
/// 品牌活动聚合页——大 banner + 福利券 + 活动专区 + 精选商品。
class SecondFloorScreen extends StatefulWidget {
  const SecondFloorScreen({super.key});

  @override
  State<SecondFloorScreen> createState() => _SecondFloorScreenState();
}

class _SecondFloorScreenState extends State<SecondFloorScreen> {
  static const _banners = [
    'assets/images/banner/banner_618.png',
    'assets/images/banner/banner_fashion.png',
    'assets/images/banner/banner_fresh.png',
    'assets/images/banner/banner_autumn.png',
    'assets/images/banner/banner_digital.png',
  ];

  final PageController _bannerCtrl = PageController();
  int _bannerIndex = 0;

  /// 已领取的券（面值）
  final Set<int> _claimed = {};

  /// 精选商品：内置池确定性抽 6 个
  late final _goods = ([...MockData.guessLikeGoods]..shuffle(Random(20260902)))
      .take(6)
      .toList();

  @override
  void dispose() {
    _bannerCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0533),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // 顶部栏
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text('淘宝二楼 · 品牌狂欢',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            // 大 banner 轮播
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                height: 150,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: PageView.builder(
                        controller: _bannerCtrl,
                        itemCount: _banners.length,
                        onPageChanged: (i) =>
                            setState(() => _bannerIndex = i),
                        itemBuilder: (_, i) => AppImage(
                          url: _banners[i],
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${_bannerIndex + 1}/${_banners.length}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 福利券
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _couponCard(20, '满99可用'),
                    const SizedBox(width: 8),
                    _couponCard(50, '满199可用'),
                    const SizedBox(width: 8),
                    _couponCard(100, '满399可用'),
                  ],
                ),
              ),
            ),
            // 活动专区
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                child: Row(
                  children: [
                    _zoneCard('新品首发', '每周三上新', const Color(0xFF7B2FF7),
                        Icons.new_releases),
                    const SizedBox(width: 8),
                    _zoneCard('品牌日', '大牌5折起', const Color(0xFFFF2E4D),
                        Icons.verified),
                    const SizedBox(width: 8),
                    _zoneCard('限时秒杀', '整点开抢', const Color(0xFFFF8C00),
                        Icons.bolt),
                  ],
                ),
              ),
            ),
            // 精选商品标题
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Text('二楼精选 · 会场同款',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            // 精选商品网格
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ProductCard(item: _goods[index]),
                  childCount: _goods.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      ),
    );
  }

  Widget _couponCard(int value, String cond) {
    final claimed = _claimed.contains(value);
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (claimed) return;
          setState(() => _claimed.add(value));
          _toast('已领取 $value 元券，放入"我的-红包卡券"');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: claimed
                  ? [const Color(0xFF555555), const Color(0xFF444444)]
                  : [const Color(0xFFFF6A00), const Color(0xFFFF2E4D)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text('¥$value',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(claimed ? '已领取' : '$cond · 点击领取',
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoneCard(String title, String sub, Color color, IconData icon) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _toast('$title 会场：$sub'),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A0F45),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              Text(sub,
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
