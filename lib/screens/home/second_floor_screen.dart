import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/banner_pool_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/product_card.dart';
import '../product/product_detail_screen.dart';

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

  /// 秒杀商品：另一颗种子确定性抽 6 个，折扣/已抢进度按标题哈希派生
  late final _seckillGoods =
      ([...MockData.guessLikeGoods]..shuffle(Random(20260903)))
          .take(6)
          .toList();

  /// 整点秒杀倒计时：每秒刷新一次
  Timer? _seckillTimer;
  DateTime _now = DateTime.now();

  /// 距离下一整点的剩余时间
  Duration get _seckillRemain {
    final next = DateTime(_now.year, _now.month, _now.day, _now.hour)
        .add(const Duration(hours: 1));
    return next.difference(_now);
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  /// 倒计时文本 mm:ss（整点场永远小于 1 小时）
  String get _seckillClock {
    final r = _seckillRemain;
    return '${_two(r.inMinutes)}:${_two(r.inSeconds % 60)}';
  }

  @override
  void initState() {
    super.initState();
    _seckillTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _seckillTimer?.cancel();
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
    // banner 与首页轮播同池：用户素材优先，池空回退内置 5 图
    final pool = context.watch<BannerPoolProvider>();
    final banners =
        pool.entries.isNotEmpty ? pool.entries : _banners;
    if (_bannerIndex >= banners.length) _bannerIndex = 0;
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
                        child: Text('${_bannerIndex + 1}/${banners.length}',
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
                    _zoneCard('限时秒杀', '距开抢 $_seckillClock',
                        const Color(0xFFFF8C00), Icons.bolt),
                  ],
                ),
              ),
            ),
            // 整点秒杀：实时倒计时 + 秒杀价横向列表
            SliverToBoxAdapter(child: _buildSeckill()),
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

  // ============ 整点秒杀 ============
  Widget _buildSeckill() {
    final nextHour = (_now.hour + 1) % 24;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B0F4F), Color(0xFF2A0A3E)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66FF8C00)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Color(0xFFFFB300), size: 18),
              const SizedBox(width: 4),
              const Text('整点秒杀',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('$nextHour:00 场',
                    style:
                        const TextStyle(color: Colors.white, fontSize: 10)),
              ),
              const SizedBox(width: 8),
              Text('距开抢 $_seckillClock',
                  style: const TextStyle(
                      color: Color(0xFFFFB300), fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () => _toast('更多秒杀场次：每天 10/14/20 点整'),
                child: const Text('全部场次 >',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _seckillGoods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _seckillCard(_seckillGoods[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seckillCard(SearchResultItem g) {
    final hash = g.title.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    final origin = double.tryParse(g.price) ?? 99.0;
    final seckill = (origin * (0.5 + hash % 3 * 0.1)); // 5~7 折
    final grabbed = 20 + hash % 70; // 已抢 20%~89%
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(item: g)),
      ),
      child: Container(
        width: 108,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              child: AppImage(
                  url: g.imageUrl,
                  width: 108,
                  height: 84,
                  fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: Text(g.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
              child: Row(
                children: [
                  Text('¥${seckill.toStringAsFixed(1)}',
                      style: const TextStyle(
                          color: Color(0xFFFF2E4D),
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('¥${origin.toStringAsFixed(1)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: Stack(
                  children: [
                    Container(height: 12, color: const Color(0xFFFFE0D6)),
                    FractionallySizedBox(
                      widthFactor: grabbed / 100,
                      child: Container(
                          height: 12, color: const Color(0xFFFF5000)),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Text('已抢$grabbed%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                height: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
