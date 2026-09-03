import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/coupons_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/material_pool_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/product_card.dart';
import '../../widgets/shop_type_badge.dart';
import '../home/search_result_screen.dart';
import '../mine/coupon_center_screen.dart';
import '../order/order_list_screen.dart';
import '../product/shop_home_screen.dart';
import 'cart_compare_screen.dart';

/// 购物车页（1:1 复刻 3.4 新版）
/// 商品项右滑显示“换图 / 编辑 / 删除”，不再直接显示编辑入口。
/// 商品图与名称参与素材库随机分配（图名对应），未命名素材自动 AI 匹配名称。
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  /// 购物车商品的分配 key：优先订单编号（稳定唯一），兜底用标题
  static String cartItemKey(OrderItem item) =>
      item.orderNo.isNotEmpty ? item.orderNo : item.title;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

/// 购物车页状态：管理模式下底部切换为批量操作栏（全选 / 移入收藏 / 删除）
class _CartScreenState extends State<CartScreen> {
  bool _managing = false;

  /// 商品降价幅度（按标题+规格哈希稳定，约 30% 商品降价）；null 表示未降价
  static double? priceDropOf(OrderItem item) {
    var h = 0;
    for (final c in (item.title + item.configuration).codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    if (h % 10 >= 3) return null;
    final pct = 5 + (h ~/ 10) % 20; // 降幅 5%~24%
    return (item.price * pct).round() / 100;
  }

  /// 下拉刷新购物车
  Future<void> _onRefresh(BuildContext context) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!context.mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('购物车已刷新'),
        duration: Duration(seconds: 1),
      ));
  }

  /// 搜索购物车：底部弹层内输入关键词，实时过滤购物车内商品
  void _showCartSearchSheet() {
    final cart = context.read<CartProvider>();
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final q = ctrl.text.trim();
            final matches = <({String shop, OrderItem item})>[
              if (q.isNotEmpty)
                for (final s in cart.shops)
                  for (final it in s.items)
                    if (it.title.contains(q)) (shop: s.shopName, item: it),
            ];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                size: 18, color: Color(0xFF999999)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: TextField(
                                controller: ctrl,
                                autofocus: true,
                                onChanged: (_) => setSheet(() {}),
                                decoration: const InputDecoration(
                                  hintText: '搜索购物车里的商品',
                                  hintStyle: TextStyle(
                                      fontSize: 13, color: Color(0xFFBBBBBB)),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: q.isEmpty
                          ? const Center(
                              child: Text('输入关键词，快速找到购物车里的商品',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF999999))))
                          : matches.isEmpty
                              ? const Center(
                                  child: Text('购物车里没有相关商品',
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF999999))))
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: matches.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (_, i) {
                                    final m = matches[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      child: Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            child: AppImage(
                                                url: m.item.imageUrl,
                                                width: 44,
                                                height: 44),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(m.item.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 13)),
                                                const SizedBox(height: 2),
                                                Text(m.shop,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                            0xFF999999))),
                                              ],
                                            ),
                                          ),
                                          Text(
                                              '¥${m.item.price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFFFF5000),
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final shops = cart.shops;
    // 降价商品（用于顶部降价提醒条）
    final dropped = <OrderItem>[
      for (final s in shops)
        for (final it in s.items)
          if (priceDropOf(it) != null) it,
    ];
    // 素材池：为购物车商品分配"图+名对应"的素材（种子确定性派生，跨重启稳定）
    final pool = context.watch<MaterialPoolProvider>();
    if (!pool.loading && !pool.isEmpty) {
      final keys = <String>[
        for (final s in shops)
          for (final it in s.items) CartScreen.cartItemKey(it),
      ];
      pool.assignCartMaterials(keys);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            _buildCouponBar(context),
            if (dropped.isNotEmpty) _buildPriceDropBar(context, dropped),
            Expanded(
              child: shops.isEmpty
                  ? _buildEmptyWithRecs(context)
                  : RefreshIndicator(
                      onRefresh: () => _onRefresh(context),
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: shops.length + 1,
                        itemBuilder: (ctx, i) => i < shops.length
                            ? _ShopCard(ctx, shop: shops[i], pool: pool)
                            : _buildGuessYouLike(context),
                      ),
                    ),
            ),
            _buildBottomBar(context, cart),
          ],
        ),
      ),
    );
  }

  // ============ 猜你喜欢（淘宝式购物车推荐流）============
  /// 推荐商品：内置池排除已在购物车的商品，按购物车内容哈希确定性排序
  List<SearchResultItem> _recGoods(BuildContext context) {
    final cart = context.read<CartProvider>();
    final inCart = <String>{
      for (final s in cart.shops)
        for (final it in s.items) it.title,
    };
    final pool =
        MockData.guessLikeGoods.where((e) => !inCart.contains(e.title)).toList();
    final seed = inCart.fold<int>(7, (a, t) => (a * 31 + t.length) & 0x7fffffff);
    pool.shuffle(Random(seed));
    return pool.take(6).toList();
  }

  Widget _buildGuessYouLike(BuildContext context) {
    final recs = _recGoods(context);
    if (recs.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 0.5, color: AppColors.divider),
            const SizedBox(width: 8),
            const Icon(Icons.favorite, color: AppColors.primary, size: 14),
            const SizedBox(width: 4),
            const Text('猜你喜欢',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333))),
            const SizedBox(width: 8),
            Container(width: 40, height: 0.5, color: AppColors.divider),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.68,
          ),
          itemCount: recs.length,
          itemBuilder: (_, i) => ProductCard(item: recs[i]),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// 空购物车：提示文案 + 推荐流（对齐真淘宝空态）
  Widget _buildEmptyWithRecs(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.shopping_cart_outlined,
            size: 56, color: Color(0xFFCCCCCC)),
        const SizedBox(height: 10),
        const Center(
            child: Text('购物车是空的', style: AppTextStyles.middleSub)),
        const SizedBox(height: 4),
        const Center(
            child: Text('再忙，也要记得买点什么犒劳自己',
                style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)))),
        _buildGuessYouLike(context),
      ],
    );
  }

  // ============ 商品对比 ============
  /// 收集勾选的商品进入对比页（2~4 件）
  void _openCompare(BuildContext context) {
    final cart = context.read<CartProvider>();
    final entries = <CompareEntry>[
      for (final s in cart.shops)
        for (final it in s.items)
          if (it.isSelected) CompareEntry(shop: s, item: it),
    ];
    if (entries.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('请先勾选 2~4 件要对比的商品'),
            duration: Duration(seconds: 1)),
      );
      return;
    }
    if (entries.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('最多同时对比 4 件，已为你取前 4 件'),
            duration: Duration(seconds: 1)),
      );
    }
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CartCompareScreen(
              entries: entries.take(4).toList())),
    );
  }

  // ============ 顶部工具栏（AI省钱 / 搜索 / 对比 / 管理）============
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          // AI省钱：点击打开 AI 省钱助手（凑单/用券建议）
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showAiSavingSheet(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('AI',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 3),
                const Text('省钱',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Spacer(),
          // 右侧操作统一放在一个紧凑 Row 里
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.search, size: 20, color: Colors.black87),
                onPressed: _showCartSearchSheet,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => _openCompare(context),
                child: const Text('对比',
                    style: TextStyle(fontSize: 13, color: Colors.black87)),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                // 单击：进入/退出批量管理模式；双击：店铺编辑菜单
                onTap: () => setState(() => _managing = !_managing),
                onDoubleTap: () => _showManageSheet(context),
                child: Text(_managing ? '完成' : '管理',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ AI 省钱助手（按当前勾选金额给出凑单/用券建议，券状态联动卡券包）============
  void _showAiSavingSheet(BuildContext context) {
    final cart = context.read<CartProvider>();
    final coupons = context.read<CouponsProvider>();
    final total = cart.totalPrice;
    const couponThreshold = 599.0;
    const couponValue = 61.0;
    final gap = couponThreshold - total;
    final unclaimedCount = coupons.unclaimed.length;
    final platformClaimed = coupons.isClaimed('消费券', '61');
    // 61 元消费券未领取时的提醒文案
    final claimTip =
        platformClaimed ? '61 元消费券已在你的卡券包，结算时直接出示即可' : '记得先去领券中心领取 61 元消费券再结算';
    final List<String> tips;
    if (cart.selectedItemCount == 0) {
      tips = [
        '先勾选想买的商品，我帮你算怎么买最划算',
        if (unclaimedCount > 0) '领券中心有 $unclaimedCount 张券待领取' else '领券中心的券你都领齐了，结算记得用',
      ];
    } else if (gap > 0) {
      tips = [
        '当前勾选 ¥${total.toStringAsFixed(2)}，再凑 ¥${gap.toStringAsFixed(2)} 即可用 61 元消费券（满 599 可用）',
        '去「猜你喜欢」挑一件小件凑单最划算',
        if (unclaimedCount > 0) '领券中心还有 $unclaimedCount 张券可叠加领取',
      ];
    } else {
      tips = [
        '当前勾选 ¥${total.toStringAsFixed(2)}，已满足 61 元消费券使用门槛，结算立减 ¥${couponValue.toStringAsFixed(0)}',
        claimTip,
      ];
    }
    // 凑单推荐：价格升序取 6 件（优先不贵于缺口的）
    final pool = [...MockData.guessLikeGoods]
      ..sort((a, b) => (double.tryParse(a.price) ?? 999)
          .compareTo(double.tryParse(b.price) ?? 999));
    final added = <String>{}; // 本次弹层内已加购的商品标题
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          // 每次重建都重新读取最新勾选金额（加购后缺口实时缩小）
          final curTotal = context.read<CartProvider>().totalPrice;
          final curGap = couponThreshold - curTotal;
          final List<String> liveTips;
          if (cart.selectedItemCount == 0) {
            liveTips = tips;
          } else if (curGap > 0) {
            liveTips = [
              '当前勾选 ¥${curTotal.toStringAsFixed(2)}，再凑 ¥${curGap.toStringAsFixed(2)} 即可用 61 元消费券（满 599 可用）',
              '点击下方「+」一键凑单，凑满自动停',
            ];
          } else {
            liveTips = [
              '当前勾选 ¥${curTotal.toStringAsFixed(2)}，已满足 61 元消费券使用门槛，结算立减 ¥${couponValue.toStringAsFixed(0)}',
              claimTip,
            ];
          }
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text('AI 省钱助手',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  for (final tip in liveTips)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(tip,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.4)),
                          ),
                        ],
                      ),
                    ),
                  // 凑单推荐（有缺口时展示）
                  if (cart.selectedItemCount > 0 && curGap > 0) ...[
                    const SizedBox(height: 4),
                    const Text('为你凑单',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 148,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pool.length < 6 ? pool.length : 6,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final g = pool[i];
                          final isAdded = added.contains(g.title);
                          return Container(
                            width: 104,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                AppImage(
                                    url: g.imageUrl,
                                    width: 104,
                                    height: 78,
                                    fit: BoxFit.cover),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 4, 6, 0),
                                  child: Text(g.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 10, height: 1.2)),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(6, 2, 6, 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text('¥${g.price}',
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: AppColors.primary,
                                                fontSize: 12,
                                                fontWeight:
                                                    FontWeight.bold)),
                                      ),
                                      GestureDetector(
                                        onTap: isAdded
                                            ? null
                                            : () {
                                                cart.addToCart(
                                                  shopName: g.shopName,
                                                  title: g.title,
                                                  price: double.tryParse(
                                                          g.price) ??
                                                      0,
                                                  imageUrl: g.imageUrl,
                                                  spec: '默认规格',
                                                  quantity: 1,
                                                );
                                                setSheet(() =>
                                                    added.add(g.title));
                                              },
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isAdded
                                                ? const Color(0xFFDDDDDD)
                                                : AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                              isAdded ? '已加' : '+ 凑单',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const CouponCenterScreen()),
                        );
                      },
                      child: const Text('去领券中心看看'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============ 顶部消费券提示条（数据联动全局卡券包） ============
  Widget _buildCouponBar(BuildContext context) {
    final cp = context.watch<CouponsProvider>();
    final un = cp.unclaimed;
    // 目录内券全部领完后收起提示条
    if (un.isEmpty) return const SizedBox.shrink();
    final totalValue =
        un.fold<int>(0, (s, c) => s + (int.tryParse(c.value) ?? 0));
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text('您有${un.length}张共$totalValue元券待领取',
                style: const TextStyle(fontSize: 12, color: Colors.red)),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const CouponCenterScreen()),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('去领券',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ============ 降价提醒条（点击展开降价商品清单）============
  Widget _buildPriceDropBar(BuildContext context, List<OrderItem> dropped) {
    final saved = dropped.fold<double>(
        0, (sum, it) => sum + priceDropOf(it)! * it.quantity);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPriceDropSheet(context, dropped),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const Icon(Icons.trending_down,
                color: Color(0xFFe6432e), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${dropped.length}件商品比加入时降价，共省 ¥${saved.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFFe6432e)),
              ),
            ),
            const Text('查看',
                style: TextStyle(fontSize: 12, color: Color(0xFFe6432e))),
            const Icon(Icons.chevron_right,
                color: Color(0xFFe6432e), size: 16),
          ],
        ),
      ),
    );
  }

  void _showPriceDropSheet(BuildContext context, List<OrderItem> dropped) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('降价商品',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1, color: AppColors.divider),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: dropped.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (ctx, i) {
                    final it = dropped[i];
                    final drop = priceDropOf(it)!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: AppImage(
                                url: it.imageUrl, width: 52, height: 52),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.small),
                                const SizedBox(height: 4),
                                Text(it.configuration,
                                    style: AppTextStyles.minSub),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '¥${it.price.toStringAsFixed(it.price % 1 == 0 ? 0 : 2)}',
                                style: AppTextStyles.price
                                    .copyWith(fontSize: 15),
                              ),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFe6432e)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  '降¥${drop.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFe6432e)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ 店铺卡片 ============
  Widget _ShopCard(BuildContext context,
      {required ShoppingCartShop shop, required MaterialPoolProvider pool}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 店铺头
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _selectIcon(shop.isSelected,
                    onTap: () => context
                        .read<CartProvider>()
                        .toggleShopSelection(shop)),
                const SizedBox(width: 8),
                // 店铺类型徽章（天猫/淘宝/国际，双击可切换）
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onDoubleTap: () => _pickShopType(context, shop),
                    child: ShopTypeBadge(shop: shop),
                  ),
                ),
                // 店名 + 箭头：点击进店逛逛（同商品详情页）
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => ShopHomeScreen(
                              shopName: shop.shopName,
                              shopType: shop.shopType)),
                    ),
                    child: Text(shop.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.smallBold),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => ShopHomeScreen(
                            shopName: shop.shopName,
                            shopType: shop.shopType)),
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: Color(0xFFc4c4c4), size: 16),
                ),
                const SizedBox(width: 8),
                if (shop.hasCoupons)
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const CouponCenterScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('领券',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
          // 店铺级促销横条（按店名确定性派生，点击去领券中心）
          if (_promoOf(shop) != null)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CouponCenterScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(42, 0, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.local_activity,
                        color: AppColors.primary, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(_promoOf(shop)!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                    const Text('去凑单',
                        style:
                            TextStyle(color: Color(0xFF999999), fontSize: 10)),
                    const Icon(Icons.chevron_right,
                        size: 12, color: Color(0xFF999999)),
                  ],
                ),
              ),
            ),
          const Divider(height: 1, color: AppColors.divider),
          // 商品列表（带右滑操作，展示素材库分配的图+名）
          ...shop.items.map((item) => _SlidableCartItem(
                item: item,
                shopName: shop.shopName,
                material: pool.cartMaterialFor(CartScreen.cartItemKey(item)),
              )),
        ],
      ),
    );
  }

  /// 店铺级促销文案：按店名哈希确定性派生，约 2/3 的店铺有促销
  String? _promoOf(ShoppingCartShop shop) {
    if (shop.items.isEmpty) return null;
    var h = 0;
    for (final c in shop.shopName.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    if (h % 3 == 2) return null;
    const promos = ['每满300减30', '店铺券满199减20', '满2件9折', '会员立减15元'];
    return promos[h % promos.length];
  }

  // ============ 商品项（右滑显示"换图 / 编辑 / 移入收藏 / 找相似 / 删除"）============
  Widget _SlidableCartItem(
      {required OrderItem item,
      required String shopName,
      MaterialEntry? material}) {
    return Builder(
      builder: (context) => Slidable(
        key: ValueKey(item.hashCode),
        direction: Axis.horizontal,
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.62,
          children: [
            CustomSlidableAction(
              onPressed: (_) => _pickCartItemImage(context, item),
              backgroundColor: const Color(0xFF5C6BC0),
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 20),
                  SizedBox(height: 2),
                  Text('换图', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => _showEditCartItemSheet(context, item),
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(height: 2),
                  Text('编辑', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => _moveItemToFavorites(context, item, shopName),
              backgroundColor: const Color(0xFF12A150),
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 20),
                  SizedBox(height: 2),
                  Text('收藏', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) {
                final kw = item.title.length > 6
                    ? item.title.substring(0, 6)
                    : item.title;
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => SearchResultScreen(keyword: kw)),
                );
              },
              backgroundColor: const Color(0xFF8E24AA),
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 20),
                  SizedBox(height: 2),
                  Text('找相似', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) {
                context.read<CartProvider>().removeItem(item);
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(height: 2),
                  Text('删除', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        child:
            _CartItemContent(context: context, item: item, material: material),
      ),
    );
  }

  Future<void> _pickCartItemImage(BuildContext context, OrderItem item) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/cart_images');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'cart_${DateTime.now().millisecondsSinceEpoch}$ext';
      final saved = await File(picked.path).copy('${saveDir.path}/$fileName');
      if (!context.mounted) return;
      context.read<CartProvider>().updateOrderItem(
            item,
            imageUrl: saved.path,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品图已替换'), duration: Duration(seconds: 1)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片替换失败')),
      );
    }
  }

  void _showEditCartItemSheet(BuildContext context, OrderItem item) {
    final titleCtrl = TextEditingController(text: item.title);
    final specCtrl = TextEditingController(text: item.configuration);
    final priceCtrl =
        TextEditingController(text: item.price.toStringAsFixed(item.price % 1 == 0 ? 0 : 2));
    final originCtrl = TextEditingController(
        text: item.originalPrice?.toStringAsFixed(
                (item.originalPrice ?? 0) % 1 == 0 ? 0 : 0) ??
            '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('编辑商品', style: AppTextStyles.normalBold),
              const SizedBox(height: 12),
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '标题')),
              TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(labelText: '规格')),
              TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '价格')),
              TextField(
                  controller: originCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '划线价（可空）')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final price = double.tryParse(priceCtrl.text);
                        final origin = originCtrl.text.isEmpty
                            ? null
                            : double.tryParse(originCtrl.text);
                        context.read<CartProvider>().updateOrderItem(
                              item,
                              title: titleCtrl.text,
                              configuration: specCtrl.text,
                              price: price,
                              originalPrice: origin,
                            );
                        Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ============ 店铺类型切换（点击徽章：天猫/淘宝/国际） ============
  void _pickShopType(BuildContext context, ShoppingCartShop shop) {
    DialogHelpers.showOptionPicker(
      context,
      title: '切换店铺类型',
      options: ShopTypeBadge.typeOptions,
      currentValue: ShopTypeBadge.resolve(shop).text,
    ).then((v) {
      if (v == null) return;
      if (!context.mounted) return;
      context.read<CartProvider>().updateShop(
            shop,
            shopBadge: v,
            isInternational: v == '国际',
          );
    });
  }

  // ============ 管理（店铺编辑入口集中在这里） ============
  void _showManageSheet(BuildContext context) {
    final shops = context.read<CartProvider>().shops;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('管理',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: shops.length,
                  itemBuilder: (_, i) {
                    final shop = shops[i];
                    return ListTile(
                      leading: ShopTypeBadge(shop: shop),
                      title: Text(shop.shopName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${shop.items.length} 件商品',
                          style: const TextStyle(fontSize: 12)),
                      trailing: GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showShopEditSheet(context, shop);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: const Color(0xFFc4c4c4)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('编辑',
                              style: TextStyle(
                                  color: Colors.black87, fontSize: 12)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============ 店铺编辑（店名 + 店铺类型 天猫/淘宝/国际） ============
  void _showShopEditSheet(BuildContext context, ShoppingCartShop shop) {
    final nameCtrl = TextEditingController(text: shop.shopName);
    var selectedType = ShopTypeBadge.resolve(shop).text;
    if (!ShopTypeBadge.typeOptions.contains(selectedType)) {
      selectedType = '天猫';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Text('编辑店铺',
                          style: AppTextStyles.normalBold)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: '店铺名称')),
                  const SizedBox(height: 12),
                  const Text('店铺类型',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: ShopTypeBadge.typeOptions.map((t) {
                      final selected = t == selectedType;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedType = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white,
                              border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : const Color(0xFFc4c4c4)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(t,
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 13)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            context.read<CartProvider>().updateShop(
                                  shop,
                                  shopName: name,
                                  shopBadge: selectedType,
                                  isInternational: selectedType == '国际',
                                );
                            Navigator.pop(ctx);
                          },
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============ 商品项内容（3.4 风格）============
  /// 商品图/名称优先展示素材库随机分配结果（图名严格对应）；
  /// 素材未命名时自动触发豆包 AI 识别起名，识别完成后界面自动刷新。
  Widget _CartItemContent(
      {required BuildContext context,
      required OrderItem item,
      MaterialEntry? material}) {
    // 未命名的素材自动 AI 匹配名称（识别中/失败过的会自动跳过）
    if (material != null && material.title.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.read<MaterialPoolProvider>().aiNameEntry(material);
        }
      });
    }
    final displayImage = material?.imagePath ?? item.imageUrl;
    final displayTitle =
        (material != null && material.title.isNotEmpty)
            ? material.title
            : item.title;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selectIcon(item.isSelected,
              onTap: () =>
                  Provider.of<CartProvider>(context, listen: false).toggleItemSelection(item)),
          const SizedBox(width: 8),
          // 商品图（素材库随机分配，图名对应）
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AppImage(url: displayImage, width: 84, height: 84),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small),
                const SizedBox(height: 4),
                // 规格胶囊（点击进入编辑弹层改规格）
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.5),
                  child: GestureDetector(
                    onTap: () => _showEditCartItemSheet(context, item),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(item.configuration,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.min
                                    .copyWith(color: AppColors.subText)),
                          ),
                          const Icon(Icons.arrow_drop_down,
                              size: 14, color: AppColors.subText),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // 立减/补贴/官方立减 标签
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: item.discountLabels
                      .map((l) => _discountChip(l))
                      .toList(),
                ),
                const SizedBox(height: 6),
                // 服务标签（退货宝/大促价保/超级爆款）
                if (item.serviceTags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: item.serviceTags
                        .map((t) => _serviceTag(t))
                        .toList(),
                  ),
                const SizedBox(height: 6),
                // 价格区（基线对齐，修复金额字体不齐）
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('平台加补后',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFF999999))),
                    const SizedBox(width: 4),
                    Text('¥',
                        style: AppTextStyles.price.copyWith(fontSize: 12)),
                    Text(
                      item.price.toStringAsFixed(
                          item.price % 1 == 0 ? 0 : 1),
                      style: AppTextStyles.price.copyWith(fontSize: 20),
                    ),
                    const SizedBox(width: 6),
                    if (item.originalPrice != null)
                      Text(
                        '¥${item.originalPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
                // 比加入时降价 标签（红底白字胶囊，对齐真实淘宝）
                if (_CartScreenState.priceDropOf(item) != null) ...[
                  const SizedBox(height: 3),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6432E),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '已降 ¥${_CartScreenState.priceDropOf(item)!.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white),
                      ),
                    ),
                  ),
                ],
                if (item.taxInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.taxInfo,
                      style: const TextStyle(
                          color: Color(0xFF999999), fontSize: 11)),
                ],
                const SizedBox(height: 8),
                // 数量步进器（右下角 - 数量 +）
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [_qtyStepper(context, item)],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 数量步进器：直接调 CartProvider.changeQuantity，1~99 边界置灰
  Widget _qtyStepper(BuildContext context, OrderItem item) {
    final cart = context.read<CartProvider>();
    Widget stepBtn(IconData icon, int delta, {required bool disabled}) {
      return GestureDetector(
        onTap: disabled ? null : () => cart.changeQuantity(item, delta),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: disabled
                ? const Color(0xFFF7F7F7)
                : const Color(0xFFF0F0F0),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon,
              size: 14,
              color: disabled
                  ? const Color(0xFFCCCCCC)
                  : const Color(0xFF666666)),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        stepBtn(Icons.remove, -1, disabled: item.quantity <= 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('${item.quantity}', style: AppTextStyles.small),
        ),
        stepBtn(Icons.add, 1, disabled: item.quantity >= 99),
      ],
    );
  }

  Widget _discountChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.red, fontSize: 10)),
    );
  }

  Widget _serviceTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFe8f5e9),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(tag,
          style: const TextStyle(
              color: Color(0xFF2e7d32), fontSize: 10)),
    );
  }

  Widget _selectIcon(bool selected, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFc4c4c4),
            width: 1.5,
          ),
          color: selected ? AppColors.primary : Colors.transparent,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : null,
      ),
    );
  }

  // ============ 底部栏（结算 / 管理两种模式） ============
  Widget _buildBottomBar(BuildContext context, CartProvider cart) {
    if (_managing) return _buildManageBar(context, cart);
    // 勾选商品的划线价总让利（用于「共减」明细行）
    var save = 0.0;
    for (final s in cart.shops) {
      for (final it in s.items) {
        if (it.isSelected &&
            it.originalPrice != null &&
            it.originalPrice! > it.price) {
          save += (it.originalPrice! - it.price) * it.quantity;
        }
      }
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => cart.toggleAllSelection(),
            child: Row(
              children: [
                _selectIcon(cart.isAllSelected, onTap: () => cart.toggleAllSelection()),
                const SizedBox(width: 4),
                const Text('全选', style: AppTextStyles.small),
              ],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('合计：', style: AppTextStyles.small),
                  Text('¥',
                      style: AppTextStyles.price.copyWith(fontSize: 13)),
                  Text(
                    cart.totalPrice.toStringAsFixed(2),
                    style: AppTextStyles.price.copyWith(fontSize: 22),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('不含运费', style: AppTextStyles.min),
                  if (save > 0) ...[
                    const SizedBox(width: 4),
                    Text('共减 ¥${save.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: AppColors.primary, fontSize: 10)),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _checkout(context, cart),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5000), Color(0xFFFF7A33)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '结算(${cart.selectedCount})',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ 管理模式底部栏（全选 / 移入收藏 / 删除） ============
  Widget _buildManageBar(BuildContext context, CartProvider cart) {
    final hasSelection = cart.selectedItemCount > 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => cart.toggleAllSelection(),
            child: Row(
              children: [
                _selectIcon(cart.isAllSelected,
                    onTap: () => cart.toggleAllSelection()),
                const SizedBox(width: 4),
                const Text('全选', style: AppTextStyles.small),
              ],
            ),
          ),
          const Spacer(),
          // 移入收藏（无选中时置灰）
          GestureDetector(
            onTap: hasSelection
                ? () => _moveSelectedToFavorites(context, cart)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color: hasSelection
                        ? AppColors.primary
                        : const Color(0xFFc4c4c4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('移入收藏',
                  style: TextStyle(
                      color: hasSelection
                          ? AppColors.primary
                          : const Color(0xFFc4c4c4),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          // 删除（无选中时置灰）
          GestureDetector(
            onTap: hasSelection ? () => _deleteSelected(context, cart) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: hasSelection
                    ? AppColors.primary
                    : const Color(0xFFc4c4c4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('删除(${cart.selectedItemCount})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // ============ 结算：勾选商品转待付款订单并跳订单页 ============
  void _checkout(BuildContext context, CartProvider cart) {
    if (cart.selectedItemCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先勾选要结算的商品'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }
    final count = cart.selectedCount;
    final total = cart.totalPrice;
    cart.checkoutSelected();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
            '已生成待付款订单（$count 件，共 ¥${total.toStringAsFixed(2)}）'),
        duration: const Duration(milliseconds: 1500),
      ));
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => const OrderListScreen(type: '待付款')),
    );
  }

  /// 单个商品移入收藏（右滑操作）：写入收藏夹后从购物车移除
  void _moveItemToFavorites(
      BuildContext context, OrderItem item, String shopName) {
    final favs = context.read<FavoritesProvider>();
    final already = favs.isFav(item.title);
    if (!already) {
      favs.toggle(SearchResultItem(
        imageUrl: item.imageUrl,
        title: item.title,
        shopName: shopName,
        price: item.price.toStringAsFixed(2),
      ));
    }
    context.read<CartProvider>().removeItem(item);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(already ? '该商品已在收藏夹，已从购物车移除' : '已移入收藏夹'),
          duration: const Duration(seconds: 1)),
    );
  }

  void _moveSelectedToFavorites(BuildContext context, CartProvider cart) {
    // 真收藏：先把选中项写入收藏夹 Provider，再从购物车移除
    final favs = context.read<FavoritesProvider>();
    for (final shop in cart.shops) {
      for (final item in shop.items) {
        if (item.isSelected && !favs.isFav(item.title)) {
          favs.toggle(SearchResultItem(
            imageUrl: item.imageUrl,
            title: item.title,
            shopName: shop.shopName,
            price: item.price.toStringAsFixed(2),
          ));
        }
      }
    }
    final count = cart.selectedItemCount;
    cart.removeSelected();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('已将 $count 件商品移入收藏夹'),
          duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _deleteSelected(
      BuildContext context, CartProvider cart) async {
    final count = cart.selectedItemCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除商品'),
        content: Text('确定要删除选中的 $count 件商品吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    cart.removeSelected();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('已删除 $count 件商品'),
          duration: const Duration(seconds: 1)),
    );
  }
}
