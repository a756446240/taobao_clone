import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/material_pool_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/product_card.dart';
import 'search_screen.dart';
import 'search_result_screen.dart';

/// 首页（搜索栏 + 热搜 + 轮播 + 金刚区 + 新品推荐 + 头条 + 猜你喜欢）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _headlineIndex = 0;
  Timer? _headlineTimer;
  // 猜你喜欢：素材池加载完成后随机抽取一次（图+名对应）；池空时回退内置数据
  List<SearchResultItem>? _feedGoods;
  String? _feedSig;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: MockData.homeTabs.length, vsync: this);
    _headlineTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      setState(() {
        _headlineIndex = (_headlineIndex + 1) % MockData.headlines.length;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headlineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 素材池加载完后再生成推荐流；素材有增删/命名变化时自动重抽一批
    final pool = context.watch<MaterialPoolProvider>();
    final sig =
        '${pool.entries.length}/${pool.entries.where((e) => e.title.isNotEmpty).length}';
    if (!pool.loading && (_feedGoods == null || _feedSig != sig)) {
      _feedSig = sig;
      _feedGoods = pool.recommendGoods(10);
    }
    final feedGoods = _feedGoods ??
        ([...MockData.guessLikeGoods]..shuffle(Random()));
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // 折叠区内容
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildKingKong(),
                      _buildRecommend(),
                      _buildHeadline(),
                    ],
                  ),
                ),
                // TabBar 吸顶
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(_buildTabBar()),
                ),
                // 商品网格
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
                      (context, index) =>
                          ProductCard(item: feedGoods[index]),
                      childCount: feedGoods.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ 顶部搜索栏（淘宝新版：黑字热搜 + 描边圆角搜索框） ============
  Widget _buildSearchBar() {
    final statusBarHeight = MediaQuery.paddingOf(context).top;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(12, statusBarHeight + 6, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 描边圆角搜索框：扫码 | 占位词 | 相机 | 搜索按钮
          Container(
            height: 40,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 1.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(AppIcons.scan,
                    color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: VerticalDivider(
                      width: 1, color: Color(0xFFe0e0e0), thickness: 1),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _gotoSearch(),
                    child: const Text(
                      '搜索你想要的宝贝',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Color(0xFF999999), fontSize: 14),
                    ),
                  ),
                ),
                const Icon(AppIcons.camera,
                    color: Color(0xFF999999), size: 22),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _gotoSearch(),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Text(
                      '搜索',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ 金刚区 ============
  Widget _buildKingKong() {
    const pageCount = 10;
    final pages = <Widget>[];
    for (var i = 0; i < MockData.kingKongItems.length; i += pageCount) {
      final end = (i + pageCount < MockData.kingKongItems.length)
          ? i + pageCount
          : MockData.kingKongItems.length;
      final items = MockData.kingKongItems.sublist(i, end);
      pages.add(
        GridView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.95,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) =>
              _buildKingKongItem(items[index]),
        ),
      );
    }

    return Container(
      color: Colors.white,
      height: 172,
      child: PageView(children: pages),
    );
  }

  Widget _buildKingKongItem(KingKongItem item) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppImage(url: item.picUrl, width: 44, height: 44),
        const SizedBox(height: 4),
        Text(item.title,
            style: AppTextStyles.min.copyWith(color: Colors.black87)),
      ],
    );
  }

  // ============ 新品推荐 ============
  Widget _buildRecommend() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('新品推荐', style: AppTextStyles.middleBold),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: MockData.recommendItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) =>
                  _buildRecommendItem(MockData.recommendItems[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendItem(RecommendItem item) {
    final bg = _hexToColor(item.bgColor);
    final titleColor = _hexToColor(item.titleColor);
    final subtitleColor = _hexToColor(item.subtitleColor);

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          AppImage(url: item.picUrl, width: 48, height: 48),
          const SizedBox(height: 4),
          if (item.title.isNotEmpty)
            Text(item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.min.copyWith(color: titleColor)),
          if (item.subtitle.isNotEmpty)
            Text(item.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: subtitleColor)),
        ],
      ),
    );
  }

  // ============ 头条 ============
  Widget _buildHeadline() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(AppIcons.notification,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 20,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: Text(
                  MockData.headlines[_headlineIndex],
                  key: ValueKey(_headlineIndex),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ TabBar ============
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.black87,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        tabs:
            MockData.homeTabs.map((tab) => Tab(text: tab.title)).toList(),
      ),
    );
  }

  // ============ 导航 ============
  void _gotoSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _gotoResult(String keyword) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchResultScreen(keyword: keyword)),
    );
  }
}

/// 颜色工具：hex 转 Color
Color _hexToColor(String hex) {
  var value = hex.replaceAll('#', '');
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

/// TabBar 吸顶代理
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _TabBarDelegate(this.child);

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: 2,
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
