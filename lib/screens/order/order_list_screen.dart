import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'express_library_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// v1.9.122：搜索样式开关——false=经典内联搜索框（默认，原功能保留）；
  /// true=真实淘宝同款订单搜索页（双击「筛选」按钮来回切换，偏好持久化）
  bool _useNewSearch = false;
  static const _kSearchStyleKey = 'order_search_style_new';

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
    // v1.9.88：付款满 10 天的待收货订单自动确认收货（对齐真实淘宝倒计时结束）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<CartProvider>().sweepAutoConfirm();
    });
    // v1.9.122：恢复搜索样式偏好（经典搜索框 / 真实淘宝同款搜索页）
    SharedPreferences.getInstance().then((p) {
      final v = p.getBool(_kSearchStyleKey) ?? false;
      if (mounted && v != _useNewSearch) setState(() => _useNewSearch = v);
    });
  }

  /// 双击「筛选」→ 经典搜索框 ↔ 真实淘宝同款搜索页 来回切换（单击仍是筛选弹层）
  void _toggleSearchStyle() {
    setState(() => _useNewSearch = !_useNewSearch);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(_kSearchStyleKey, _useNewSearch));
    _toast(_useNewSearch ? '已切换：淘宝同款订单搜索页' : '已切换：经典搜索框');
  }

  /// 新版搜索：点击搜索框 → 全屏订单搜索页（真实淘宝同款）
  void _openOrderSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrderSearchScreen()),
    );
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
            if (!isChannel && _currentTab == '售后') _buildRefundFilterBar(),
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
                            padding: const EdgeInsets.only(top: 8, bottom: 24),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) => _OrderCard(
                              shop: filtered[i].shop,
                              items: filtered[i].items,
                              actionText: _actionText,
                              rateTab: _currentTab == '待评价',
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
                  onRemove: () => setState(() => _removedChannelIds.add(o.id)),
                  onPay: () => setState(() => _statusOverrides[o.id] = '配送中'),
                )
              : FeizhuOrderCard(
                  order: o,
                  onRemove: () => setState(() => _removedChannelIds.add(o.id)),
                  onPay: () => setState(() => _statusOverrides[o.id] = '待出行'),
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
                        style:
                            const TextStyle(color: Colors.white, fontSize: 9),
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

  // ============ 子 Tab 行（撑满整宽可滑动；对齐真实淘宝：灰底胶囊，选中橙字加粗） ============
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
              constraints: BoxConstraints(minWidth: constraints.maxWidth - 20),
              child: IntrinsicWidth(
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _subIndex = i),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
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
                                    ? const Color(0xFFFF5000)
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

  // ============ 退款/售后的「进行中/已完结」筛选（都不选=全部退款单，对齐真实淘宝） ============
  /// 0=全部 1=进行中 2=已完结
  int _refundFilter = 0;

  Widget _buildRefundFilterBar() {
    Widget chip(String label, int value) {
      final selected = _refundFilter == value;
      return GestureDetector(
        onTap: () => setState(() => _refundFilter = selected ? 0 : value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? const Color(0xFFFF5000) : Colors.black87,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 2),
                const Icon(Icons.close, size: 13, color: Color(0xFFFF5000)),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 4, right: 12, bottom: 8),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('可筛选售后状态',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ),
          const Spacer(),
          chip('进行中', 1),
          chip('已完结', 2),
        ],
      ),
    );
  }

  /// 退款单按 进行中/已完结 过滤（基于店铺子状态文案）
  bool _matchesRefundFilter(ShoppingCartShop shop) {
    if (_refundFilter == 0) return true;
    final s = shop.orderSubStatus;
    final done = s.contains('成功') ||
        s.contains('结束') ||
        s.contains('关闭') ||
        s.contains('完成');
    return _refundFilter == 2 ? done : !done;
  }

  /// 状态过滤 + 搜索过滤（商品标题/规格/店铺名 关键词）
  List<_ShopView> _visibleShops(List<ShoppingCartShop> shops) {
    final q = _query.trim().toLowerCase();
    final result = <_ShopView>[];
    for (final shop in shops) {
      if (!_matchesStatus(shop)) continue;
      if (_currentTab == '售后' && !_matchesRefundFilter(shop)) continue;
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
          // 搜索框（经典：可输入即时过滤；新版：点击进入淘宝同款搜索页。
          // 双击「筛选」按钮在两种样式间切换，v1.9.122）
          Expanded(
            child: GestureDetector(
              onTap: _useNewSearch ? _openOrderSearch : null,
              behavior: HitTestBehavior.opaque,
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
                      child: _useNewSearch
                          ? const Text('搜索订单',
                              style: TextStyle(
                                  color: Color(0xFF999999), fontSize: 14))
                          : TextField(
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
                    if (!_useNewSearch && _query.isNotEmpty)
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
                    style: TextStyle(color: Colors.black87, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 筛选 → 单击：订单筛选底部弹层（v1.9.114）；
          // 双击：经典搜索框 ↔ 淘宝同款搜索页 来回切换（v1.9.122）
          GestureDetector(
            onTap: _openFilterSheet,
            onDoubleTap: _toggleSearchStyle,
            child: _topAction(AppIcons.filter, '筛选'),
          ),
          const SizedBox(width: 12),
          // 管理 → v1.9.115：单击开面板（批量操作/回收站等，对齐真实淘宝）；
          // 双击仍是订单管理页（编辑入口）
          GestureDetector(
            onTap: _openMorePanel,
            onDoubleTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrderManagerScreen()),
            ),
            child: _topAction(AppIcons.list, '管理'),
          ),
          const SizedBox(width: 10),
          // v1.9.115：右上角三个点（带 67 角标）→ 快捷入口底部弹层
          // （消息/回到首页/我的淘宝/购物车/我的订单/足迹/收藏/客服/反馈/举报）
          GestureDetector(
            onTap: _openShortcutsSheet,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.more_horiz,
                        color: Colors.black87, size: 22),
                    Positioned(
                      right: -10,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 3, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5000),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Text('67',
                            style: TextStyle(color: Colors.white, fontSize: 8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('',
                    style: TextStyle(color: Colors.black87, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ v1.9.114：三个点下拉面板（批量操作/回收站/调研反馈/ ============
  // ============ 我的快递/发票中心/价保中心，纯视觉无实际功能） ============
  void _openMorePanel() {
    const items = <(IconData, String)>[
      (Icons.how_to_reg_outlined, '批量操作'),
      (Icons.delete_outline, '回收站'),
      (Icons.edit_note, '调研反馈'),
      (Icons.local_shipping_outlined, '我的快递'),
      (Icons.receipt_long, '发票中心'),
      (Icons.verified_user_outlined, '价保中心'),
    ];
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'more',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dlgCtx, _, __) {
        final top = MediaQuery.of(dlgCtx).padding.top;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: top + 52),
            child: Material(
              color: Colors.white,
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final e in items)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // v1.9.136：「我的快递」不再是纯视觉，点击进快递库
                          onTap: () {
                            Navigator.of(dlgCtx).pop();
                            if (e.$2 == '我的快递') {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) =>
                                      const ExpressLibraryScreen()));
                            }
                          },
                          child: SizedBox(
                            width: 68,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(e.$1, color: Colors.black87, size: 26),
                                const SizedBox(height: 6),
                                Text(e.$2,
                                    style: const TextStyle(
                                        color: Colors.black87, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============ v1.9.115：三个点 → 快捷入口底部弹层（对齐真实淘宝） ============
  // ============ 消息/回到首页/我的淘宝/购物车/我的订单/足迹/收藏/客服/反馈/举报 ============
  void _openShortcutsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ShortcutsSheet(),
    );
  }

  // ============ v1.9.114：订单筛选底部弹层（纯视觉，对齐真实淘宝） ============
  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => const _OrderFilterSheet(),
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
        // v1.9.114：除 AI助手外顶部图标改黑色（对齐真实淘宝，此前橙色被驳回）
        Icon(icon, color: Colors.black87, size: 22),
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
                const Text('换个商品关键词或店铺名试试', style: AppTextStyles.min),
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
  final bool rateTab; // 待评价 Tab：右上角交易成功 + 评价引导灰框 + 评价高亮按钮
  final void Function(OrderItem item) onEditItem;
  final void Function(OrderItem item) onDetail;

  const _OrderCard({
    required this.shop,
    required this.items,
    required this.actionText,
    required this.onEditItem,
    required this.onDetail,
    this.rateTab = false,
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

  /// 是否交易成功订单（下方无物流框架，底部按钮为 3 种样式组合）
  bool get _isTradeSuccess => shop.orderSubStatus.contains('交易成功');

  /// 交易成功底部按钮样式：v1.9.87 起固定样式0（追加评价+查看物流+再买一单浅橙高亮，
  /// 对齐真实淘宝截图）；仅当编辑菜单手动指定 orderBtnStyle 时才用其它组合
  int get _successBtnStyle {
    if (shop.orderBtnStyle >= 0 && shop.orderBtnStyle <= 2) {
      return shop.orderBtnStyle;
    }
    return 0;
  }

  /// 交易成功订单底部按钮行（v1.9.85 对齐真实淘宝截图，编辑菜单可切换/随机）：
  /// 0：追加评价 + 查看物流 + 再买一单（浅橙底橙字高亮）—— Chocola BB 截图款
  /// 1：再买一单（橙实心）+ 加入购物车 + 删除订单 —— 小福星代购截图款
  /// 2：评价 + 加入购物车 + 再买一单（橙实心）
  Widget _buildSuccessButtons(BuildContext context) {
    const gap = SizedBox(width: 8);
    final List<Widget> btns;
    switch (_successBtnStyle) {
      case 0:
        btns = [
          _outlineBtn('追加评价', onTap: () => _onRateTap(context)),
          gap,
          _outlineBtn('查看物流',
              onTap: () => _gotoLogistics(context, items.first)),
          gap,
          _capsuleBtn('再买一单',
              highlight: true, onTap: () => _reAddToCart(context)),
        ];
        break;
      case 1:
        btns = [
          _primaryBtn('再买一单', onTap: () => _reAddToCart(context)),
          gap,
          _outlineBtn('加入购物车', onTap: () => _reAddToCart(context)),
          gap,
          _outlineBtn('删除订单', onTap: () => _confirmDeleteOrder(context)),
        ];
        break;
      default:
        btns = [
          _outlineBtn('评价', onTap: () => _onRateTap(context)),
          gap,
          _outlineBtn('加入购物车', onTap: () => _reAddToCart(context)),
          gap,
          _primaryBtn('再买一单', onTap: () => _reAddToCart(context)),
        ];
    }
    return Row(
      children: [
        // "更多"固定在最左侧（编辑入口，双击打开编辑菜单）
        _moreBtn('更多', onDoubleTap: () => onEditItem(items.first)),
        const Spacer(),
        ...btns,
      ],
    );
  }

  /// 抓包真实按钮序列（orderOps："再买一单*|加入购物车|评价|查看物流"，*=高亮）
  List<(String, bool)> get _capturedOps {
    if (shop.orderOps.isEmpty) return const [];
    return shop.orderOps
        .split('|')
        .where((s) => s.isNotEmpty)
        .map((s) =>
            s.endsWith('*') ? (s.substring(0, s.length - 1), true) : (s, false))
        .toList();
  }

  /// 抓包真实按钮行（v1.9.75 起）：顺序与高亮完全照搬淘宝下发数据
  Widget _buildCapturedOpsButtons(BuildContext context) {
    const gap = SizedBox(width: 8);
    return Row(
      children: [
        // "更多"固定在最左侧（编辑入口，双击打开编辑菜单）
        _moreBtn('更多', onDoubleTap: () => onEditItem(items.first)),
        const Spacer(),
        for (var i = 0; i < _capturedOps.length; i++) ...[
          if (i > 0) gap,
          // v1.9.87：高亮位改浅橙底橙字胶囊（真实淘宝高亮是浅橙，不是实心橙）
          _capturedOps[i].$2
              ? _capsuleBtn(_capturedOps[i].$1,
                  highlight: true,
                  onTap: () => _onOpTap(context, _capturedOps[i].$1))
              : _outlineBtn(_capturedOps[i].$1,
                  onTap: () => _onOpTap(context, _capturedOps[i].$1)),
        ],
      ],
    );
  }

  /// 抓包按钮点击：已知按钮映射真实动作，平台功能类按钮仅提示
  void _onOpTap(BuildContext context, String name) {
    if (name == '评价' || name == '追加评价') {
      _onRateTap(context);
    } else if (name == '查看物流') {
      _gotoLogistics(context, items.first);
    } else if (name == '加入购物车' || name == '再买一单') {
      _reAddToCart(context);
    } else if (name == '删除订单') {
      _confirmDeleteOrder(context);
    }
    // v1.9.101：申请开票/延长收货/确认收货/修改地址/闲鱼转卖等平台功能
    // 按钮点击静默，不再弹「演示样式按钮」提示
  }

  /// 「删除订单」：确认后移除该店铺卡片（与真实淘宝一致的二次确认）
  void _confirmDeleteOrder(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除订单？', style: TextStyle(fontSize: 16)),
        content:
            const Text('删除后不可恢复，确定要删除这笔订单吗？', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child:
                  const Text('删除', style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    ).then((ok) {
      if (ok != true) return;
      if (!context.mounted) return;
      context.read<CartProvider>().removeShop(shop);
    });
  }

  /// 待评价 Tab 底部按钮行（对齐真实淘宝评价列表的 4 种组合，按店名哈希稳定随机）：
  /// 0：更多 + 闲鱼转卖 + 再买一单 + 评价（高亮）
  /// 1：更多 + 加入购物车 + 查看物流 + 评价（高亮）
  /// 2：更多 + 加入购物车 + 再买一单 + 评价（高亮）
  /// 3：更多 + 闲鱼转卖 + 加入购物车 + 评价（高亮）
  Widget _buildRateButtons(BuildContext context) {
    const gap = SizedBox(width: 8);
    final h = shop.shopName.codeUnits
        .fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    final List<Widget> btns;
    switch (h % 4) {
      case 0:
        btns = [
          _outlineBtn('闲鱼转卖', onTap: () {}),
          gap,
          _outlineBtn('再买一单', onTap: () => _reAddToCart(context)),
        ];
        break;
      case 1:
        btns = [
          _outlineBtn('加入购物车', onTap: () => _reAddToCart(context)),
          gap,
          _outlineBtn('查看物流',
              onTap: () => _gotoLogistics(context, items.first)),
        ];
        break;
      case 2:
        btns = [
          _outlineBtn('加入购物车', onTap: () => _reAddToCart(context)),
          gap,
          _outlineBtn('再买一单', onTap: () => _reAddToCart(context)),
        ];
        break;
      default:
        btns = [
          _outlineBtn('闲鱼转卖', onTap: () {}),
          gap,
          _outlineBtn('加入购物车', onTap: () => _reAddToCart(context)),
        ];
    }
    return Row(
      children: [
        // "更多"固定在最左侧（编辑入口，双击打开编辑菜单）
        _moreBtn('更多', onDoubleTap: () => onEditItem(items.first)),
        const Spacer(),
        ...btns,
        gap,
        _primaryBtn('评价', onTap: () => _onRateTap(context)),
      ],
    );
  }

  /// 「评价」：进入发表评价页
  void _onRateTap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RateOrderScreen(shop: shop, item: items.first),
      ),
    );
  }

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
    // 实付款：抓包导入的订单带 actualTotal（接口实付总额，单价×数量有分位差）优先用；
    // 否则沿用旧逻辑 = 各商品实付价直接相加（实付录入多少就是多少，不再乘规格数量）
    final total = shop.actualTotal > 0
        ? shop.actualTotal
        : items.fold<double>(0, (sum, item) => sum + item.price);
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
                // 售后卡片右上角只写"退款"（橘色），与真实淘宝一致；
                // 待评价 Tab 右上角写"交易成功"（对齐真实淘宝评价列表）
                Text(
                    isRefund
                        ? '退款'
                        : rateTab
                            ? '交易成功'
                            : shop.orderSubStatus,
                    style: AppTextStyles.small.copyWith(
                        color: AppColors.primary, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          // 商品列表：点击进入详情，双击弹出编辑菜单
          ...items.map((item) => _OrderItemTile(
                item: item,
                shop: shop,
                orderStatus: rateTab ? '交易成功' : shop.orderSubStatus,
                onTap: () => onDetail(item),
                onDoubleTap: () => onEditItem(item),
              )),
          // 赠品行（v1.9.102：对齐真实淘宝列表卡——左"N件赠品"，
          // 右赠品缩略图+箭头，位于物流信息上方）
          if (!isRefund && items.any((e) => e.giftCount > 0))
            _listGiftRow(context, items.firstWhere((e) => e.giftCount > 0)),
          // 日期+实付款行（v1.9.103：上移到商品区正下方，与商品图底部边缘对齐；
          // 运费计入实付款；标题右侧单价只算货品价值）
          if (!isRefund) _paidDateLine(total),
          // 状态框架（物流/待发货承诺/评价引导）在实付款行下方，
          // 贴近按钮区（v1.9.103 与实付款行互换位置，对齐真实淘宝列表卡层级）
          // v1.9.104：退款售后卡不再渲染底部状态框架——商品区已有一条退款条，
          // 底部再来一条就是用户截图里"多余的第二个退款框"（真实淘宝退款卡只有一条）
          if (!isRefund)
            _OrderStatusFrame(
              item: items.first,
              orderStatus: rateTab ? '交易成功' : shop.orderSubStatus,
              ratePrompt: rateTab,
            ),
          // 底部操作栏（售后卡片无合计行，对齐真实淘宝退款单）
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: isRefund
                ? Row(
                    children: [
                      // "更多"（编辑入口，双击打开编辑菜单）
                      _moreBtn('更多',
                          onDoubleTap: () => onEditItem(items.first)),
                      const Spacer(),
                      _capsuleBtn('加入购物车', onTap: () => _reAddToCart(context)),
                      const SizedBox(width: 8),
                      _capsuleBtn('钱款去向', onTap: () => onDetail(items.first)),
                      const SizedBox(width: 8),
                      _capsuleBtn('联系商家',
                          highlight: true, onTap: () => _contactShop(context)),
                    ],
                  )
                : rateTab
                    ? (shop.orderOps.isNotEmpty
                        ? _buildCapturedOpsButtons(context)
                        : _buildRateButtons(context))
                    : _isTradeSuccess
                        // v1.9.87：交易成功卡片固定用截图款组合（追加评价+查看物流+
                        // 再买一单浅橙高亮），不再走抓包按钮序列（用户反馈抓包款的
                        // 实心橙再买一单+申请开票+删除订单与真实淘宝截图不符）
                        ? _buildSuccessButtons(context)
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
                                  onTap: () =>
                                      _gotoLogistics(context, items.first)),
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

  /// 金额格式化：去掉末尾的 .00/.0（对齐真实淘宝 ¥265.5 / ¥32 / ¥3.4 的写法）
  static String fmtPrice(double v) {
    var s = v.toStringAsFixed(2);
    if (s.endsWith('00')) {
      s = s.substring(0, s.length - 3);
    } else if (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// 列表卡赠品行（v1.9.102）：左"N件赠品"，右赠品缩略图（最多2张）+箭头。
  /// 对齐真实淘宝待收货卡片；单击进订单详情（赠品的编辑在详情页）
  Widget _listGiftRow(BuildContext context, OrderItem it) {
    // v1.9.104：图片少于件数时循环重复填充（与详情页 _giftThumbs 同逻辑）
    final base = it.giftImages.isNotEmpty
        ? it.giftImages
        : (it.giftImage.isNotEmpty ? [it.giftImage] : <String>[]);
    final target = it.giftCount.clamp(1, 2);
    final thumbs = base.isEmpty
        ? <String>[]
        : (base.length >= target
            ? base
            : [for (var i = 0; i < target; i++) base[i % base.length]]);
    return GestureDetector(
      onTap: () => onDetail(it),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        // v1.9.106：底距 10→4，实付款行紧贴赠品行下方
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        child: Row(
          children: [
            Text('${it.giftCount}件赠品',
                style: const TextStyle(fontSize: 13, color: Color(0xFF333333))),
            const Spacer(),
            for (final t in thumbs.take(2))
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AppImage(url: t, width: 20, height: 20),
                ),
              ),
            if (thumbs.isEmpty)
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.card_giftcard,
                    size: 12, color: Color(0xFFbbbbbb)),
              ),
            const Icon(Icons.chevron_right, color: Color(0xFFcccccc), size: 16),
          ],
        ),
      ),
    );
  }

  /// 日期+实付款行（v1.9.102，对齐真实淘宝列表卡右下角）：
  /// "09.11  |  含运费¥35 实付款 ¥99"
  /// - 日期取订单创建时间的月日（MM.DD）
  /// - 运费计入实付款；有运费时显示"含运费¥x"
  /// - "实付款"较细黑体，右侧价格相对较粗——两个价格都与订单实付款一致
  Widget _paidDateLine(double total) {
    const grey = TextStyle(fontSize: 11, color: Color(0xFF999999));
    // 日期：解析创建时间里的月日（兼容 2026-09-11 / 2026/09/11 / 2026年9月1日）
    String date = '';
    final ct = items.first.createTime;
    final m = RegExp(r'\d{2,4}[-/年](\d{1,2})[-/月](\d{1,2})').firstMatch(ct);
    if (m != null) {
      date = '${m.group(1)!.padLeft(2, '0')}.${m.group(2)!.padLeft(2, '0')}';
    }
    // 运费：订单级运费挂在首个商品上（抓包）；生成订单按各商品求和
    final freight = items.fold<double>(
        0, (s, e) => s + (e.showShippingFee ? e.shippingFee : 0));
    return Padding(
      // v1.9.106：顶距 2→0——无赠品时与商品图底边对齐，有赠品时紧贴赠品行
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text.rich(
            TextSpan(
              children: [
                if (date.isNotEmpty) ...[
                  TextSpan(text: date, style: grey),
                  const TextSpan(text: '  |  ', style: grey),
                ],
                if (freight > 0)
                  TextSpan(text: '含运费¥${fmtPrice(freight)}  ', style: grey),
                const TextSpan(
                    text: '实付款 ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF333333))),
                TextSpan(
                  text: '¥${fmtPrice(total)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A)),
                ),
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
      MaterialPageRoute(
          builder: (_) => LogisticsScreen(item: item, shopName: shop.shopName)),
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
          color: highlight ? const Color(0xFFFFF1E8) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text,
            style: TextStyle(
                color: highlight ? AppColors.primary : Colors.black87,
                fontSize: 12,
                fontWeight: highlight ? FontWeight.w500 : FontWeight.normal)),
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

  /// 次按钮：v1.9.85 起统一灰底胶囊（真实淘宝退款/待收货卡片同款灰框，
  /// 不再用白底描边），内容不变只改框颜色
  Widget _outlineBtn(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
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
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ============ 订单商品项（可点击编辑） ============
class _OrderItemTile extends StatelessWidget {
  final OrderItem item;
  final ShoppingCartShop shop; // 计算标题右侧实付单价需要整单实付/运费（v1.9.102）
  final String orderStatus; // 店铺级订单状态，决定下方状态行的文案与图标
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const _OrderItemTile({
    required this.item,
    required this.shop,
    required this.orderStatus,
    required this.onTap,
    this.onDoubleTap,
  });

  Future<void> _pickImage(BuildContext context) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/order_images');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'order_${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(picked.path).copy('${saveDir.path}/$fileName');
      if (!context.mounted) return;
      // v1.9.102：存相对 Documents 路径——自签重装容器变化后图片不丢
      final rel = 'order_images/$fileName';
      // 用商品标题作为 key，详情页也会读取同一张图
      await context.read<ProductImageProvider>().setOverride(item.title, rel);
      if (!context.mounted) return;
      context.read<CartProvider>().updateOrderItem(item, imageUrl: rel);
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
        // v1.9.106：底距 10→4——无赠品时实付款行紧贴商品图底边（对齐），
        // 有赠品时赠品行紧贴图片下方、实付款再贴赠品行
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: isRefund
            ? _buildRefundLayout(context, imageUrl)
            : _buildNormalLayout(context, imageUrl),
      ),
    );
  }

  // ============ 售后卡片布局（照搬真实淘宝退款/售后列表） ============
  Widget _buildRefundLayout(BuildContext context, String imageUrl) {
    final amount = item.refundAmount > 0 ? item.refundAmount : item.price;
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
                  // 随机商品对应规格（前缀按商品稳定选取）；
                  // v1.9.105：「默认规格」/空规格不显示（对齐真实淘宝）
                  if (item.configuration.trim().isNotEmpty &&
                      item.configuration.trim() != '默认规格') ...[
                    const SizedBox(height: 6),
                    Text(
                      '$_specPrefix:${item.configuration}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          AppTextStyles.min.copyWith(color: AppColors.subText),
                    ),
                  ],
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
  /// v1.9.104：style 3（平台支持退款）并入 style 1（退款金额）——真实淘宝
  /// 退款卡只有一条退款框，"平台支持退款"条是多余的（用户截图确认）
  List<TextSpan> _refundBarSpans(double amount) {
    const grey = TextStyle(fontSize: 12, color: Color(0xFF999999));
    const orange = TextStyle(fontSize: 12, color: Color(0xFFFF5000));
    final pending = _refundBarStatus == '待商家退款';
    var style = item.refundBarStyle < 0 ? 1 : item.refundBarStyle;
    if (style == 3) style = 1; // 平台支持退款 → 退款金额样式
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
          text: '¥${item.refundDiscount.toStringAsFixed(2)}', style: orange));
    }
    return spans;
  }

  /// 规格前缀：按商品标题稳定选取（颜色分类/商品规格）
  String get _specPrefix {
    final sum = item.title.codeUnits.fold<int>(0, (a, b) => a + b);
    return sum.isEven ? '颜色分类' : '商品规格';
  }

  // ============ 普通订单布局 ============
  // v1.9.102 对齐真实淘宝列表卡：
  // - 标题只一行（约 17-18 字符后省略号截断），右侧实付单价（较粗黑体）+ ×N
  // - 规格在标题下方，服务标签再下方（纯绿色字、不带框）
  // - 状态框架（物流/待发货/评价引导）下移到卡片底部（_OrderStatusFrame）
  Widget _buildNormalLayout(BuildContext context, String imageUrl) {
    // v1.9.105：规格为「默认规格」或空时不渲染规格行
    // （对齐真实淘宝——天猫超市等无规格商品不显示规格）
    final spec = item.configuration.trim();
    final showSpec = spec.isNotEmpty && spec != '默认规格';
    // 标签拼成一条 Text（空格分隔）：单行裁切由 Text 自身保证，
    // 绝不会溢出卡片（v1.9.105 弃用 SingleChildScrollView 方案）
    final tagsText = item.displayTags.join('  ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onDoubleTap: () => _pickImage(context), // 双击换商品图
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            // v1.9.106：80→76，缩小与文字区的高度差
            child: AppImage(
              url: imageUrl,
              width: 76,
              height: 76,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // v1.9.105 结构修复：标题/规格/标签放左列，价格放右列——
        // 旧结构把标题和价格放同一 Row，价格列（¥+×N 约33px高）撑高了
        // 整行，规格只能从价格列底部开始排，视觉上永远"贴不上标题"
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.small.copyWith(height: 1.2),
                    ),
                    if (showSpec)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          spec,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.subText,
                              height: 1.2),
                        ),
                      ),
                    // 服务标签：单行，只显示能完整放下的标签——
                    // 放不下的整个不显示，绝不切半个字（v1.9.106，对齐真实淘宝）
                    if (tagsText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _fitTagsRow(item.displayTags),
                      ),
                    // "平台加补后 / 领消费券后约" 价格行已按需求删除
                    if (item.showTaxInfoLine && item.taxInfo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(item.taxInfo,
                            style: const TextStyle(
                                color: Color(0xFF999999), fontSize: 11)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 标题右侧：实付单价 + ×N——只算货品价值（不含运费），
              // 数量>1 自动 ÷数量（与详情页 _unitPriceOf 同逻辑）
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${_OrderCard.fmtPrice(_unitPrice)}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 2),
                  Text('×${item.quantity}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF999999))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 服务标签单行整词显示（v1.9.106）：逐个测量标签宽度，
  /// 只保留能在可用宽度内完整放下的标签，放不下的整个丢弃——
  /// 绝不出现"7天无理由"被切成"7天无理"这种半个字的情况（对齐真实淘宝）
  Widget _fitTagsRow(List<String> tags) {
    const style =
        TextStyle(color: Color(0xFF00A870), fontSize: 12, height: 1.2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final kept = <String>[];
        var used = 0.0;
        for (final t in tags) {
          final tp = TextPainter(
            text: TextSpan(text: t, style: style),
            textDirection: TextDirection.ltr,
            textScaler: scaler,
          )..layout();
          // 间距按 8 计（渲染用两个空格≈7px，往保守算）
          final w = tp.width + (kept.isEmpty ? 0 : 8);
          if (kept.isNotEmpty && used + w > constraints.maxWidth) break;
          used += w;
          kept.add(t);
        }
        return Text(
          kept.join('  '),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: style,
        );
      },
    );
  }

  /// 标题右侧实付单价（v1.9.102）：与详情页 _unitPriceOf 同逻辑——
  /// price≈整单实付时先剥运费再 ÷数量；抓包新数据 price 本就是单价直接用
  double get _unitPrice {
    if (shop.actualTotal > 0 && (item.price - shop.actualTotal).abs() < 1.0) {
      final shipFee = item.showShippingFee ? item.shippingFee : 0.0;
      return (item.price - shipFee) / item.quantity;
    }
    if (item.quantity > 1) {
      if (shop.actualTotal > 0 &&
          (item.price * item.quantity - shop.actualTotal).abs() < 1.0) {
        return item.price;
      }
      if (item.productTotal > 0 &&
          (item.price - item.productTotal).abs() < 1.0) {
        return item.price / item.quantity;
      }
    }
    return item.price;
  }
}

// ============ 卡片底部状态框架（v1.9.102：从商品区下移，贴近按钮区） ============
class _OrderStatusFrame extends StatelessWidget {
  final OrderItem item;
  final String orderStatus; // 店铺级订单状态，决定状态行的文案与图标
  final bool ratePrompt; // 待评价 Tab：显示评价引导灰框（随机文案+灰星）

  const _OrderStatusFrame({
    required this.item,
    required this.orderStatus,
    this.ratePrompt = false,
  });

  @override
  Widget build(BuildContext context) {
    // 待评价 Tab：评价引导灰框（随机文案 + 灰色星标行，对齐真实淘宝评价列表）
    if (ratePrompt) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
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
                  TextSpan(children: _ratePromptSpans),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // 灰色星标行（未评价，对齐真实淘宝）
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 5; i++)
                    const Padding(
                      padding: EdgeInsets.only(left: 2),
                      child: Icon(Icons.star_rounded,
                          color: Color(0xFFDDDDDD), size: 15),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    // 待发货：灰底圆角框架（图标 + "待发货"粗体 + 时间文案），双击编辑具体时间
    if (_isPendingShip) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: GestureDetector(
          onDoubleTap: () => _editShipPromise(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Color(0xFF999999), size: 14),
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
      );
    }
    // 交易成功：下方不再显示任何框架（对齐真实淘宝）
    // 其余状态行全部统一灰色圆角框架（图标 + 粗体状态词 + 灰色描述 + 箭头）
    if (_statusLine != null && !_isTradeSuccess) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(_statusIcon,
                  color: _isTransitLine
                      ? const Color(0xFFff5000)
                      : const Color(0xFF999999),
                  size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text.rich(
                  TextSpan(children: _statusLineSpans),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF999999), size: 16),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  /// 待评价 Tab 评价引导文案池（对齐真实淘宝评价列表的随机引导语，
  /// 按商品标题哈希稳定选取，同一商品每次一致）：
  /// 0 返100淘金币（金币图标）/ 1 评价帮助更多人 / 2 评价将帮助X.X万人… /
  /// 3 回购多次，怎么样？/ 4 分享使用心得，帮助更多人
  List<InlineSpan> get _ratePromptSpans {
    const grey = TextStyle(fontSize: 12, color: Color(0xFF999999));
    const dark = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF333333));
    final h =
        item.title.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    switch (h % 5) {
      case 0:
        return [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: 3),
              child: Icon(Icons.monetization_on,
                  color: Color(0xFFFFB300), size: 14),
            ),
          ),
          const TextSpan(text: '返', style: grey),
          const TextSpan(
              text: '100',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF5000))),
          const TextSpan(text: '淘金币', style: grey),
        ];
      case 1:
        return [const TextSpan(text: '评价帮助更多人', style: dark)];
      case 2:
        final wan = (12 + h % 87) / 10; // 1.2 ~ 9.8 万
        return [
          TextSpan(text: '评价将帮助${wan.toStringAsFixed(1)}万人…', style: dark)
        ];
      case 3:
        return [const TextSpan(text: '回购多次，怎么样？', style: dark)];
      default:
        return [const TextSpan(text: '分享使用心得，帮助更多人', style: dark)];
    }
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

  /// 是否交易成功（此类订单下方不显示任何物流/状态框架）
  bool get _isTradeSuccess => orderStatus.contains('交易成功');

  /// 运输中/派送中物流行（联网更新后的「预计xx送达」摘要）：
  /// v1.9.110 起整行橙色（对齐真实淘宝物流条）
  bool get _isTransitLine {
    final line = _statusLine;
    if (line == null) return false;
    // v1.9.112：只有「今天送达」的物流行才整行橙色（对齐真实淘宝），
    // 已发货/已揽件/预计明天送达等保持原灰黑样式
    return line.contains('今天送达');
  }

  /// 状态行富文本：首个词（已发货/运输中/派送中…）粗体深色，其余灰色（对齐真实淘宝灰框样式）
  List<TextSpan> get _statusLineSpans {
    final line = _statusLine!;
    final idx = line.indexOf(' ');
    // v1.9.110：运输中/派送中（预计xx送达）整行橙色，对齐真实淘宝
    if (_isTransitLine) {
      const orange = TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFff5000));
      const orangeTail = TextStyle(fontSize: 12, color: Color(0xFFff5000));
      if (idx <= 0) return [TextSpan(text: line, style: orange)];
      return [
        TextSpan(text: line.substring(0, idx), style: orange),
        TextSpan(text: line.substring(idx), style: orangeTail),
      ];
    }
    const head = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A));
    const tail = TextStyle(fontSize: 12, color: Color(0xFF999999));
    if (idx <= 0) return [TextSpan(text: line, style: head)];
    return [
      TextSpan(text: line.substring(0, idx), style: head),
      TextSpan(text: line.substring(idx), style: tail),
    ];
  }

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
    ('完成单按钮样式', Icons.dashboard_customize),
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
              border: Border(bottom: BorderSide(color: Color(0xFFf0f0f0))),
            ),
            child: Row(
              children: [
                const Text('订单编辑',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    final current = _item.refundAmount > 0 ? _item.refundAmount : _item.price;
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
        initial:
            _item.countDown.isEmpty ? _defaultCountdown() : _item.countDown,
      ).then((v) {
        if (v != null && v.isNotEmpty) {
          provider.setCountdown(_item, v);
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
    if (label == '完成单按钮样式') {
      Navigator.of(context).pop();
      const styles = [
        '随机（每单自动分配）',
        '样式1：追加评价 + 查看物流 + 再买一单',
        '样式2：再买一单 + 加入购物车 + 删除订单',
        '样式3：评价 + 加入购物车 + 再买一单',
      ];
      const values = [-1, 0, 1, 2];
      final cur = values.indexOf(widget.shop.orderBtnStyle);
      DialogHelpers.showOptionPicker(
        widget.parentContext,
        title: '完成单按钮样式（交易成功订单）',
        options: styles,
        currentValue: styles[cur < 0 ? 0 : cur],
      ).then((v) {
        if (v == null) return;
        provider.updateShop(widget.shop,
            orderBtnStyle: values[styles.indexOf(v)]);
        _toast('完成单按钮样式已切换为「$v」');
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
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
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
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('发送',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
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

/// v1.9.114：订单筛选底部弹层（对齐真实淘宝，纯视觉——选中态可切换，
/// 重置清空、确认关闭，不做真实过滤）
class _OrderFilterSheet extends StatefulWidget {
  const _OrderFilterSheet();

  @override
  State<_OrderFilterSheet> createState() => _OrderFilterSheetState();
}

class _OrderFilterSheetState extends State<_OrderFilterSheet> {
  final Set<String> _sel = {};

  static const _timeChips = [
    '1个月前',
    '3个月前',
    '6个月前',
    '2026年',
    '2025年',
    '2024年',
    '2023年',
    '2022年',
    '展开 ∨',
  ];

  static const _categories = <(IconData, String)>[
    (Icons.checkroom, '女装'),
    (Icons.person_outline, '男装'),
    (Icons.child_care, '母婴'),
    (Icons.pets, '宠物'),
    (Icons.weekend_outlined, '家装家居'),
    (Icons.local_laundry_service_outlined, '家电数码'),
    (Icons.favorite_border, '个护健康'),
    (Icons.place_outlined, '其他'),
    (Icons.menu_book_outlined, '报刊文教'),
    (Icons.shopping_bag_outlined, '鞋包配饰'),
    (Icons.sanitizer_outlined, '洗护用品'),
    (Icons.cleaning_services_outlined, '清洁'),
  ];

  static const _statusChips = ['交易成功', '交易关闭'];
  static const _invoiceChips = ['已开票', '申请中', '未开票'];
  static const _sourceChips = ['天猫超市', '天猫国际'];
  static const _giftChips = ['我收到的', '我送出的'];

  void _toggle(String key) {
    setState(() {
      if (_sel.contains(key)) {
        _sel.remove(key);
      } else {
        _sel.add(key);
      }
    });
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Text(t,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      );

  Widget _chip(String label, {IconData? icon}) {
    final sel = _sel.contains(label);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _toggle(label),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFFFF1E8) : const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(6),
          border: sel
              ? Border.all(color: const Color(0xFFFF5000), width: 0.8)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 20,
                  color: sel ? const Color(0xFFFF5000) : Colors.black87),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: sel ? const Color(0xFFFF5000) : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _chipGrid(List<String> labels) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
          children: [for (final l in labels) _chip(l)],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.86,
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 4, 6),
            child: Row(
              children: [
                const Expanded(
                  child: Center(
                    child: Text('订单筛选',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87)),
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, size: 22, color: Colors.black87),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _sectionTitle('下单时间'),
                _chipGrid(_timeChips),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('起始时间',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF999999))),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('-',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF999999))),
                      ),
                      Expanded(
                        child: Container(
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F6F8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('终止时间',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF999999))),
                        ),
                      ),
                    ],
                  ),
                ),
                _sectionTitle('常买的类目'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.6,
                    children: [
                      for (final c in _categories) _chip(c.$2, icon: c.$1),
                    ],
                  ),
                ),
                // 收货地址
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    children: const [
                      Text('收货地址',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87)),
                      Spacer(),
                      Text('试试按地址关键字搜索订单 ›',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF999999))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _addrBox('山东省 淄博市 张店区', '中央公园(人民西路) 华润中央公园9号楼803'),
                      const SizedBox(height: 8),
                      _addrBox('山东省 淄博市 张店区', '中房大厦C座1001'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6F8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('展开更多地址 ∨',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF999999))),
                      ),
                    ],
                  ),
                ),
                _sectionTitle('订单状态'),
                _chipGrid(_statusChips),
                _sectionTitle('发票'),
                _chipGrid(_invoiceChips),
                _sectionTitle('来源'),
                _chipGrid(_sourceChips),
                _sectionTitle('礼物'),
                _chipGrid(_giftChips),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: '没有找到适合的筛选条件？',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF999999))),
                      TextSpan(
                          text: '试试订单搜索',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFFFF5000))),
                    ])),
                  ),
                ),
              ],
            ),
          ),
          // 底部按钮：重置（黄）/ 确认（橘）
          Padding(
            padding: EdgeInsets.fromLTRB(12, 6, 12, 10 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(_sel.clear),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFB400),
                        borderRadius:
                            BorderRadius.horizontal(left: Radius.circular(22)),
                      ),
                      child: const Text('重置',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5000),
                        borderRadius:
                            BorderRadius.horizontal(right: Radius.circular(22)),
                      ),
                      child: const Text('确认',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
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

  Widget _addrBox(String region, String detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(region,
              style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
          const SizedBox(height: 2),
          Text(detail,
              style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}

/// v1.9.115：三个点 → 快捷入口底部弹层（对齐真实淘宝，纯视觉可关闭）
/// 第一行：消息(带67角标)/回到首页/我的淘宝/购物车/我的订单
/// 第二行：我的足迹/我的收藏/专属客服/意见反馈/举报；底部取消按钮
class _ShortcutsSheet extends StatelessWidget {
  const _ShortcutsSheet();

  static const _row1 = <(IconData, String)>[
    (Icons.chat_bubble_outline, '消息'),
    (Icons.home_outlined, '回到首页'),
    (Icons.sentiment_satisfied_alt, '我的淘宝'),
    (Icons.shopping_cart_outlined, '购物车'),
    (Icons.receipt_long, '我的订单'),
  ];
  static const _row2 = <(IconData, String)>[
    (Icons.travel_explore, '我的足迹'),
    (Icons.star_border, '我的收藏'),
    (Icons.headset_mic_outlined, '专属客服'),
    (Icons.edit_outlined, '意见反馈'),
    (Icons.report_gmailerrorred_outlined, '举报'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上半部分白底图标区
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 22, 8, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRow(context, _row1, badgeOnFirst: true),
                  const SizedBox(height: 22),
                  _buildRow(context, _row2),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 取消按钮
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: const Text('取消',
                    style: TextStyle(fontSize: 16, color: Colors.black87)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<(IconData, String)> items,
      {bool badgeOnFirst = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (var i = 0; i < items.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
            child: SizedBox(
              width: 62,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(items[i].$1, color: Colors.black87, size: 28),
                      if (badgeOnFirst && i == 0)
                        Positioned(
                          right: -12,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5000),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('67',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 9)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(items[i].$2,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ============ v1.9.122：真实淘宝同款订单搜索页 ============
// 入口：订单列表顶栏搜索框（双击「筛选」按钮在经典/新版间切换）。
// 结构对齐真实淘宝：搜索栏（全部▾ + 输入框 + 筛选icon + 橙色搜索按钮）、
// 历史搜索 chips、历史搜过的订单横滑、常买推荐/常买好店；
// 输入时出联想（匹配商品 + 关键词橙色高亮）；提交后结果页
// （全部/购物N/闪购/飞猪 tab + 时间排序 + 订单卡片复用 _OrderCard）。
class OrderSearchScreen extends StatefulWidget {
  const OrderSearchScreen({super.key});

  @override
  State<OrderSearchScreen> createState() => _OrderSearchScreenState();
}

class _OrderSearchScreenState extends State<OrderSearchScreen> {
  static const _kHistoryKey = 'order_search_history_v1';
  static const _kSeenKey = 'order_search_seen_v1';
  static const _scopes = ['全部', '商品名', '订单号', '店铺名'];

  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  String _scope = '全部';
  bool _results = false; // false=搜索首页/联想  true=结果页
  String _keyword = '';
  int _resultTab = 0; // 0全部 1购物 2闪购 3飞猪
  bool _timeDesc = true; // 时间排序：默认最新在前

  List<String> _history = [];
  List<Map<String, dynamic>> _seen = []; // {t:标题, i:图, ts:毫秒}
  int _recTab = 0; // 0常买推荐 1常买好店

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    // v1.9.124：结果页再点搜索框 → 切回联想编辑界面并全选关键词
    // （对齐真实淘宝：搜索一次后点搜索框会再次弹出搜索界面）
    _focus.addListener(() {
      if (_focus.hasFocus && _results) {
        setState(() => _results = false);
        _ctrl.selection =
            TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
      }
    });
    // 进入页面自动弹键盘（对齐真实淘宝）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _history = p.getStringList(_kHistoryKey) ?? [];
      final raw = p.getString(_kSeenKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          _seen = (jsonDecode(raw) as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        } catch (_) {
          _seen = [];
        }
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// 全部订单店铺（排除购物车条目，与订单列表口径一致）
  List<ShoppingCartShop> _orderShops() {
    return context
        .read<CartProvider>()
        .shops
        .where((s) => !s.orderSubStatus.contains('购物车'))
        .toList();
  }

  bool _itemMatches(ShoppingCartShop shop, OrderItem it, String q) {
    switch (_scope) {
      case '商品名':
        return it.title.toLowerCase().contains(q);
      case '订单号':
        return it.orderNo.toLowerCase().contains(q) ||
            it.alipayTradeNo.toLowerCase().contains(q);
      case '店铺名':
        return shop.shopName.toLowerCase().contains(q);
      case '全部':
      default:
        return it.title.toLowerCase().contains(q) ||
            it.configuration.toLowerCase().contains(q) ||
            it.orderNo.toLowerCase().contains(q) ||
            shop.shopName.toLowerCase().contains(q);
    }
  }

  /// 关键词匹配的 店铺+命中商品 分组
  List<_ShopView> _matchGroups(String kw) {
    final q = kw.trim().toLowerCase();
    if (q.isEmpty) return [];
    final out = <_ShopView>[];
    for (final s in _orderShops()) {
      final items = s.items.where((it) => _itemMatches(s, it, q)).toList();
      if (items.isNotEmpty) out.add(_ShopView(s, items));
    }
    return out;
  }

  Future<void> _saveHistory(String kw) async {
    final p = await SharedPreferences.getInstance();
    _history.remove(kw);
    _history.insert(0, kw);
    if (_history.length > 10) _history = _history.sublist(0, 10);
    await p.setStringList(_kHistoryKey, _history);
  }

  Future<void> _saveSeen(List<_ShopView> groups) async {
    final p = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final g in groups) {
      for (final it in g.items.take(2)) {
        _seen.removeWhere((e) => e['t'] == it.title);
        _seen.insert(0, {'t': it.title, 'i': it.imageUrl, 'ts': now});
      }
    }
    if (_seen.length > 20) _seen = _seen.sublist(0, 20);
    await p.setString(_kSeenKey, jsonEncode(_seen));
  }

  Future<void> _submit([String? kw]) async {
    var k = (kw ?? _ctrl.text).trim();
    if (k.isEmpty && kw == null) {
      // v1.9.123 修复「第一次能搜、后续点搜索没反应」：
      // 搜狗等第三方输入法的组字挂在键盘候选栏、尚未提交进输入框，
      // 此时 _ctrl.text 为空导致静默 return——先断开输入连接让 IME
      // 把组字提交上屏，再取一次文本
      _focus.unfocus();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      k = _ctrl.text.trim();
    }
    if (k.isEmpty) return;
    if (kw != null) _ctrl.text = kw;
    final groups = _matchGroups(k);
    setState(() {
      _keyword = k;
      _results = true;
      _resultTab = 0;
    });
    _focus.unfocus();
    _saveHistory(k);
    if (groups.isNotEmpty) _saveSeen(groups);
  }

  String _seenLabel(dynamic ts) {
    final t = ts is int ? ts : int.tryParse('$ts') ?? 0;
    if (t <= 0) return '近期搜过';
    final d = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(t))
        .inDays;
    if (d <= 0) return '今天搜过';
    if (d == 1) return '昨天搜过';
    return '$d天前搜过';
  }

  String _fmtP(double p) =>
      p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);

  /// 关键词橙色高亮（对齐真实淘宝联想）
  Widget _hl(String text, String q, {TextStyle? style}) {
    if (q.isEmpty) {
      return Text(text,
          style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final lower = text.toLowerCase();
    final ql = q.toLowerCase();
    final spans = <TextSpan>[];
    var i = 0;
    while (true) {
      final j = lower.indexOf(ql, i);
      if (j < 0) {
        spans.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (j > i) spans.add(TextSpan(text: text.substring(i, j)));
      spans.add(TextSpan(
          text: text.substring(j, j + q.length),
          style: const TextStyle(color: Color(0xFFFF5000))));
      i = j + q.length;
    }
    return Text.rich(TextSpan(style: style, children: spans),
        maxLines: 1, overflow: TextOverflow.ellipsis);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            if (_results) _buildResultTabs(),
            Expanded(
              child: _results
                  ? _buildResults()
                  : _ctrl.text.trim().isNotEmpty
                      ? _buildSuggestions()
                      : _buildHome(),
            ),
          ],
        ),
      ),
    );
  }

  // ============ 顶部搜索栏（全部▾ + 输入 + 筛选icon + 橙搜索按钮） ============
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_results) {
                // 结果页返回 → 回到搜索编辑态（再点返回才退出）
                setState(() => _results = false);
                _focus.requestFocus();
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child:
                  Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
            ),
          ),
          Expanded(
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFFF5000), width: 1),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _pickScope,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      children: [
                        Text(_scope,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.black87)),
                        const Icon(Icons.keyboard_arrow_down,
                            size: 16, color: Color(0xFF999999)),
                      ],
                    ),
                  ),
                  Container(
                      width: 0.5,
                      height: 18,
                      color: const Color(0xFFDDDDDD),
                      margin: const EdgeInsets.symmetric(horizontal: 8)),
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                      textInputAction: TextInputAction.search,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
                      decoration: const InputDecoration(
                        hintText: '商品名/订单号/快递号',
                        hintStyle:
                            TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _ctrl.clear()),
                      child: const Icon(Icons.cancel,
                          size: 16, color: Color(0xFFCCCCCC)),
                    ),
                  const SizedBox(width: 6),
                  const Icon(Icons.filter_list,
                      size: 18, color: Color(0xFF999999)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _submit(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5000),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Text('搜索',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickScope() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
                padding: EdgeInsets.all(14),
                child: Text('搜索范围',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
            for (final s in _scopes)
              ListTile(
                dense: true,
                title: Text(s,
                    style: TextStyle(
                        fontSize: 14,
                        color: s == _scope
                            ? const Color(0xFFFF5000)
                            : Colors.black87)),
                trailing: s == _scope
                    ? const Icon(Icons.check,
                        color: Color(0xFFFF5000), size: 18)
                    : null,
                onTap: () {
                  setState(() => _scope = s);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ============ 搜索首页（历史搜索 / 历史搜过的订单 / 常买推荐·好店） ============
  Widget _buildHome() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
      children: [
        if (_history.isNotEmpty) ...[
          _sectionTitle('历史搜索', onClear: () async {
            final p = await SharedPreferences.getInstance();
            await p.remove(_kHistoryKey);
            setState(() => _history = []);
          }),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final k in _history)
                GestureDetector(
                  onTap: () => _submit(k),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(15)),
                    child: Text(k,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (_seen.isNotEmpty) ...[
          _sectionTitle('历史搜过的订单', onClear: () async {
            final p = await SharedPreferences.getInstance();
            await p.remove(_kSeenKey);
            setState(() => _seen = []);
          }),
          const SizedBox(height: 10),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _seen.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final e = _seen[i];
                return GestureDetector(
                  onTap: () => _submit((e['t'] ?? '').toString()),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: AppImage(
                            url: (e['i'] ?? '').toString(),
                            width: 88,
                            height: 88),
                      ),
                      const SizedBox(height: 5),
                      Text(_seenLabel(e['ts']),
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF999999))),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            _recTabBtn('常买推荐', 0),
            const SizedBox(width: 24),
            _recTabBtn('常买好店', 1),
          ],
        ),
        const SizedBox(height: 14),
        if (_recTab == 0) ..._buildRecGoods() else ..._buildRecShops(),
      ],
    );
  }

  Widget _sectionTitle(String t, {VoidCallback? onClear}) {
    return Row(
      children: [
        Text(t,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A))),
        const Spacer(),
        if (onClear != null)
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.delete_outline,
                size: 18, color: Color(0xFF999999)),
          ),
      ],
    );
  }

  Widget _recTabBtn(String t, int idx) {
    final active = _recTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _recTab = idx),
      child: Column(
        children: [
          Text(t,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? const Color(0xFFFF5000) : Colors.black87)),
          const SizedBox(height: 3),
          Container(
              width: 20,
              height: 2.5,
              decoration: BoxDecoration(
                  color: active ? const Color(0xFFFF5000) : Colors.transparent,
                  borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  /// 常买推荐：按标题聚合全订单商品，购买次数降序
  List<Widget> _buildRecGoods() {
    final agg = <String, Map<String, dynamic>>{};
    for (final s in _orderShops()) {
      for (final it in s.items) {
        final e = agg.putIfAbsent(it.title, () => {'it': it, 'n': 0});
        e['n'] = (e['n'] as int) + it.quantity;
      }
    }
    final list = agg.values.toList()
      ..sort((a, b) => (b['n'] as int).compareTo(a['n'] as int));
    if (list.isEmpty) {
      return [
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
                child: Text('暂无常买商品',
                    style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)))))
      ];
    }
    return [
      for (final e in list.take(8))
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AppImage(
                    url: (e['it'] as OrderItem).imageUrl,
                    width: 64,
                    height: 64),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((e['it'] as OrderItem).title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('¥${_fmtP((e['it'] as OrderItem).price)}',
                            style: const TextStyle(
                                color: Color(0xFFFF5000),
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text('买过${e['n']}次',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF999999))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  /// 常买好店：店铺头像 + 名称 + 88VIP好评率 + 买过N次 + 进店
  List<Widget> _buildRecShops() {
    final shops = _orderShops();
    if (shops.isEmpty) {
      return [
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(
                child: Text('暂无常买店铺',
                    style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)))))
      ];
    }
    return [
      for (final s in shops.take(8))
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              ClipOval(
                child: s.shopAvatar.isNotEmpty
                    ? AppImage(url: s.shopAvatar, width: 44, height: 44)
                    : Container(
                        width: 44,
                        height: 44,
                        color: const Color(0xFFB23A2E),
                        alignment: Alignment.center,
                        child: Text(
                            s.shopName.isEmpty
                                ? '店'
                                : s.shopName.substring(0, 1),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('88VIP好评率99%',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFFF5000))),
                        const SizedBox(width: 8),
                        Text(
                            '买过${s.items.fold(0, (sum, it) => sum + it.quantity)}次',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF999999))),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ShopHomeScreen(shopName: s.shopName))),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                      borderRadius: BorderRadius.circular(14)),
                  child: const Text('进店',
                      style: TextStyle(fontSize: 12, color: Colors.black87)),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  // ============ 输入联想（匹配商品 + 关键词高亮） ============
  Widget _buildSuggestions() {
    final q = _ctrl.text.trim();
    final ql = q.toLowerCase();
    final matched = <(ShoppingCartShop, OrderItem)>[];
    for (final s in _orderShops()) {
      for (final it in s.items) {
        if (_itemMatches(s, it, ql)) matched.add((s, it));
        if (matched.length >= 3) break;
      }
      if (matched.length >= 3) break;
    }
    // 关键词联想：历史 + 店铺名 + 命中商品标题
    final kws = <String>[];
    for (final h in _history) {
      if (h.toLowerCase().contains(ql) && h != q && !kws.contains(h)) {
        kws.add(h);
      }
    }
    for (final s in _orderShops()) {
      if (s.shopName.toLowerCase().contains(ql) && !kws.contains(s.shopName)) {
        kws.add(s.shopName);
      }
    }
    for (final (_, it) in matched) {
      if (it.title.toLowerCase().contains(ql) &&
          !kws.contains(it.title) &&
          kws.length < 8) {
        kws.add(it.title);
      }
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: [
        const SizedBox(height: 4),
        for (final (s, it) in matched)
          GestureDetector(
            onTap: () => _submit(),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: AppImage(url: it.imageUrl, width: 44, height: 44),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _hl(it.title, q,
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF1A1A1A))),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            if (it.configuration.isNotEmpty)
                              Flexible(
                                child: Text(it.configuration,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF999999))),
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(s.shopName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: Color(0xFF999999))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 18, color: Color(0xFFCCCCCC)),
                ],
              ),
            ),
          ),
        for (final k in kws.take(6))
          GestureDetector(
            onTap: () => _submit(k),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(AppIcons.search,
                      size: 16, color: Color(0xFFBBBBBB)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _hl(k, q,
                          style: const TextStyle(
                              fontSize: 14, color: Color(0xFF1A1A1A)))),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============ 结果页（全部/购物N/闪购/飞猪 + 时间排序） ============
  Widget _buildResultTabs() {
    final n = _matchGroups(_keyword).fold(0, (sum, g) => sum + g.items.length);
    final labels = ['全部', '购物${n > 0 ? ' $n' : ''}', '闪购', '飞猪'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) _rtTab(labels[i], i),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _timeDesc = !_timeDesc),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  Text('时间',
                      style: TextStyle(
                          fontSize: 14,
                          color: _timeDesc
                              ? Colors.black87
                              : const Color(0xFFFF5000))),
                  const Icon(Icons.swap_vert, size: 15, color: Colors.black87),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rtTab(String label, int idx) {
    final active = _resultTab == idx;
    return GestureDetector(
      onTap: () => setState(() => _resultTab = idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                    color: active ? const Color(0xFFFF5000) : Colors.black87)),
            const SizedBox(height: 3),
            Container(
                width: 18,
                height: 2.5,
                decoration: BoxDecoration(
                    color:
                        active ? const Color(0xFFFF5000) : Colors.transparent,
                    borderRadius: BorderRadius.circular(2))),
          ],
        ),
      ),
    );
  }

  String _actionTextOf(ShoppingCartShop shop) {
    final st = shop.orderSubStatus;
    if (st.contains('待付款') || st.contains('等待付款')) return '去支付';
    if (st.contains('待发货') || st.contains('等待发货')) return '提醒发货';
    if (st.contains('评价') && !st.contains('退款') && !st.contains('售后')) {
      return '评价';
    }
    if (st.contains('已发货') ||
        st.contains('运输中') ||
        st.contains('派送中') ||
        st.contains('签收')) {
      return '确认收货';
    }
    return '查看详情';
  }

  Widget _buildResults() {
    // 闪购/飞猪：购物频道外的订单不参与（对齐真实淘宝分频道）
    if (_resultTab == 2 || _resultTab == 3) {
      return _emptyHint('暂无相关订单');
    }
    final groups = _matchGroups(_keyword);
    if (groups.isEmpty) return _emptyHint('未找到相关订单');
    // 时间排序（付款时间优先，其次创建时间，字符串近似时间序）
    String tOf(_ShopView g) {
      final it = g.items.first;
      return it.payTime.isNotEmpty ? it.payTime : it.createTime;
    }

    groups.sort((a, b) =>
        _timeDesc ? tOf(b).compareTo(tOf(a)) : tOf(a).compareTo(tOf(b)));
    return Container(
      color: const Color(0xFFF5F5F5),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: groups.length,
        itemBuilder: (_, i) => _OrderCard(
          shop: groups[i].shop,
          items: groups[i].items,
          actionText: _actionTextOf(groups[i].shop),
          onEditItem: (item) => _editItem(groups[i].shop, item),
          onDetail: (item) => _gotoDetail(groups[i].shop, item),
        ),
      ),
    );
  }

  Widget _emptyHint(String msg) {
    return Container(
      color: const Color(0xFFF5F5F5),
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 72, color: Color(0xFFC4C4C4)),
          const SizedBox(height: 12),
          Text(msg,
              style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
          const SizedBox(height: 6),
          const Text('换个商品关键词或店铺名试试',
              style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
        ],
      ),
    );
  }

  // ============ 进入订单/退款详情、编辑菜单（与订单列表同一套逻辑） ============
  void _gotoDetail(ShoppingCartShop shop, OrderItem item) {
    final isRefund = shop.orderSubStatus.contains('退款') ||
        shop.orderSubStatus.contains('售后');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isRefund
            ? RefundDetailScreen(shop: shop, item: item)
            : OrderDetailScreen(shop: shop, item: item),
      ),
    );
  }

  void _editItem(ShoppingCartShop shop, OrderItem item) {
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
}
