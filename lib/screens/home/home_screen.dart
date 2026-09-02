import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/banner_pool_provider.dart';
import '../../providers/material_pool_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/product_card.dart';
import 'banner_pool_screen.dart';
import 'category_screen.dart';
import 'channel_screen.dart';
import 'live_list_screen.dart';
import 'search_screen.dart';
import 'search_result_screen.dart';

/// 首页（搜索栏 + 图标两页滑动 + 直播四卡 + 超级立减横幅 + 吸顶 Tab + 猜你喜欢）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // 图标区翻页（第 1 页单行 5+半露，第 2 页 3×5）
  final PageController _iconPageController = PageController();
  double _iconPage = 0;
  // 猜你喜欢：素材池加载完成后随机抽取一次（图+名对应）；池空时回退内置数据
  List<SearchResultItem>? _feedGoods;
  String? _feedSig;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: MockData.homeTabs.length, vsync: this);
    _iconPageController.addListener(() {
      final p = _iconPageController.page ?? 0;
      if ((p - _iconPage).abs() > 0.001) {
        setState(() => _iconPage = p);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _iconPageController.dispose();
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
                      _buildIconPages(),
                      _buildLiveCards(),
                      _buildBannerCarousel(),
                      _buildSuperCutBanner(),
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
                    child: const Row(
                      children: [
                        Icon(AppIcons.search,
                            color: Color(0xFF999999), size: 18),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '搜索你想要的宝贝',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: Color(0xFF999999), fontSize: 14),
                          ),
                        ),
                      ],
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

  // ============ 图标区（两页滑动：P1 单行5个无文字，P2 三行15；下方栏目固定不受影响） ============
  // 行高 = 顶部留白10 + 图标48 = 58（图标下方已无文字，容器高度按内容收紧）
  static const double _kIconRowHeight = 58;

  Widget _buildIconPages() {
    // 翻页时高度在 单行(1页) 与 三行(2页) 之间平滑过渡
    final height = _kIconRowHeight +
        (_kIconRowHeight * 2 + 10) * _iconPage.clamp(0.0, 1.0);
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: height,
            child: PageView(
              controller: _iconPageController,
              children: [
                _buildIconPage1(),
                _buildIconPage2(),
              ],
            ),
          ),
          const SizedBox(height: 2),
          _buildPageIndicator(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    final onSecond = _iconPage > 0.5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: onSecond ? 5 : 14,
          height: 4,
          decoration: BoxDecoration(
            color: onSecond
                ? const Color(0xFFdddddd)
                : AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: onSecond ? 14 : 5,
          height: 4,
          decoration: BoxDecoration(
            color: onSecond
                ? AppColors.primary
                : const Color(0xFFdddddd),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  /// 第 1 页：单行 5 个均分整宽（图标下方不显示文字，半露的第 6 个已按需求删除）
  Widget _buildIconPage1() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 20) / 5;
        return Container(
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(),
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 10),
              ...MockData.homeIconPage1.map(
                (e) => SizedBox(
                    width: itemWidth,
                    child: _buildIconEntry(e, showLabel: false)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 第 2 页：3 行 × 5 = 15 个（图标下方不显示文字）
  Widget _buildIconPage2() {
    final items = MockData.homeIconPage2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: Column(
        children: [
          for (var r = 0; r < 3; r++)
            SizedBox(
              height: _kIconRowHeight - 10,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < 5; c++)
                    Expanded(
                        child: _buildIconEntry(items[r * 5 + c],
                            showLabel: false)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIconEntry(HomeIconEntry e, {bool showLabel = true}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 单击进入对应页面：分类走专属分类页，其余走频道页
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => e.title == '分类'
                ? const CategoryScreen()
                : ChannelScreen(entry: e)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (e.asset != null)
            Image.asset(
              e.asset!,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildFallbackBadge(e),
            )
          else
            _buildFallbackBadge(e),
          if (showLabel) ...[
            const SizedBox(height: 5),
            Text(
              e.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFallbackBadge(HomeIconEntry e) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Color(e.color),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        e.badge,
        maxLines: 1,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: e.badge.length > 1 ? 13 : 20,
        ),
      ),
    );
  }

  // ============ 淘宝直播 / 直播有好价 / 百亿补贴 / 国家补贴（固定四卡） ============
  Widget _buildLiveCards() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Row(
        children: [
          for (var i = 0; i < MockData.homeLiveCards.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _buildLiveCard(MockData.homeLiveCards[i])),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveCard(HomeLiveCard card) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 直播类进直播列表页，补贴类进频道页
      onTap: () {
        final Widget dest = card.title.contains('直播')
            ? const LiveListScreen()
            : ChannelScreen(
                entry: HomeIconEntry(
                  card.title,
                  card.title == '国家补贴' ? '国' : '补',
                  card.title == '国家补贴'
                      ? 0xFF16a34a
                      : 0xFFff2d55,
                ),
              );
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => dest));
      },
      child: _buildLiveCardContent(card),
    );
  }

  Widget _buildLiveCardContent(HomeLiveCard card) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFf7f8fa),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(card.titleColor),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: AppImage(url: card.imageUrl, height: 56)),
          const SizedBox(height: 6),
          Text(
            card.priceText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(card.priceColor),
            ),
          ),
        ],
      ),
    );
  }

  // ============ AI 生成大促 banner 轮播（SenseNova 定期换肤） ============
  Widget _buildBannerCarousel() {
    return const _BannerCarousel();
  }

  // ============ 红色"超级立减"横幅 ============
  Widget _buildSuperCutBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFff1e1e), Color(0xFFff5000)],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          const Icon(Icons.campaign, color: Colors.white, size: 20),
          const SizedBox(width: 6),
          const Text(
            '超级立减',
            style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold),
          ),
          Container(
            width: 1,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white54,
          ),
          const Expanded(
            child: Text(
              '好物立减，大牌9折起',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '福利 立即查看',
              style: TextStyle(
                  color: Color(0xFFff2d2d),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
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

/// 首购 banner 轮播（独立 banner 素材池，与商品素材库不共用、不接 AI 素材）
/// 双击进入 banner 素材库管理；有多少素材就轮播多少张，池空时回退内置大促图
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  /// 内置大促 banner（仅在用户 banner 素材池为空时兜底展示）
  static const _fallbackBanners = [
    'assets/images/banner/banner_618.png',
    'assets/images/banner/banner_fashion.png',
    'assets/images/banner/banner_fresh.png',
    'assets/images/banner/banner_autumn.png',
    'assets/images/banner/banner_digital.png',
  ];

  final PageController _controller = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final count = _pageCount;
      if (count <= 0) return;
      final next = (_current + 1) % count;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut);
    });
  }

  /// 当前轮播页数（用户 banner 素材优先，池空回退内置）
  int get _pageCount {
    final pool = context.read<BannerPoolProvider>();
    return pool.entries.isNotEmpty
        ? pool.entries.length
        : _fallbackBanners.length;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 双击进入 banner 素材库更换素材
  void _openBannerPool() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BannerPoolScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pool = context.watch<BannerPoolProvider>();
    final pages =
        pool.entries.isNotEmpty ? pool.entries : _fallbackBanners;
    if (_current >= pages.length) _current = pages.length - 1;
    return GestureDetector(
      onDoubleTap: _openBannerPool,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        height: 100,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => AppImage(
                  url: pages[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
            // 圆点指示器
            Positioned(
              right: 10,
              bottom: 8,
              child: Row(
                children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 4),
                      width: _current == i ? 12 : 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _current == i
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
