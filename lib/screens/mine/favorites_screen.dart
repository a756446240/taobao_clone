import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/follow_shops_provider.dart';
import '../../widgets/app_image.dart';
import '../home/search_result_screen.dart';
import '../product/product_detail_screen.dart';
import '../product/shop_home_screen.dart';

/// 淘宝式收藏夹页：商品 / 店铺双 Tab
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  int _tab = 0; // 0=商品 1=店铺

  /// 收藏的宝贝：真实收藏数据（商品详情页收藏按钮写入，持久化）
  List<SearchResultItem> _goodsOf(BuildContext context) =>
      context.watch<FavoritesProvider>().items;

  /// 收藏的店铺：真实关注数据（店铺主页关注按钮写入，持久化）
  List<String> _shopsOf(BuildContext context) =>
      context.watch<FollowShopsProvider>().followed.toList()..sort();

  /// 由店铺名确定性派生粉丝数文案（同一店铺每次一致）
  static String _fansOf(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final w = 10 + h % 450; // 1.0万 ~ 45.9万
    return '${(w / 10).toStringAsFixed(1)}万粉丝';
  }

  /// 由店铺名确定性派生店铺标签
  static String _tagOf(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    const tags = ['天猫', '金牌卖家', '天猫国际', '企业店铺'];
    return tags[h % tags.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('收藏的宝贝',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: _tab == 0 ? _buildGoodsGrid() : _buildShopList(),
          ),
        ],
      ),
    );
  }

  /// 顶部 商品/店铺 胶囊 Tab（橙底白字选中态，对齐订单页风格）
  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          _tabCapsule('商品', 0, count: _goodsOf(context).length),
          const SizedBox(width: 8),
          _tabCapsule('店铺', 1, count: _shopsOf(context).length),
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

  // ============ 商品 Tab：双列网格 ============
  Widget _buildGoodsGrid() {
    final goods = _goodsOf(context);
    if (goods.isEmpty) {
      return const Center(
        child: Text('还没有收藏宝贝\n去商品详情页点"收藏"吧',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.68,
      ),
      itemCount: goods.length,
      itemBuilder: (_, i) => _goodsCard(goods[i]),
    );
  }

  Widget _goodsCard(SearchResultItem g) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(item: g)),
      ),
      onLongPress: () => _confirmUnfav(g),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: AppImage(url: g.imageUrl, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('¥${g.price}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(g.commentCount,
                          style: const TextStyle(
                              color: Color(0xFF999999), fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(g.shopName,
                          style: const TextStyle(
                              color: Color(0xFF999999), fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                    ),
                    GestureDetector(
                      onTap: () {
                        // 找相似：取标题前 6 个字作关键词搜同款
                        final kw = g.title.length <= 6
                            ? g.title
                            : g.title.substring(0, 6);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SearchResultScreen(keyword: kw),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1E8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('找相似',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ============ 店铺 Tab：列表（真实关注数据）============
  Widget _buildShopList() {
    final shops = _shopsOf(context);
    if (shops.isEmpty) {
      return const Center(
        child: Text('还没有收藏店铺\n去店铺主页点"关注"吧',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      itemCount: shops.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final name = shops[i];
        final fans = _fansOf(name);
        final tag = _tagOf(name);
        return GestureDetector(
          onLongPress: () => _confirmUnfollow(name),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(name.substring(0, 1),
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(name,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1E8),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(tag,
                                style: const TextStyle(
                                    color: AppColors.primary, fontSize: 9)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(fans,
                          style: const TextStyle(
                              color: Color(0xFF999999), fontSize: 11)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ShopHomeScreen(
                          shopName: name,
                          shopType: tag.contains('天猫')
                              ? ShopType.tianMao
                              : ShopType.taoBao),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child:
                        const Text('进店逛逛', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 长按商品卡 → 取消收藏
  void _confirmUnfav(SearchResultItem g) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消收藏'),
        content: Text('不再收藏「${g.title}」吗？',
            maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () {
              context.read<FavoritesProvider>().remove(g.title);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('已取消收藏'),
                    duration: Duration(seconds: 1)),
              );
            },
            child: const Text('取消收藏', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 长按店铺卡 → 取消收藏（同步全局关注状态）
  void _confirmUnfollow(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消收藏'),
        content: Text('不再收藏「$name」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () {
              context.read<FollowShopsProvider>().unfollow(name);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('已取消收藏'),
                    duration: Duration(seconds: 1)),
              );
            },
            child: const Text('取消收藏', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
