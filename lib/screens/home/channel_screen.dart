import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/product_card.dart';
import 'category_screen.dart';
import 'search_result_screen.dart';

/// 频道页（首页金刚区入口）
/// 频道色渐变头 + 运营标语 + 促销 chips + 商品双列网格（按频道名哈希稳定选品）
class ChannelScreen extends StatelessWidget {
  final HomeIconEntry entry;
  const ChannelScreen({super.key, required this.entry});

  /// 各频道运营标语（未配置的走兜底文案）
  static const _slogans = {
    '天猫超市': '生活百货，一站购齐',
    '淘宝秒杀': '整点开抢，手慢无',
    '领淘金币': '天天领币，下单抵扣',
    '88VIP': '尊享折上 95 折',
    '芭芭农场': '种果树，免费吃水果',
    '红包签到': '每日签到，红包天天领',
    '聚划算': '品牌团购，巨划算',
    '天猫新品': '全球新品，首发速递',
    '分类': '全部分类，快速直达',
    '活动日历': '大促排期，一目了然',
    '试用领取': '免费试用，先用后买',
    '淘工厂': '工厂直供，源头好货',
    '游戏中心': '边玩边赚，好礼不停',
    '飞猪旅行': '机票酒店，说走就走',
    '连连消': '休闲一刻，消除烦恼',
    '充值中心': '话费流量，极速到账',
    '淘宝闪购': '小时达，附近好店',
    '淘鲜达': '生鲜果蔬，一小时送达',
    '淘宝礼物': '送礼有心意',
    '全部频道': '更多精彩频道',
    '淘票票': '电影演出，在线选座',
    '百亿补贴': '官方补贴，低价正品',
    '国家补贴': '政府补贴，至高立减 20%',
  };

  /// 促销 chip 文案（按频道轮换展示 3 个）
  static const _promoChips = [
    ['限时折扣', '爆款直降', '天天低价'],
    ['整点秒杀', '满减专区', '新人专享'],
    ['品牌特卖', '第二件半价', '包邮专区'],
  ];

  int get _seed {
    var h = 0;
    for (final c in entry.title.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  /// 按频道哈希稳定选取 10 件商品（轮转切片，同频道每次进入一致）
  List<SearchResultItem> get _goods {
    final all = MockData.guessLikeGoods;
    final start = _seed % all.length;
    return [for (var i = 0; i < 10; i++) all[(start + i) % all.length]];
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(entry.color);
    final slogan = _slogans[entry.title] ?? '精选好货，尽在${entry.title}';
    final chips = _promoChips[_seed % _promoChips.length];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 频道色渐变头
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.75)],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    // 导航行
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.share_outlined,
                              color: Colors.white, size: 20),
                          onPressed: () {
                            Clipboard.setData(const ClipboardData(
                                text:
                                    '【淘宝】https://m.tb.cn/h.chX19 这个频道太好逛了，快来看看吧'));
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(const SnackBar(
                                content: Text('分享链接已复制，快去分享吧'),
                                duration: Duration(seconds: 1),
                              ));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // 频道徽标 + 标题 + 标语
                    entry.asset != null
                        ? Image.asset(
                            entry.asset!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _badgeFallback(),
                          )
                        : _badgeFallback(),
                    const SizedBox(height: 10),
                    Text(entry.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(slogan,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12)),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
          // 促销 chips 条
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  for (final c in chips) ...[
                    // 促销 chip：点击按关键词搜索相关商品
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SearchResultScreen(keyword: c),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(c,
                            style: const TextStyle(
                                color: AppColors.primary, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  // 单击「更多 >」→ 全部分类页
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CategoryScreen()),
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text('更多 >',
                          style: TextStyle(
                              color: AppColors.subText, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 推荐标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department,
                      color: color, size: 18),
                  const SizedBox(width: 4),
                  Text('${entry.title}·精选推荐',
                      style: AppTextStyles.middleBold),
                ],
              ),
            ),
          ),
          // 商品双列网格
          SliverPadding(
            padding: const EdgeInsets.all(8),
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
    );
  }

  Widget _badgeFallback() {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        entry.badge,
        maxLines: 1,
        style: TextStyle(
          color: Color(entry.color),
          fontWeight: FontWeight.bold,
          fontSize: entry.badge.length > 1 ? 18 : 26,
        ),
      ),
    );
  }
}
