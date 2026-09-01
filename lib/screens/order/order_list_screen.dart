import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_image_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/shop_type_badge.dart';
import 'order_detail_screen.dart';
import 'order_manager_screen.dart';
import 'refund_detail_screen.dart';

/// 我的订单列表（与购物车共用数据源，支持 3.4 商品编辑功能）
class OrderListScreen extends StatefulWidget {
  final String type;
  const OrderListScreen({super.key, this.type = '全部'});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  static const _tabs = ['全部订单', '待付款', '待发货', '已发货', '售后'];

  String get _currentTab => _tabs[_tab.index];

  String get _actionText {
    switch (_currentTab) {
      case '待付款':
        return '去支付';
      case '待发货':
        return '提醒发货';
      case '已发货':
        return '确认收货';
      case '售后':
        return '申请售后';
      default:
        return '查看详情';
    }
  }

  @override
  void initState() {
    super.initState();
    final idx = _tabs.indexOf(_normalizeType(widget.type));
    _tab = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: idx >= 0 ? idx : 0,
    );
    _tab.addListener(() {
      if (_tab.indexIsChanging) setState(() {});
    });
  }

  String _normalizeType(String type) {
    if (type == '全部' || type == '全部订单') return '全部订单';
    if (type.contains('待付款')) return '待付款';
    if (type.contains('待发货')) return '待发货';
    if (type.contains('已发货') || type.contains('待收货')) return '已发货';
    if (type.contains('售后') || type.contains('退款') || type.contains('评价')) return '售后';
    return '全部订单';
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<CartProvider>().shops;
    final filtered = _visibleShops(shops);

    return Scaffold(
      backgroundColor: const Color(0xFFf5f5f5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tab,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black87,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 14),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(18),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
                labelPadding: const EdgeInsets.symmetric(horizontal: 10),
                tabs: _tabs.map((t) => Tab(text: t)).toList(),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _empty()
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _OrderCard(
                            shop: filtered[i].shop,
                            items: filtered[i].items,
                            actionText: _actionText,
                            onEditItem: (item) =>
                                _showEditMenu(filtered[i].shop, item),
                            onDetail: (item) =>
                                _gotoDetail(filtered[i].shop, item),
                          ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 状态过滤 + 搜索过滤（商品标题/规格/店铺名 关键词）
  List<_ShopView> _visibleShops(List<ShoppingCartShop> shops) {
    final q = _query.trim().toLowerCase();
    final result = <_ShopView>[];
    for (final shop in shops) {
      if (!_matchesStatus(shop)) continue;
      if (q.isEmpty || shop.shopName.toLowerCase().contains(q)) {
        result.add(_ShopView(shop, shop.items));
        continue;
      }
      final matched = shop.items
          .where((it) =>
              it.title.toLowerCase().contains(q) ||
              it.configuration.toLowerCase().contains(q))
          .toList();
      if (matched.isNotEmpty) result.add(_ShopView(shop, matched));
    }
    return result;
  }

  bool _matchesStatus(ShoppingCartShop shop) {
    final category = CartProvider.statusCategory(shop.orderSubStatus);
    switch (_currentTab) {
      case '待付款':
        return shop.orderSubStatus.contains('待付款') ||
            shop.orderSubStatus.contains('等待付款');
      case '待发货':
        return category == '待发货' ||
            shop.orderSubStatus.contains('待发货') ||
            shop.orderSubStatus.contains('等待发货');
      case '已发货':
        return category == '待收货' ||
            shop.orderSubStatus.contains('已发货') ||
            shop.orderSubStatus.contains('运输中') ||
            shop.orderSubStatus.contains('派送中') ||
            shop.orderSubStatus.contains('已签收') ||
            shop.orderSubStatus.contains('签收') ||
            shop.orderSubStatus.contains('收货');
      case '售后':
        return category == '退款/售后' ||
            shop.orderSubStatus.contains('退款') ||
            shop.orderSubStatus.contains('售后') ||
            shop.orderSubStatus.contains('评价');
      case '全部订单':
      default:
        // 购物车状态的条目不进订单列表（对齐真实淘宝：购物车 ≠ 订单）
        return !shop.orderSubStatus.contains('购物车');
    }
  }

  // ============ 顶部栏（搜索框 + AI助手/筛选/管理 + 消息角标） ============
  Widget _buildTopBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios,
                color: Colors.black87, size: 22),
          ),
          const SizedBox(width: 8),
          // 搜索框（可输入：按商品关键词/店铺名搜索）
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFf2f2f2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(AppIcons.search,
                      color: Color(0xFF999999), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black87),
                      decoration: const InputDecoration(
                        hintText: '搜索订单',
                        hintStyle: TextStyle(
                            color: Color(0xFF999999), fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() {
                        _searchCtrl.clear();
                        _query = '';
                      }),
                      child: const Icon(Icons.cancel,
                          color: Color(0xFF999999), size: 16),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 筛选 → 订单始终按创建时间自动排序（新订单在最上方），点击仅提示
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('订单已按创建时间自动排序，新订单在最上方'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: _topAction(AppIcons.filter, '筛选'),
          ),
          const SizedBox(width: 12),
          // 管理 → 订单管理页（编辑入口，双击进入）
          GestureDetector(
            onDoubleTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrderManagerScreen()),
            ),
            child: _topAction(AppIcons.list, '管理'),
          ),
          const SizedBox(width: 12),
          // 消息 → 订单管理入口（编辑入口，双击进入）
          GestureDetector(
            onDoubleTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrderManagerScreen()),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(AppIcons.message,
                    color: Colors.black87, size: 26),
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(Radius.circular(9)),
                    ),
                    child: const Text('22',
                        style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topAction(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.black87, fontSize: 10)),
      ],
    );
  }

  // ============ 进入订单/退款详情 ============
  void _gotoDetail(ShoppingCartShop shop, OrderItem item) {
    final isRefund = widget.type == '退款/售后' ||
        widget.type == '售后' ||
        widget.type == '退款' ||
        shop.orderSubStatus.contains('退款') ||
        shop.orderSubStatus.contains('售后');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isRefund
            ? RefundDetailScreen(shop: shop, item: item)
            : OrderDetailScreen(shop: shop, item: item),
      ),
    );
  }

  // ============ 编辑菜单（3.4 商品编辑功能） ============
  void _showEditMenu(ShoppingCartShop shop, OrderItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) =>
          _OrderEditSheet(shop: shop, item: item, parentContext: context),
    );
  }

  Widget _empty() {
    final searching = _query.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 80, color: Color(0xFFc4c4c4)),
          const SizedBox(height: 12),
          Text(searching ? '未找到相关订单' : '暂无${_currentTab}订单',
              style: AppTextStyles.middleSub),
          const SizedBox(height: 8),
          Text(searching ? '换个商品关键词或店铺名试试' : '（这是练习 App，未接真实数据）',
              style: AppTextStyles.min),
        ],
      ),
    );
  }
}

/// 店铺 + 当前应展示的商品（搜索时可能只展示匹配到的商品）
class _ShopView {
  final ShoppingCartShop shop;
  final List<OrderItem> items;
  const _ShopView(this.shop, this.items);
}

// ============ 订单卡片 ============
class _OrderCard extends StatelessWidget {
  final ShoppingCartShop shop;
  final List<OrderItem> items; // 当前应展示的商品（搜索时可能只是部分）
  final String actionText;
  final void Function(OrderItem item) onEditItem;
  final void Function(OrderItem item) onDetail;

  const _OrderCard({
    required this.shop,
    required this.items,
    required this.actionText,
    required this.onEditItem,
    required this.onDetail,
  });

  /// 点击店铺类型徽章：切换 天猫/淘宝/国际
  void _pickShopType(BuildContext context) {
    DialogHelpers.showOptionPicker(
      context,
      title: '切换店铺类型',
      options: ShopTypeBadge.typeOptions,
      currentValue: ShopTypeBadge.resolve(shop).text,
    ).then((v) {
      if (v == null) return;
      context.read<CartProvider>().updateShop(
            shop,
            shopBadge: v,
            isInternational: v == '国际',
          );
    });
  }

  /// 是否退款/售后类订单（售后卡片用不同布局）
  static bool isRefundStatus(String s) =>
      s.contains('退款') || s.contains('退货') || s.contains('售后');

  @override
  Widget build(BuildContext context) {
    // 合计 = 各商品实付价直接相加（实付录入多少就是多少，不再乘规格数量）
    final total = items.fold<double>(0, (sum, item) => sum + item.price);
    final isRefund = isRefundStatus(shop.orderSubStatus);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 店铺头
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onDoubleTap: () => _pickShopType(context),
                  child: ShopTypeBadge(shop: shop),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(shop.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.smallBold),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF999999), size: 18),
                const Spacer(),
                // 售后卡片右上角只写"退款"（橘色），与真实淘宝一致
                Text(isRefund ? '退款' : shop.orderSubStatus,
                    style: AppTextStyles.small.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // 商品列表：点击进入详情，双击弹出编辑菜单
          ...items.map((item) => _OrderItemTile(
                item: item,
                orderStatus: shop.orderSubStatus,
                onTap: () => onDetail(item),
                onDoubleTap: () => onEditItem(item),
              )),
          const Divider(height: 1, color: Color(0xFFf5f5f5)),
          // 底部操作栏（售后卡片无合计行，对齐真实淘宝退款单）
          if (!isRefund)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('共${items.length}件商品 合计：',
                      style: AppTextStyles.min),
                  Text('¥',
                      style: AppTextStyles.price.copyWith(fontSize: 13)),
                  Text(
                    total.toStringAsFixed(2),
                    style: AppTextStyles.price.copyWith(fontSize: 18),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: isRefund
                ? Row(
                    children: [
                      // "更多"（编辑入口，双击打开编辑菜单）
                      _moreBtn('更多',
                          onDoubleTap: () => onEditItem(items.first)),
                      const Spacer(),
                      _capsuleBtn('加入购物车'),
                      const SizedBox(width: 8),
                      _capsuleBtn('钱款去向',
                          onTap: () => onDetail(items.first)),
                      const SizedBox(width: 8),
                      _capsuleBtn('联系商家', highlight: true),
                    ],
                  )
                : Row(
                    children: [
                      // "更多"固定在最左侧（编辑入口，双击打开编辑菜单）
                      _moreBtn('更多',
                          onDoubleTap: () => onEditItem(items.first)),
                      const Spacer(),
                      _outlineBtn('催物流'),
                      const SizedBox(width: 8),
                      _outlineBtn('查看物流', onTap: () => onDetail(items.first)),
                      const SizedBox(width: 8),
                      _primaryBtn(actionText, onTap: () => onDetail(items.first)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 售后卡片按钮：灰底胶囊 / 橘色高亮胶囊（照搬真实淘宝退款单样式）
  Widget _capsuleBtn(String text,
      {VoidCallback? onTap, bool highlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFFFF1E8)
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: TextStyle(
                color: highlight ? AppColors.primary : Colors.black87,
                fontSize: 12,
                fontWeight:
                    highlight ? FontWeight.w500 : FontWeight.normal)),
      ),
    );
  }

  /// "更多"按钮：真实淘宝为无边框纯文字样式，置于行首
  Widget _moreBtn(String text, {VoidCallback? onDoubleTap}) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Text(text,
            style: const TextStyle(color: Colors.black87, fontSize: 12)),
      ),
    );
  }

  Widget _outlineBtn(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFdddddd)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.black87, fontSize: 12)),
      ),
    );
  }

  Widget _primaryBtn(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ============ 订单商品项（可点击编辑） ============
class _OrderItemTile extends StatelessWidget {
  final OrderItem item;
  final String orderStatus; // 店铺级订单状态，决定下方状态行的文案与图标
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const _OrderItemTile({
    required this.item,
    required this.orderStatus,
    required this.onTap,
    this.onDoubleTap,
  });

  Future<void> _pickImage(BuildContext context) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/order_images');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'order_${DateTime.now().millisecondsSinceEpoch}$ext';
      final saved = await File(picked.path).copy('${saveDir.path}/$fileName');
      if (!context.mounted) return;
      // 用商品标题作为 key，详情页也会读取同一张图
      await context
          .read<ProductImageProvider>()
          .setOverride(item.title, saved.path);
      context.read<CartProvider>().updateOrderItem(item, imageUrl: saved.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品图已替换'), duration: Duration(seconds: 1)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片选择失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final override = context.watch<ProductImageProvider>().imageFor(item.title);
    final imageUrl = override ?? item.imageUrl;
    final isRefund = _OrderCard.isRefundStatus(orderStatus);

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap ?? onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: isRefund
            ? _buildRefundLayout(context, imageUrl)
            : _buildNormalLayout(context, imageUrl),
      ),
    );
  }

  // ============ 售后卡片布局（照搬真实淘宝退款/售后列表） ============
  Widget _buildRefundLayout(BuildContext context, String imageUrl) {
    final amount =
        item.refundAmount > 0 ? item.refundAmount : item.price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onDoubleTap: () => _pickImage(context), // 双击换商品图
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(url: imageUrl, width: 80, height: 80),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.small,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 商品行右侧：退款金额（与订单金额一致）
                      Text.rich(
                        TextSpan(
                          text: '退款: ',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF999999)),
                          children: [
                            TextSpan(
                              text: '¥${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 随机商品对应规格（前缀按商品稳定选取）
                  Text(
                    '$_specPrefix:${item.configuration}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.min
                        .copyWith(color: AppColors.subText),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 退款条：灰底圆角整宽（状态跟随退款详情页改动实时同步 + 变体文案 + 金额橘色）
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: '$_refundBarStatus ',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A)),
                    children: _refundBarSpans(amount),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF999999), size: 16),
            ],
          ),
        ),
      ],
    );
  }

  /// 退款条状态文字：与退款详情页的退款状态实时同步（退款成功/待商家退款/退款结束）
  String get _refundBarStatus {
    if (item.refundStatus.isNotEmpty) return item.refundStatus;
    if (orderStatus.contains('成功')) return '退款成功';
    if (orderStatus.contains('结束')) return '退款结束';
    return '待商家退款';
  }

  /// 退款条变体文案：0极速退款成功/1退款金额/2支付渠道/3平台支持退款
  /// 支付渠道跟订单内选择的支付方式一致；优惠随机生成、可在编辑菜单隐藏
  List<TextSpan> _refundBarSpans(double amount) {
    const grey = TextStyle(fontSize: 12, color: Color(0xFF999999));
    const orange = TextStyle(fontSize: 12, color: Color(0xFFFF5000));
    final pending = _refundBarStatus == '待商家退款';
    final style = item.refundBarStyle < 0 ? 1 : item.refundBarStyle;
    if (style == 3) {
      return [const TextSpan(text: '平台支持退款', style: grey)];
    }
    final label = switch (style) {
      0 => pending ? '极速退款中 ' : '极速退款成功 ',
      2 => item.paymentMethod.contains('微信') ? '微信 ' : '支付宝 ',
      _ => '退款金额 ',
    };
    final spans = <TextSpan>[
      TextSpan(text: label, style: grey),
      TextSpan(text: '¥${amount.toStringAsFixed(2)}', style: orange),
    ];
    if (item.showRefundDiscount && item.refundDiscount > 0) {
      spans.add(const TextSpan(text: '，优惠 ', style: grey));
      spans.add(TextSpan(
          text: '¥${item.refundDiscount.toStringAsFixed(2)}',
          style: orange));
    }
    return spans;
  }

  /// 规格前缀：按商品标题稳定选取（颜色分类/商品规格）
  String get _specPrefix {
    final sum = item.title.codeUnits.fold<int>(0, (a, b) => a + b);
    return sum.isEven ? '颜色分类' : '商品规格';
  }

  // ============ 普通订单布局 ============
  Widget _buildNormalLayout(BuildContext context, String imageUrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onDoubleTap: () => _pickImage(context), // 双击换商品图
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(
                  url: imageUrl,
                  width: 80,
                  height: 80,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.configuration,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.min
                        .copyWith(color: AppColors.subText),
                  ),
                  const SizedBox(height: 6),
                  // 保障标签：与详情页 detailTags 同一份数据，编辑后两边同步
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...item.detailTags.map(_greenTag),
                      _greenTag(item.returnText),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // "平台加补后 / 领消费券后约" 价格行已按需求删除
                  if (item.showTaxInfoLine && item.taxInfo.isNotEmpty)
                    Text(item.taxInfo,
                        style: const TextStyle(
                            color: Color(0xFF999999), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        if (_statusLine != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(_statusIcon,
                    color: const Color(0xFF999999), size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(_statusLine!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.min
                          .copyWith(color: const Color(0xFF666666))),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF999999), size: 16),
              ],
            ),
          ),
      ],
    );
  }

  /// 状态行文案：随订单状态变化（对齐真实淘宝各状态的展示格式）
  /// - 退款类 → "退款成功 退款金额 ¥xx"（参照真实淘宝退款单格式）
  /// - 交易关闭 → "交易关闭"
  /// - 待付款 → "等待买家付款"
  /// - 待发货 → "等待卖家发货"
  /// - 已签收/交易成功 → "已签收 · 您的快件已送达，签收人：单位前台"
  /// - 已发货/运输中 → 商品自带的物流文字（可在编辑菜单中修改）
  String? get _statusLine {
    final s = orderStatus;
    if (s.contains('退款') || s.contains('退货') || s.contains('售后')) {
      if (s.contains('成功')) {
        final amount = (item.refundAmount > 0 ? item.refundAmount : item.price)
            .toStringAsFixed(2);
        return '退款成功 退款金额 ¥$amount';
      }
      if (s.contains('结束')) return '退款结束';
      return '退款中 · 等待商家处理';
    }
    if (s.contains('交易关闭')) return '交易关闭';
    if (s.contains('待付款') || s.contains('等待付款')) return '等待买家付款';
    if (s.contains('待发货') || s.contains('等待发货')) return '等待卖家发货';
    if (s.contains('签收') || s.contains('交易成功')) {
      return '已签收 · 您的快件已送达，签收人：单位前台';
    }
    return item.logistics.isEmpty ? null : item.logistics;
  }

  IconData get _statusIcon {
    final s = orderStatus;
    if (s.contains('退款') || s.contains('退货') || s.contains('售后')) {
      return Icons.assignment_return;
    }
    if (s.contains('交易关闭')) return Icons.cancel_outlined;
    if (s.contains('待付款') || s.contains('等待付款')) return Icons.payment;
    if (s.contains('待发货') || s.contains('等待发货')) return Icons.schedule;
    if (s.contains('签收') || s.contains('交易成功')) {
      return Icons.check_circle_outline;
    }
    return Icons.local_shipping;
  }

  Widget _greenTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFF2E7D32), fontSize: 10)),
    );
  }
}

// ============ 编辑菜单 BottomSheet ============
class _OrderEditSheet extends StatefulWidget {
  final ShoppingCartShop shop;
  final OrderItem item;
  final BuildContext parentContext;

  const _OrderEditSheet({
    required this.shop,
    required this.item,
    required this.parentContext,
  });

  @override
  State<_OrderEditSheet> createState() => _OrderEditSheetState();
}

class _OrderEditSheetState extends State<_OrderEditSheet> {
  late OrderItem _item;

  /// 服务标签类菜单项：单击切换"添加/移除"标签（detailTags），卡片绿标签即时变化
  static const _tagLabels = ['破损包赔', '15天价保', '15天退货'];

  static const _menuItems = [
    ('破损包赔', Icons.verified_user),
    ('15天价保', Icons.timer),
    ('15天退货', Icons.assignment_return),
    ('修改 7天无理由 文字', Icons.edit_note),
    ('修改状态标题', Icons.title),
    ('修改倒计时', Icons.timelapse),
    ('修改物流状态', Icons.local_shipping),
    ('修改创建时间', Icons.access_time_filled),
    ('修改付款时间', Icons.payment),
    ('修改发货时间', Icons.fire_truck),
    ('修改地址', Icons.location_on),
    ('修改收件人', Icons.person),
    ('标记为已签收', Icons.check_circle),
    ('修改签收/派送文字', Icons.edit),
    ('修改退款条样式', Icons.autorenew),
    ('隐藏"准时送达"行', Icons.visibility_off),
    ('隐藏"进口税"行', Icons.visibility_off),
    ('隐藏"优惠"', Icons.visibility_off),
  ];

  /// 是否售后订单（退款卡片追加"修改退款金额"入口）
  bool get _isRefund => _OrderCard.isRefundStatus(widget.shop.orderSubStatus);

  /// 当前应展示的菜单（售后订单在最上方加"修改退款金额"）
  List<(String, IconData)> get _visibleMenuItems {
    if (!_isRefund) return _menuItems;
    return [('修改退款金额', Icons.payments), ..._menuItems];
  }

  @override
  void initState() {
    super.initState();
    _item = widget.item;
  }

  /// 修改完成后的统一反馈（用订单列表页的 Scaffold 弹 SnackBar）
  void _toast(String msg) {
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CartProvider>();
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFf0f0f0))),
            ),
            child: Row(
              children: [
                const Text('订单编辑',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Color(0xFF999999)),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _visibleMenuItems.length,
              itemBuilder: (context, index) {
                final (label, icon) = _visibleMenuItems[index];
                final hidden = label.startsWith('隐藏');
                final isOn = _switchValue(label);
                final isTag = _tagLabels.contains(label);
                // 编辑菜单内的按钮：单击直接修改（入口双击、菜单内单击规则）
                return ListTile(
                  leading: Icon(icon, color: const Color(0xFF666666)),
                  title: Text(label),
                  trailing: hidden
                      ? Switch(
                          value: isOn,
                          onChanged: (v) => _handleSwitch(label, provider, v),
                          activeColor: AppColors.primary,
                        )
                      : isTag
                          ? Icon(
                              _item.detailTags.contains(label)
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: _item.detailTags.contains(label)
                                  ? AppColors.primary
                                  : const Color(0xFFcccccc),
                            )
                          : const Icon(Icons.chevron_right,
                              color: Color(0xFFcccccc)),
                  onTap: () => _handleMenuTap(label, provider),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _switchValue(String label) {
    if (label == '隐藏"准时送达"行') return !_item.showOnTime;
    if (label == '隐藏"进口税"行') return !_item.showTaxInfoLine;
    if (label == '隐藏"优惠"') return !_item.showRefundDiscount;
    return false;
  }

  void _handleSwitch(String label, CartProvider provider, bool value) {
    if (label == '隐藏"准时送达"行') {
      provider.updateOrderItem(_item, showOnTime: !value);
    } else if (label == '隐藏"进口税"行') {
      provider.updateOrderItem(_item, showTaxInfoLine: !value);
    } else if (label == '隐藏"优惠"') {
      provider.updateOrderItem(_item, showRefundDiscount: !value);
    }
  }

  /// 服务标签（破损包赔/15天价保/15天退货）：单击切换 添加/移除，卡片绿标签即时变化
  void _toggleTag(String label, CartProvider provider) {
    final tags = List<String>.from(_item.detailTags);
    final had = tags.contains(label);
    if (had) {
      tags.remove(label);
    } else {
      tags.add(label);
    }
    provider.updateOrderItem(_item, detailTags: tags);
    setState(() {});
    _toast(had ? '已移除「$label」标签' : '已添加「$label」标签');
  }

  /// 修改退款金额（售后订单）：退款卡片的"退款: ¥金额"与退款条金额即时更新
  void _editRefundAmount(CartProvider provider) {
    final current =
        _item.refundAmount > 0 ? _item.refundAmount : _item.price;
    Navigator.of(context).pop();
    DialogHelpers.showTextInput(
      widget.parentContext,
      title: '修改退款金额',
      initial: current.toStringAsFixed(2),
    ).then((v) {
      final n = double.tryParse(v ?? '');
      if (n == null || n <= 0) return;
      provider.updateOrderItem(_item, refundAmount: n);
      _toast('退款金额已修改为 ¥${n.toStringAsFixed(2)}');
    });
  }

  void _handleMenuTap(String label, CartProvider provider) {
    // 服务标签切换（修复：之前这三项点击无任何反应）
    if (_tagLabels.contains(label)) {
      _toggleTag(label, provider);
      return;
    }
    if (label == '修改退款金额') {
      _editRefundAmount(provider);
      return;
    }
    if (label == '标记为已签收') {
      provider.markSigned(widget.shop, widget.item);
      Navigator.of(context).pop();
      _toast('已标记为已签收');
      return;
    }
    if (label == '修改状态标题') {
      _showStatusPicker(provider);
      return;
    }
    // 三个时间字段统一使用滚动时间选择器（用父级 context 打开，避免弹层关闭后 context 失效）
    if (label == '修改创建时间' || label == '修改付款时间' || label == '修改发货时间') {
      String initial;
      ValueChanged<String> onSave;
      switch (label) {
        case '修改创建时间':
          initial = _item.createTime;
          onSave = (v) => provider.updateOrderItem(_item, createTime: v);
          break;
        case '修改付款时间':
          initial = _item.payTime;
          onSave = (v) => provider.updateOrderItem(_item, payTime: v);
          break;
        default:
          initial = _item.shipTime;
          onSave = (v) => provider.updateOrderItem(_item, shipTime: v);
      }
      Navigator.of(context).pop();
      DialogHelpers.showDateTimePicker(widget.parentContext,
              title: label, initial: initial)
          .then((v) {
        if (v != null && v.isNotEmpty) {
          onSave(v);
          _toast('$label成功：$v');
        }
      });
      return;
    }
    // 倒计时：滚动式选择器（天+小时双滚轮）
    if (label == '修改倒计时') {
      Navigator.of(context).pop();
      DialogHelpers.showCountdownPicker(
        widget.parentContext,
        title: '修改倒计时',
        initial:
            _item.countDown.isEmpty ? '还剩3天21小时自动确认' : _item.countDown,
      ).then((v) {
        if (v != null && v.isNotEmpty) {
          provider.updateOrderItem(_item, countDown: v);
          _toast('倒计时已修改：$v');
        }
      });
      return;
    }
    if (label == '修改退款条样式') {
      Navigator.of(context).pop();
      const styles = ['极速退款成功', '退款金额', '支付宝/微信（跟随订单支付方式）', '平台支持退款（无金额）'];
      DialogHelpers.showOptionPicker(
        widget.parentContext,
        title: '修改退款条样式',
        options: styles,
        currentValue: styles[_item.refundBarStyle.clamp(0, 3)],
      ).then((v) {
        if (v == null) return;
        provider.updateOrderItem(_item, refundBarStyle: styles.indexOf(v));
        _toast('退款条样式已切换为「$v」');
      });
      return;
    }
    if (label == '隐藏"准时送达"行') {
      provider.updateOrderItem(_item, showOnTime: !_item.showOnTime);
      return;
    }
    if (label == '隐藏"进口税"行') {
      provider.updateOrderItem(_item, showTaxInfoLine: !_item.showTaxInfoLine);
      return;
    }
    if (label == '隐藏"优惠"') {
      provider.updateOrderItem(_item,
          showRefundDiscount: !_item.showRefundDiscount);
      return;
    }
    _showTextEditDialog(label, provider);
  }

  /// 订单状态：9 个固定选项，改动后自动归入对应栏目
  /// 注意：弹层关闭后必须用 parentContext 打开选择器，否则 context 失效导致选择无反应
  void _showStatusPicker(CartProvider provider) {
    Navigator.of(context).pop();
    DialogHelpers.showOptionPicker(
      widget.parentContext,
      title: '修改订单状态',
      options: CartProvider.orderStatusOptions,
      currentValue: _item.statusTitle,
    ).then((v) {
      if (v != null) {
        provider.updateOrderStatus(widget.shop, widget.item, v);
        _toast('订单状态已修改为「$v」');
      }
    });
  }

  /// 文本类编辑：先关菜单，再用订单列表页 context 打开输入框，保存后弹反馈
  void _showTextEditDialog(String label, CartProvider provider) {
    String initial;
    void Function(String) apply;
    switch (label) {
      case '修改 7天无理由 文字':
        initial = _item.returnText;
        apply = (v) => provider.updateOrderItem(_item, returnText: v);
        break;
      case '修改状态标题':
        initial = _item.statusTitle;
        apply = (v) => provider.updateOrderItem(_item, statusTitle: v);
        break;
      case '修改物流状态':
        initial = _item.logistics;
        apply = (v) => provider.updateOrderItem(_item, logistics: v);
        break;
      case '修改地址':
        initial = _item.address;
        apply = (v) => provider.updateOrderItem(_item, address: v);
        break;
      case '修改收件人':
        initial = _item.receiver;
        apply = (v) => provider.updateOrderItem(_item, receiver: v);
        break;
      case '修改签收/派送文字':
        initial = _item.deliveryText;
        apply = (v) => provider.updateOrderItem(_item, deliveryText: v);
        break;
      default:
        return;
    }

    Navigator.of(context).pop();
    DialogHelpers.showTextInput(
      widget.parentContext,
      title: label,
      initial: initial,
      maxLines: label == '修改地址' ? 3 : 1,
    ).then((value) {
      if (value == null || value.isEmpty) return;
      apply(value);
      _toast('已$label');
    });
  }
}
