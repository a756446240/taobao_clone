import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/footprints_provider.dart';
import '../../providers/product_image_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/product_card.dart';
import 'qa_screen.dart';
import 'reviews_screen.dart';
import 'shop_home_screen.dart';
import '../message/chat_screen.dart';

/// 商品详情页（1:1 对齐淘宝详情页结构）
/// 图廊 → 价格横幅 → 标题 → 服务 → 规格 → 评价 → 店铺 → 看了又看
/// 底部：店铺/客服/收藏 + 加入购物车 + 立即购买
class ProductDetailScreen extends StatefulWidget {
  final SearchResultItem item;
  const ProductDetailScreen({super.key, required this.item});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _galleryIndex = 0;

  /// 收藏状态全局化：读 FavoritesProvider，收藏夹页同步生效
  bool get _collected =>
      context.watch<FavoritesProvider>().isFav(widget.item.title);

  @override
  void initState() {
    super.initState();
    // 进详情即记一条真实足迹（同标题去重提前，持久化）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FootprintsProvider>().add(widget.item);
      }
    });
  }

  /// 切换收藏，返回切换后的状态（回调里用返回值，不能 watch）
  bool _toggleCollect() =>
      context.read<FavoritesProvider>().toggle(widget.item);

  /// 划线价：现价的 1.4 倍取整
  String get _originPrice {
    final p = double.tryParse(widget.item.price) ?? 0;
    return (p * 1.4).toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final overrideUrl =
        context.watch<ProductImageProvider>().imageFor(widget.item.title);
    final imageUrl = overrideUrl ?? widget.item.imageUrl;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                _buildGallery(imageUrl),
                _buildPriceBanner(),
                _buildTitleBlock(),
                const SizedBox(height: 8),
                _buildServiceRow(),
                _buildSelectRow(),
                const SizedBox(height: 8),
                _buildReviewBlock(),
                const SizedBox(height: 8),
                _buildQaBlock(),
                const SizedBox(height: 8),
                _buildShopCard(),
                const SizedBox(height: 8),
                _buildRecommend(),
              ],
            ),
            // 顶部悬浮按钮
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  _circleBtn(Icons.arrow_back_ios_new,
                      () => Navigator.of(context).pop()),
                  const Spacer(),
                  _circleBtn(Icons.share_outlined, () {
                    Clipboard.setData(ClipboardData(
                        text:
                            '【淘宝】https://m.tb.cn/h.pD42 ${widget.item.title}，快来看看吧'));
                    _toast('链接已复制，快去分享吧');
                  }),
                  const SizedBox(width: 8),
                  _circleBtn(Icons.more_horiz, _showMoreSheet),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
      ));
  }

  /// 顶部「更多」→ 真实功能菜单弹层
  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),
            const Text('更多',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _moreAction(ctx, Icons.share_outlined, '分享宝贝', () {
              Clipboard.setData(ClipboardData(
                  text:
                      '【淘宝】https://m.tb.cn/h.pD42 ${widget.item.title}，快来看看吧'));
              _toast('链接已复制，快去分享吧');
            }),
            _moreAction(ctx, Icons.star_border, '收藏宝贝', () {
              final now = _toggleCollect();
              _toast(now ? '已加入收藏' : '已取消收藏');
            }),
            _moreAction(ctx, Icons.flag_outlined, '举报商品', () async {
              final reason = await DialogHelpers.showOptionPicker(
                context,
                title: '选择举报原因',
                options: const [
                  '假冒伪劣',
                  '虚假宣传',
                  '价格欺诈',
                  '违禁商品',
                  '侵犯知识产权',
                  '其他问题',
                ],
                currentValue: '',
              );
              if (reason != null) {
                _toast('已提交「$reason」举报，平台将尽快核实');
              }
            }),
            _moreAction(ctx, Icons.home_outlined, '返回首页', () {
              Navigator.of(context).popUntil((r) => r.isFirst);
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _moreAction(
      BuildContext sheetCtx, IconData icon, String label, VoidCallback action) {
    return ListTile(
      leading: Icon(icon, size: 22, color: const Color(0xFF333333)),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.of(sheetCtx).pop();
        action();
      },
    );
  }

  /// 服务行 → 服务保障说明弹层
  void _showServiceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Center(
                child: Text('服务保障',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              SizedBox(height: 14),
              _ServiceItem(
                icon: Icons.assignment_return_outlined,
                title: '7天无理由退换',
                desc: '签收后 7 天内，商品完好可申请无理由退换货',
              ),
              SizedBox(height: 12),
              _ServiceItem(
                icon: Icons.local_shipping_outlined,
                title: '运费险',
                desc: '退换货运费由保险公司赔付，上门取件自动抵扣',
              ),
              SizedBox(height: 12),
              _ServiceItem(
                icon: Icons.flash_on_outlined,
                title: '极速退款',
                desc: '信誉良好用户退货退款，平台先行垫付极速到账',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 进店逛逛 / 底部店铺图标 → 店铺主页
  void _gotoShop(String shopName) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ShopHomeScreen(shopName: shopName)),
    );
  }

  // ============ 图廊（同图 3 页可滑动，右下页码胶囊） ============
  Widget _buildGallery(String imageUrl) {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: PageView.builder(
              itemCount: 3,
              onPageChanged: (i) => setState(() => _galleryIndex = i),
              itemBuilder: (_, page) => GestureDetector(
                onTap: () => _openGalleryViewer(imageUrl, page),
                child: imageUrl.isEmpty
                    ? Container(
                        color: const Color(0xFFF5F5F5),
                        child: const Icon(Icons.image,
                            size: 80, color: Color(0xFFDDDDDD)),
                      )
                    : AppImage(url: imageUrl, fit: BoxFit.cover),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_galleryIndex + 1}/3',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  /// 点击图廊 → 全屏大图查看器（双指缩放 + 左右翻页）
  void _openGalleryViewer(String imageUrl, int initialPage) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _GalleryViewer(
            imageUrl: imageUrl, initialPage: initialPage),
      ),
    );
  }

  // ============ 价格横幅（橙红渐变） ============
  Widget _buildPriceBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5000), Color(0xFFFF2E4D)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('券后价 ',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                  const Text('¥',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  Text(widget.item.price,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 2),
              Text('原价 ¥$_originPrice',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      decoration: TextDecoration.lineThrough)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.item.commentCount.isNotEmpty)
                Text(widget.item.commentCount,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('大促价保',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ 标题区 ============
  Widget _buildTitleBlock() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2, right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('天猫',
                    style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
              Expanded(
                child: Text(widget.item.title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.35)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                widget.item.goodRate.isNotEmpty
                    ? widget.item.goodRate
                    : '98%好评',
                style: AppTextStyles.min
                    .copyWith(color: AppColors.subText),
              ),
              const SizedBox(width: 12),
              Text('发货地 广东广州',
                  style: AppTextStyles.min
                      .copyWith(color: AppColors.subText)),
            ],
          ),
        ],
      ),
    );
  }

  // ============ 服务行 ============
  Widget _buildServiceRow() {
    return _whiteRow(
      title: '服务',
      child: Expanded(
        child: Text('7天无理由 · 运费险 · 极速退款',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.small),
      ),
      onTap: _showServiceSheet,
    );
  }

  // ============ 选择规格行 ============
  Widget _buildSelectRow() {
    return _whiteRow(
      title: '选择',
      child: Expanded(
        child: Text('颜色分类 · 数量',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.small
                .copyWith(color: AppColors.subText)),
      ),
      onTap: () => _openSkuSheet(buyNow: false),
    );
  }

  Widget _whiteRow({
    required String title,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Text(title,
                style: AppTextStyles.small
                    .copyWith(color: AppColors.subText)),
            const SizedBox(width: 16),
            child,
            const Icon(Icons.chevron_right,
                color: Color(0xFFC4C4C4), size: 18),
          ],
        ),
      ),
    );
  }

  // ============ 评价区 ============
  Widget _buildReviewBlock() {
    const reviews = [
      ('淘友**酱', '宝贝质量很好，和描述的一样，物流也很快，好评！'),
      ('爱吃橘子的猫', '第二次回购了，性价比很高，推荐入手~'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 单击进入全部评价页
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => ReviewsScreen(item: widget.item)),
            ),
            child: Row(
              children: [
                Text('宝贝评价（2000+）', style: AppTextStyles.smallBold),
                const Spacer(),
                Text(
                  widget.item.goodRate.isNotEmpty
                      ? widget.item.goodRate
                      : '98%好评',
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 12),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFC4C4C4), size: 16),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...reviews.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor:
                          AppColors.primary.withOpacity(0.12),
                      child: Text(r.$1[0],
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$1,
                              style: AppTextStyles.min
                                  .copyWith(color: AppColors.subText)),
                          const SizedBox(height: 2),
                          Text(r.$2,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.small),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ============ 问大家区 ============
  Widget _buildQaBlock() {
    final entries = buildQaEntries(widget.item.title);
    final totalAnswers =
        entries.fold<int>(0, (sum, e) => sum + e.answers.length);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // 单击进入问大家列表页
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => QaScreen(item: widget.item)),
      ),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('问大家（${entries.length}）',
                    style: AppTextStyles.smallBold),
                const Spacer(),
                Text('共$totalAnswers个回答',
                    style: const TextStyle(
                        color: AppColors.primary, fontSize: 12)),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFC4C4C4), size: 16),
              ],
            ),
            const SizedBox(height: 10),
            for (final e in entries.take(2))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('问',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.question,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.small),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.answers.length}个回答',
                        style: AppTextStyles.min),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============ 店铺卡片 ============
  Widget _buildShopCard() {
    final name = widget.item.shopName;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Text(name.isNotEmpty ? name[0] : '店',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.smallBold),
                const SizedBox(height: 3),
                Text('描述相符 4.8 · 服务态度 4.9 · 物流服务 4.8',
                    style: AppTextStyles.min
                        .copyWith(color: AppColors.subText)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _gotoShop(name),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('进店逛逛',
                  style:
                      TextStyle(color: AppColors.primary, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  // ============ 看了又看 ============
  Widget _buildRecommend() {
    final others = MockData.guessLikeGoods
        .where((g) => g.title != widget.item.title)
        .toList();
    if (others.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('看了又看', style: AppTextStyles.smallBold),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.62,
            ),
            itemCount: others.length,
            itemBuilder: (_, i) => ProductCard(item: others[i]),
          ),
        ],
      ),
    );
  }

  // ============ 底部购买栏 ============
  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              _bottomIcon(Icons.storefront_outlined, '店铺',
                  () => _gotoShop(widget.item.shopName)),
              _bottomIcon(Icons.headset_mic_outlined, '客服', () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversation: Conversation(
                        avatar: '',
                        title: widget.item.shopName,
                        description: '店铺客服在线',
                        createAt: '',
                      ),
                      accentColor: const Color(0xFFFF5000),
                    ),
                  ),
                );
              }),
              _bottomIcon(
                _collected ? Icons.star : Icons.star_border,
                '收藏',
                () {
                  final now = _toggleCollect();
                  _toast(now ? '已加入收藏' : '已取消收藏');
                },
                active: _collected,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openSkuSheet(buyNow: false),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Color(0xFFFFB300),
                        Color(0xFFFF8F00),
                      ]),
                      borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(20)),
                    ),
                    child: const Text('加入购物车',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => _openSkuSheet(buyNow: true),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Color(0xFFFF5000),
                        Color(0xFFFF2E4D),
                      ]),
                      borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(20)),
                    ),
                    child: const Text('立即购买',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomIcon(IconData icon, String label, VoidCallback onTap,
      {bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: active
                    ? const Color(0xFFFFC107)
                    : const Color(0xFF333333)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF333333))),
          ],
        ),
      ),
    );
  }

  // ============ SKU 选择底部抽屉 ============
  void _openSkuSheet({required bool buyNow}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkuSheet(item: widget.item, buyNow: buyNow),
    );
  }
}

/// SKU 选择抽屉：颜色规格 + 数量 + 确认
class _SkuSheet extends StatefulWidget {
  final SearchResultItem item;
  final bool buyNow;
  const _SkuSheet({required this.item, required this.buyNow});

  @override
  State<_SkuSheet> createState() => _SkuSheetState();
}

class _SkuSheetState extends State<_SkuSheet> {
  static const _specs = ['默认款', '升级款', '礼盒装'];

  /// 各规格的加价（在商品基础价上叠加）
  static const _specDelta = {'默认款': 0.0, '升级款': 30.0, '礼盒装': 60.0};

  String _spec = _specs[0];
  int _qty = 1;

  /// 各规格库存：由商品名哈希生成（同一商品稳定，不同商品各异），礼盒装小概率缺货
  late final Map<String, int> _stocks = _buildStocks();

  Map<String, int> _buildStocks() {
    var h = 0;
    for (final c in widget.item.title.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return {
      '默认款': 120 + h % 400,
      '升级款': 20 + (h ~/ 7) % 180,
      '礼盒装': h % 5 == 0 ? 0 : 5 + (h ~/ 13) % 60,
    };
  }

  double get _basePrice => double.tryParse(widget.item.price) ?? 0;

  int get _stock => _stocks[_spec] ?? 0;

  /// 当前规格单价文案（整数不带小数点）
  String get _priceText {
    final p = _basePrice + (_specDelta[_spec] ?? 0);
    return p % 1 == 0 ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
  }

  void _selectSpec(String s) {
    final stock = _stocks[s] ?? 0;
    if (stock <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('该规格暂时缺货，看看其他规格吧'),
          duration: Duration(milliseconds: 1200),
        ));
      return;
    }
    setState(() {
      _spec = s;
      if (_qty > stock) _qty = stock;
    });
  }

  @override
  Widget build(BuildContext context) {
    final overrideUrl =
        context.watch<ProductImageProvider>().imageFor(widget.item.title);
    final imageUrl = overrideUrl ?? widget.item.imageUrl;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 商品摘要
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: imageUrl.isEmpty
                        ? Container(
                            width: 84,
                            height: 84,
                            color: const Color(0xFFF5F5F5),
                            child: const Icon(Icons.image,
                                color: Color(0xFFDDDDDD)),
                          )
                        : AppImage(
                            url: imageUrl, width: 84, height: 84),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('¥',
                                style: AppTextStyles.price
                                    .copyWith(fontSize: 13)),
                            Text(_priceText,
                                style: AppTextStyles.price
                                    .copyWith(fontSize: 22)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 库存联动：紧张时橙色提示
                        Text(
                          _stock < 30 ? '库存紧张，仅剩 $_stock 件' : '库存 $_stock 件',
                          style: AppTextStyles.min.copyWith(
                              color: _stock < 30
                                  ? AppColors.primary
                                  : AppColors.subText),
                        ),
                        const SizedBox(height: 2),
                        Text('已选：$_spec，$_qty 件',
                            style: AppTextStyles.min.copyWith(
                                color: AppColors.subText)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // 规格
              const Text('颜色分类',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _specs.map((s) {
                  final selected = s == _spec;
                  final outOfStock = (_stocks[s] ?? 0) <= 0;
                  return GestureDetector(
                    onTap: () => _selectSpec(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFFF1EC)
                            : const Color(0xFFF5F5F5),
                        border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        outOfStock ? '$s（缺货）' : s,
                        style: TextStyle(
                            fontSize: 13,
                            color: outOfStock
                                ? const Color(0xFFBBBBBB)
                                : selected
                                    ? AppColors.primary
                                    : Colors.black87),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // 数量
              Row(
                children: [
                  const Text('购买数量',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  _qtyBtn(Icons.remove, _qty > 1
                      ? () => setState(() => _qty--)
                      : null),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('$_qty',
                        style: const TextStyle(fontSize: 15)),
                  ),
                  _qtyBtn(
                      Icons.add,
                      _qty < _stock
                          ? () => setState(() => _qty++)
                          : null),
                ],
              ),
              const SizedBox(height: 20),
              // 确认按钮
              GestureDetector(
                onTap: _stock > 0 ? _confirm : null,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _stock > 0
                        ? const [Color(0xFFFF5000), Color(0xFFFF2E4D)]
                        : const [Color(0xFFCCCCCC), Color(0xFFBBBBBB)]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    widget.buyNow ? '立即购买' : '加入购物车',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon,
            size: 16,
            color: onTap == null
                ? const Color(0xFFCCCCCC)
                : Colors.black87),
      ),
    );
  }

  void _confirm() {
    // 结算价 = 基础价 + 规格加价；数量兜底不超过库存
    final price = _basePrice + (_specDelta[_spec] ?? 0);
    final qty = _qty > _stock ? _stock : _qty;
    final overrideUrl = context
        .read<ProductImageProvider>()
        .imageFor(widget.item.title);
    context.read<CartProvider>().addToCart(
          shopName: widget.item.shopName,
          title: widget.item.title,
          price: price,
          imageUrl: overrideUrl ?? widget.item.imageUrl,
          spec: _spec,
          quantity: qty,
          asPendingOrder: widget.buyNow,
        );
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(widget.buyNow
            ? '已生成待付款订单，去订单页看看吧'
            : '已加入购物车'),
        duration: const Duration(milliseconds: 1500),
      ));
  }
}

/// 服务保障条目（弹层用）
class _ServiceItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _ServiceItem(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: const Color(0xFFFF5000)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF999999))),
            ],
          ),
        ),
      ],
    );
  }
}

/// 全屏大图查看器：双指缩放（0.5x-4x）+ 左右翻页 + 点击关闭
class _GalleryViewer extends StatefulWidget {
  final String imageUrl;
  final int initialPage;
  const _GalleryViewer({required this.imageUrl, required this.initialPage});

  @override
  State<_GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<_GalleryViewer> {
  late final PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialPage;
    _ctrl = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _ctrl,
            itemCount: 3,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, __) => GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: widget.imageUrl.isEmpty
                      ? const Icon(Icons.image,
                          size: 120, color: Color(0xFF666666))
                      : AppImage(
                          url: widget.imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          // 页码指示
          Positioned(
            left: 0,
            right: 0,
            bottom: 32,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_index + 1}/3',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12)),
              ),
            ),
          ),
          // 关闭按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
