import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/material_pool_provider.dart';
import '../../providers/product_image_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/product_card.dart';
import '../../widgets/shop_type_badge.dart';
import '../message/chat_screen.dart';
import '../product/shop_home_screen.dart';
import 'channel_orders.dart';
import 'logistics_screen.dart';
import 'order_detail_screen.dart';
import 'rate_order_screen.dart';
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
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  /// 顶部频道：全部订单 / 购物 / 闪购(外卖) / 飞猪(旅行)（撑满整宽，指示条滑动切换）
  static const _channels = ['全部订单', '购物', '闪购', '飞猪'];
  static const _channelBadges = {2: '外卖', 3: '旅行'};
  late final TabController _channelCtrl;
  int _channel = 0;
  int _subIndex = 0;

  /// 各频道的子 Tab（对齐真实淘宝）
  static const _subTabs = [
    ['全部', '待付款', '待发货', '待收货', '待评价', '退款·售后'], // 全部订单
    ['全部', '待付款', '待发货', '待收货', '待评价', '退款·售后'], // 购物
    ['全部', '待付款', '待收货', '退款·售后'], // 闪购
    ['全部', '待付款', '待出行', '待评价', '已关闭'], // 飞猪
  ];

  List<String> get _tabs => _subTabs[_channel];

  /// 子 Tab 标签 → 内部状态过滤 key
  String get _currentTab {
    final label = _tabs[_subIndex.clamp(0, _tabs.length - 1)];
    switch (label) {
      case '全部':
        return '全部订单';
      case '待收货':
        return '已发货';
      case '退款·售后':
        return '售后';
      default:
        return label; // 待付款/待发货/待出行/待评价/已关闭
    }
  }

  /// 闪购/飞猪频道订单（确定性随机生成，删除仅会话内生效）
  late final List<ChannelOrder> _shangouOrders = buildShangouOrders();
  late final List<ChannelOrder> _feizhuOrders = buildFeizhuOrders();
  final Set<String> _removedChannelIds = {};

  /// 频道订单支付后的状态覆盖（订单 id → 新状态，仅会话内生效）
  final Map<String, String> _statusOverrides = {};

  String get _actionText {
    switch (_currentTab) {
      case '待付款':
        return '去支付';
      case '待发货':
        return '提醒发货';
      case '已发货':
        return '确认收货';
      case '待评价':
        return '评价';
      case '售后':
        return '申请售后';
      default:
        return '查看详情';
    }
  }

  @override
  void initState() {
    super.initState();
    _subIndex = _initialSubIndex(widget.type);
    _channelCtrl = TabController(length: _channels.length, vsync: this);
    _channelCtrl.addListener(() {
      if (_channelCtrl.indexIsChanging) return;
      if (_channel != _channelCtrl.index) {
        setState(() {
          _channel = _channelCtrl.index;
          _subIndex = 0;
        });
      }
    });
  }

  int _initialSubIndex(String type) {
    final tabs = _tabs;
    int idx;
    if (type.contains('待付款')) {
      idx = tabs.indexOf('待付款');
    } else if (type.contains('待发货')) {
      idx = tabs.indexOf('待发货');
    } else if (type.contains('已发货') || type.contains('待收货')) {
      idx = tabs.indexOf('待收货');
    } else if (type.contains('评价')) {
      idx = tabs.indexOf('待评价');
    } else if (type.contains('售后') || type.contains('退款')) {
      idx = tabs.indexOf('退款·售后');
    } else {
      idx = 0;
    }
    return idx >= 0 ? idx : 0;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _channelCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
      ));
  }

  /// 下拉刷新：重新拉取订单状态（购物/闪购/飞猪三个频道通用）
  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {});
    _toast(_channel >= 2 ? '订单状态已更新' : '已为你刷新订单');
  }

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<CartProvider>().shops;
    final isChannel = _channel >= 2;
    final filtered = isChannel ? <_ShopView>[] : _visibleShops(shops);

    return Scaffold(
      backgroundColor: const Color(0xFFf5f5f5),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            _buildChannelBar(),
            _buildSubTabBar(),
            Expanded(
              child: isChannel
                  ? RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: const Color(0xFFFF5000),
                      child: _buildChannelOrders(),
                    )
                  : filtered.isEmpty
                      ? RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: const Color(0xFFFF5000),
                          child: _empty(),
                        )
                      : RefreshIndicator(
                          onRefresh: _onRefresh,
                          color: const Color(0xFFFF5000),
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.only(top: 8, bottom: 24),
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
            ),
          ],
        ),
      ),
    );
  }

  // ============ 闪购/飞猪频道订单（随机生成） ============
  List<ChannelOrder> _channelOrders() {
    final src = _channel == 2 ? _shangouOrders : _feizhuOrders;
    final label = _tabs[_subIndex.clamp(0, _tabs.length - 1)];
    final q = _query.trim().toLowerCase();
    return src.map((o) {
      // 支付后的状态流转（去支付 → 配送中/待出行）
      final st = _statusOverrides[o.id];
      return st == null ? o : o.copyWithStatus(st);
    }).where((o) {
      if (_removedChannelIds.contains(o.id)) return false;
      if (!_matchesChannelStatus(o, label)) return false;
      if (q.isNotEmpty &&
          !o.shopName.toLowerCase().contains(q) &&
          !o.itemTitle.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// 频道子 Tab 标签 → 频道订单状态匹配
  bool _matchesChannelStatus(ChannelOrder o, String label) {
    switch (label) {
      case '全部':
        return true;
      case '待付款':
        return o.status == '待付款';
      case '待收货': // 闪购：配送中
        return o.status == '配送中';
      case '退款·售后':
        return o.status.contains('退款');
      case '待出行': // 飞猪
        return o.status == '待出行';
      case '待评价':
        return o.status == '待评价';
      case '已关闭':
        return o.status == '交易关闭';
      default:
        return true;
    }
  }

  Widget _buildChannelOrders() {
    final orders = _channelOrders();
    // 飞猪：固定 2 个订单下方追加「商品推荐」（同淘宝首页下方，素材库随机）
    final showRec = _channel == 3 && orders.isNotEmpty;
    if (orders.isEmpty) return _empty();
    final recGoods = showRec ? _feizhuRecGoods(context) : null;
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        for (final o in orders)
          o.kind == 0
              ? ShangouOrderCard(
                  order: o,
                  onRemove: () =>
                      setState(() => _removedChannelIds.add(o.id)),
                  onPay: () => setState(
                      () => _statusOverrides[o.id] = '配送中'),
                )
              : FeizhuOrderCard(
                  order: o,
                  onRemove: () =>
                      setState(() => _removedChannelIds.add(o.id)),
                  onPay: () => setState(
                      () => _statusOverrides[o.id] = '待出行'),
                ),
        if (recGoods != null) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 2),
            child: Center(
              child: Text('—— 商品推荐 ——',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.w500)),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.62,
            ),
            itemCount: recGoods.length,
            itemBuilder: (_, i) => ProductCard(item: recGoods[i]),
          ),
        ],
      ],
    );
  }

  /// 飞猪订单下方商品推荐：素材池随机（图+名对应），池空回退内置数据；会话内保持稳定
  List<SearchResultItem>? _feizhuRecPicks;
  String? _feizhuRecSig;

  List<SearchResultItem> _feizhuRecGoods(BuildContext context) {
    final pool = context.watch<MaterialPoolProvider>();
    final sig =
        '${pool.entries.length}/${pool.entries.where((e) => e.title.isNotEmpty).length}';
    if (!pool.loading && (_feizhuRecPicks == null || _feizhuRecSig != sig)) {
      _feizhuRecSig = sig;
      _feizhuRecPicks = pool.recommendGoods(10);
    }
    return _feizhuRecPicks ??
        // 素材池未就绪时的兜底推荐：固定种子保证每次 build 顺序一致
        ([...MockData.guessLikeGoods]..shuffle(Random(20260903)));
  }

  // ============ 频道栏（全部订单/购物/闪购/飞猪：撑满整宽，指示条随切换滑动） ============
  Widget _buildChannelBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _channelCtrl,
        isScrollable: false, // 4 个频道均分整宽（填充满）
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.black87,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 15),
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2.5,
        labelPadding: EdgeInsets.zero,
        tabs: [
          for (var i = 0; i < _channels.length; i++)
            Tab(
              height: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_channels[i]),
                  if (_channelBadges.containsKey(i)) ...[
                    const SizedBox(width: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFff5000),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        _channelBadges[i]!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============ 子 Tab 行（撑满整宽可滑动，选中橙底白字胶囊；照搬购物频道样式） ============
  Widget _buildSubTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ConstrainedBox(
              // tab 少时均分撑满整宽，tab 多时按内容宽度可左右滑动
              constraints:
                  BoxConstraints(minWidth: constraints.maxWidth - 20),
              child: IntrinsicWidth(
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _subIndex = i),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _subIndex == i
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              _tabs[i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _subIndex == i
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: _subIndex == i
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
            shop.orderSubStatus.contains('售后');
      case '待评价':
        return shop.orderSubStatus.contains('评价') &&
            !shop.orderSubStatus.contains('退款') &&
            !shop.orderSubStatus.contains('售后');
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
          const SizedBox(width: 10),
          // AI助手（对齐真实淘宝订单页，图标为用户提供的官方素材）
          GestureDetector(
            onTap: _openAiAssistant,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      'assets/images/icons/ai_assistant.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.auto_awesome,
                          color: AppColors.primary,
                          size: 22),
                    ),
                    Positioned(
                      right: -4,
                      top: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('AI助手',
                    style:
                        TextStyle(color: Colors.black87, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 10),
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
        ],
      ),
    );
  }

  // ============ AI助手底部面板（订单智能问答） ============
  void _openAiAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AiAssistantSheet(),
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
    // 闪购/飞猪频道直接用子 Tab 标签（_currentTab 是为购物频道映射的）
    final what = _channel >= 2
        ? _tabs[_subIndex.clamp(0, _tabs.length - 1)]
        : _currentTab;
    return LayoutBuilder(
      builder: (_, constraints) => SingleChildScrollView(
        // 空态也可下拉刷新
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inbox_outlined,
                  size: 80, color: Color(0xFFc4c4c4)),
              const SizedBox(height: 12),
              Text(searching ? '未找到相关订单' : '暂无$what订单',
                  style: AppTextStyles.middleSub),
              if (searching) ...[
                const SizedBox(height: 8),
                const Text('换个商品关键词或店铺名试试',
                    style: AppTextStyles.min),
              ],
            ],
          ),
        ),
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

  /// 主按钮动作：评价 → 发表评价页；其他 → 订单详情
  void _onPrimaryTap(BuildContext context) {
    if (actionText == '评价') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RateOrderScreen(shop: shop, item: items.first),
        ),
      );
    } else {
      onDetail(items.first);
    }
  }

  /// 点击店铺类型徽章：切换 天猫/淘宝/国际
  void _pickShopType(BuildContext context) {
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

  /// 是否退款/售后类订单（售后卡片用不同布局）
  static bool isRefundStatus(String s) =>
      s.contains('退款') || s.contains('退货') || s.contains('售后');

  /// 是否已签收/交易成功（店铺状态或单品状态任一命中即算，
  /// 此类订单不再显示「催物流」）
  bool get _isSigned {
    final s = shop.orderSubStatus;
    if (s.contains('签收') || s.contains('交易成功')) return true;
    for (final it in items) {
      if (it.statusTitle.contains('签收') || it.statusTitle.contains('交易成功')) {
        return true;
      }
    }
    return false;
  }

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
                // Expanded(tight) 吃掉全部剩余空间，保证状态文字贴卡片右缘；
                // 内层 Row 让店名 + 箭头保持左对齐（箭头跟在店名后）
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ShopHomeScreen(
                                  shopName: shop.shopName,
                                  shopType: shop.shopType),
                            ),
                          ),
                          child: Text(shop.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.smallBold),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right,
                          color: Color(0xFF999999), size: 18),
                    ],
                  ),
                ),
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
                      _capsuleBtn('加入购物车',
                          onTap: () => _reAddToCart(context)),
                      const SizedBox(width: 8),
                      _capsuleBtn('钱款去向',
                          onTap: () => onDetail(items.first)),
                      const SizedBox(width: 8),
                      _capsuleBtn('联系商家',
                          highlight: true,
                          onTap: () => _contactShop(context)),
                    ],
                  )
                : Row(
                    children: [
                      // "更多"固定在最左侧（编辑入口，双击打开编辑菜单）
                      _moreBtn('更多',
                          onDoubleTap: () => onEditItem(items.first)),
                      const Spacer(),
                      // 已签收/交易成功的订单不再显示「催物流」（对齐真实淘宝）
                      if (!_isSigned) ...[
                        _outlineBtn('催物流',
                            onTap: () => _urgeLogistics(context)),
                        const SizedBox(width: 8),
                      ],
                      _outlineBtn('查看物流',
                          onTap: () => _gotoLogistics(context, items.first)),
                      const SizedBox(width: 8),
                      // 「申请售后」对齐真实淘宝统一灰色线框，不用橙色实心
                      actionText == '申请售后'
                          ? _outlineBtn(actionText,
                              onTap: () => _onPrimaryTap(context))
                          : _primaryBtn(actionText,
                              onTap: () => _onPrimaryTap(context)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// 跳转物流详情页（带商品信息）
  void _gotoLogistics(BuildContext context, OrderItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LogisticsScreen(item: item)),
    );
  }

  /// 售后卡片「加入购物车」：把商品重新加回购物车
  void _reAddToCart(BuildContext context) {
    final item = items.first;
    context.read<CartProvider>().addToCart(
          shopName: shop.shopName,
          title: item.title,
          price: item.price,
          imageUrl: item.imageUrl,
          spec: item.configuration,
          quantity: item.quantity,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已加入购物车'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 售后卡片「联系商家」：进入店铺客服会话
  void _contactShop(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: Conversation(
            avatar: '',
            title: shop.shopName,
            description: '退款售后咨询',
            createAt: '',
          ),
          accentColor: const Color(0xFFFF5000),
        ),
      ),
    );
  }

  /// 「催物流」：提醒物流加紧配送
  void _urgeLogistics(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已提醒物流加紧配送'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
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
      if (!context.mounted) return;
      context.read<CartProvider>().updateOrderItem(item, imageUrl: saved.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品图已替换'), duration: Duration(seconds: 1)),
      );
    } catch (_) {
      if (!context.mounted) return;
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
        // 待发货：灰底圆角框架（图标 + "待发货"粗体 + 时间文案），双击编辑具体时间
        if (_isPendingShip)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onDoubleTap: () => _editShipPromise(context),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        color: Color(0xFF999999), size: 14),
                    const SizedBox(width: 4),
                    const Text('待发货',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_shipPromiseText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF999999))),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (_statusLine != null)
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
    // 待发货由灰色框架单独渲染（见 _buildNormalLayout），不再走纯文字状态行
    if (s.contains('待发货') || s.contains('等待发货')) return null;
    if (s.contains('签收') || s.contains('交易成功')) {
      // 用户自定义签收文案优先；但生成器默认的「预计xx送达」等运输中文案
      // 在签收状态下属于过期信息，不能展示（否则列表与详情页状态互相矛盾）
      final dt = item.deliveryText;
      final isTransitText = dt.contains('预计') ||
          dt.contains('发货') ||
          dt.contains('承诺') ||
          dt.contains('揽件') ||
          dt.contains('运输') ||
          dt.contains('派送');
      if (dt.isNotEmpty && !isTransitText) return dt;
      // 物流文字本身已是签收语时直接沿用，保证与详情页横幅同源
      if (item.logistics.contains('签收')) return item.logistics;
      final signer = item.receiver.isNotEmpty ? item.receiver : '本人';
      return '已签收 · 您的快件已送达，签收人：$signer';
    }
    return item.logistics.isEmpty ? null : item.logistics;
  }

  /// 是否待发货订单（普通布局里显示灰色发货承诺框架）
  bool get _isPendingShip =>
      orderStatus.contains('待发货') || orderStatus.contains('等待发货');

  /// 待发货灰框时间文案：用户改过用用户值，否则按商品标题确定性分配
  /// 变体对齐真实淘宝：预计明天/后天到达、今天/明天/后天 HH:mm 前发货、预售 M月d日 HH:mm 前发货
  String get _shipPromiseText {
    if (item.shipPromise.isNotEmpty) return item.shipPromise;
    final h =
        item.title.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    final hh = (8 + h % 14).toString().padLeft(2, '0'); // 08~21 点
    final mm = (h % 60).toString().padLeft(2, '0');
    switch (h % 6) {
      case 0:
        return '预计明天到达';
      case 1:
        return '预计后天到达';
      case 2:
        return '今天$hh:$mm前发货';
      case 3:
        return '明天$hh:$mm前发货';
      case 4:
        return '后天$hh:$mm前发货';
      default:
        // 预售日期按当前日期往后推 15~39 天（随标题哈希），月份不再写死
        final d = DateTime.now().add(Duration(days: 15 + h % 25));
        return '预售，${d.month}月${d.day}日$hh:$mm前发货';
    }
  }

  /// 双击灰色框架：编辑发货时间文案（持久化到 shipPromise）
  void _editShipPromise(BuildContext context) {
    DialogHelpers.showTextInput(
      context,
      title: '修改发货时间',
      initial: _shipPromiseText,
    ).then((v) {
      if (v == null || v.isEmpty) return;
      if (!context.mounted) return;
      context.read<CartProvider>().updateOrderItem(item, shipPromise: v);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('发货时间已修改：$v'),
          duration: const Duration(seconds: 1),
        ));
    });
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

  /// 默认确认收货倒计时：发货后 10 天自动确认（无发货时间时按 10 天整）
  String _defaultCountdown() {
    final ship = _item.shipTime.isNotEmpty
        ? DateTime.tryParse(_item.shipTime.replaceAll(' ', 'T'))
        : null;
    if (ship == null) return '还剩10天0小时自动确认';
    var remain = ship.add(const Duration(days: 10)).difference(DateTime.now());
    if (remain.isNegative) remain = const Duration(hours: 1);
    return '还剩${remain.inDays}天${remain.inHours % 24}小时自动确认';
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
        initial: _item.countDown.isEmpty ? _defaultCountdown() : _item.countDown,
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

// ============ 订单 AI 助手底部面板（本地关键词应答） ============
class _AiAssistantSheet extends StatefulWidget {
  const _AiAssistantSheet();

  @override
  State<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<_AiAssistantSheet> {
  final List<Map<String, String>> _messages = [
    {
      'role': 'ai',
      'text': '你好，我是订单 AI 助手。可以问我物流进度、退款售后、修改地址、催发货等问题～',
    },
  ];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  static const List<String> _quickQuestions = [
    '我的快递到哪了',
    '怎么申请退款',
    '可以改地址吗',
    '怎么催发货',
  ];

  String _answer(String q) {
    if (q.contains('物流') || q.contains('快递') || q.contains('到哪')) {
      return '在订单卡片上点击「查看物流」，可以看到完整的物流跟踪时间线和运单号；显示"运输中"的订单一般 1-3 天内送达。';
    }
    if (q.contains('退款') || q.contains('售后') || q.contains('退钱')) {
      return '未发货订单支持"秒退"：进入订单详情 → 申请退款，选择原因后提交即可；已收到货可在「退款/售后」Tab 发起退货退款。';
    }
    if (q.contains('地址') || q.contains('收件人')) {
      return '待发货订单可以改地址：双击订单卡片左侧「更多」→ 编辑菜单 → 修改地址/修改收件人，保存后立即生效。';
    }
    if (q.contains('催') || q.contains('发货')) {
      return '商家承诺 48 小时内发货。你可以点击订单卡片上的「催物流」按钮提醒商家，超时未发货可申请赔付。';
    }
    if (q.contains('优惠') || q.contains('券')) {
      return '领券中心在「我的」页面中部，消费券和品类券每天限量发放，下单时满足门槛会自动抵扣。';
    }
    return '这个问题我还在学习中。你可以试试问物流、退款、改地址、催发货相关问题，我会尽力解答～';
  }

  void _send([String? preset]) {
    final q = (preset ?? _input.text).trim();
    if (q.isEmpty) return;
    setState(() {
      _messages.add({'role': 'me', 'text': q});
      _messages.add({'role': 'ai', 'text': _answer(q)});
    });
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                const Icon(Icons.smart_toy_outlined,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('订单 AI 助手',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isMe = m['role'] == 'me';
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                        maxWidth:
                            MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      m['text']!,
                      style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                );
              },
            ),
          ),
          // 快捷提问
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickQuestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _send(_quickQuestions[i]),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Text(_quickQuestions[i],
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ),
          // 输入框
          Container(
            color: Colors.white,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: _send,
                    decoration: InputDecoration(
                      hintText: '输入你的问题…',
                      hintStyle: const TextStyle(
                          color: Color(0xFFBBBBBB), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('发送',
                        style:
                            TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
