import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/material_pool_provider.dart';
import '../../providers/product_image_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/image_picker_helper.dart';
import 'refund_detail_screen.dart';
import 'rate_order_screen.dart';
import 'logistics_screen.dart';
import 'complaint_screen.dart';
import '../message/chat_screen.dart';

/// 订单详情页（严格对齐 v3.4 APK 待发货/待收货详情）
class OrderDetailScreen extends StatefulWidget {
  final ShoppingCartShop shop;
  final OrderItem item;

  const OrderDetailScreen({
    super.key,
    required this.shop,
    required this.item,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late OrderItem _item;
  late ShoppingCartShop _shop;
  bool _addressExpanded = false; // 地址区单击展开查看完整信息
  bool _orderInfoExpanded = false; // 订单信息折叠（v1.9.85 恢复：默认折叠，点标题展开）
  bool _shopDiscountExpanded = false; // 店铺优惠明细展开（v1.9.93）
  // 商品标题展开状态（v1.9.99：>16字默认折叠1行，点∨展开；key=商品标题）
  final Set<String> _expandedTitles = {};
  bool _platformCouponExpanded = false; // 平台优惠明细展开（v1.9.93）

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _shop = widget.shop;
  }

  bool get _isPendingShip => _item.statusTitle.contains('待发货');

  /// 待评价订单（已交易成功待买家评价）：详情页标题/物流条对齐真实淘宝交易成功单
  bool get _isWaitRate =>
      _item.statusTitle.contains('待评价') ||
      _shop.orderSubStatus.contains('待评价');

  /// 订单编号（订单信息行）：5127 开头 19 位
  String get _orderNo => _item.orderNo;

  /// 交易号：按支付方式取 支付宝/微信 交易号（28 位）
  String get _tradeNo => context.read<CartProvider>().tradeNoFor(_item);

  @override
  Widget build(BuildContext context) {
    context.watch<CartProvider>();
    context.watch<ProductImageProvider>();

    // 待评价订单详情标题对齐真实淘宝：交易成功
    final title = _item.statusTitle.isEmpty
        ? '订单详情'
        : _isWaitRate
            ? '交易成功'
            : _item.statusTitle;
    return Scaffold(
      backgroundColor: const Color(0xFFf5f5f5),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(title),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    _buildStatusHeader(),
                    // 准时送达卡：独立白色框架，上下灰条间隔（可隐藏）
                    if (_item.showOnTime) ...[
                      _greyBar(),
                      _buildOnTimeCard(),
                    ],
                    _greyBar(),
                    _buildShopCard(),
                    // 店铺与商品同一框架：细分隔线衔接（同下方灰线样式）
                    _lineDivider(),
                    // v1.9.96：合并订单（同单号多商品）逐商品一张卡
                    ..._buildProductCards(),
                    _greyBar(),
                    _buildOrderInfoCard(),
                    _greyBar(),
                    _buildGuaranteeCard(),
                    _greyBar(),
                    _buildRecommendCard(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  /// 栏目之间的灰色长条（直角通栏分隔）
  Widget _greyBar() {
    return Container(height: 10, color: const Color(0xFFf0f0f0));
  }

  /// 店铺卡与商品卡之间的细分隔线（与下方价格区灰线一致）
  Widget _lineDivider() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Divider(height: 1, thickness: 1, color: Color(0xFFf0f0f0)),
    );
  }

  // ============ 顶部栏 ============
  Widget _buildAppBar(String title) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios,
                color: Colors.black87, size: 22),
          ),
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                // v1.9.99：标题加大加粗（对齐真实淘宝状态页标题）
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87)),
          ),
          // 编辑入口：双击打开编辑菜单
          GestureDetector(
            onDoubleTap: () => _showEditMenu(),
            child: const Icon(Icons.more_horiz,
                color: Colors.black87, size: 24),
          ),
        ],
      ),
    );
  }

  // ============ 状态头（3.4 样式：大标题居中 + 倒计时 + 物流行 + 地址 + 承诺发货 + 准时送达） ============
  Widget _buildStatusHeader() {
    final provider = context.read<CartProvider>();
    final category = CartProvider.statusCategory(
        _item.statusTitle.isEmpty ? _shop.orderSubStatus : _item.statusTitle);
    final showCountdown = category == '待收货';
    final logisticsOptions = [
      '已揽件 · 预计后天送达',
      '运输中 · 预计明天送达',
      '派送中 · 快递员正在派送',
      '已签收 · 包裹已到达',
      '已到达代收点',
      '物流异常 · 请联系快递员',
    ];
    // 物流阶段图标/标签
    final stage = _logisticsStage();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 倒计时（居中橙色，双击滚动选择器编辑）
          if (showCountdown) ...[
            GestureDetector(
              onDoubleTap: _editCountdown,
              child: Center(
                child: Text(
                  _item.countDown.isEmpty
                      ? '还剩3天21小时自动确认'
                      : _item.countDown,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFFF5000)),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // 物流状态行（单击 → 物流详情页，对齐真实淘宝；双击换选项）
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => LogisticsScreen(
                      item: _item, shopName: _shop.shopName)),
            ),
            onDoubleTap: () => _showOptionPicker(
              title: '修改物流状态',
              options: logisticsOptions,
              currentValue: _item.logistics,
              onSave: (v) => provider.updateOrderItem(_item, logistics: v),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(stage.$2, color: const Color(0xFFFF5000), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${stage.$1}  ',
                          style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFFF5000),
                              fontWeight: FontWeight.w600)),
                      TextSpan(
                        text: _bannerLogisticsText,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF333333)),
                      ),
                    ]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 16, color: Color(0xFFcccccc)),
              ],
            ),
          ),
          // 地址区（单击展开/收起完整信息，双击手动输入：第一行收件人，其余地址）
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () =>
                setState(() => _addressExpanded = !_addressExpanded),
            onDoubleTap: () => _editText('修改地址（第一行收件人，第二行起地址）',
                '${_item.receiver}\n${_item.address}', (v) {
              final lines = v
                  .split('\n')
                  .map((l) => l.trim())
                  .where((l) => l.isNotEmpty)
                  .toList();
              if (lines.isNotEmpty) {
                provider.updateOrderItem(_item, receiver: lines.first);
              }
              if (lines.length > 1) {
                provider.updateOrderItem(
                    _item, address: lines.sublist(1).join('\n'));
              }
            }, maxLines: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _item.address.isEmpty
                      ? '中房大厦C座1001'
                      : _item.address.replaceAll('\n', ' '),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${_item.receiver.isEmpty ? '黑山灰' : _item.receiver} 86-186****5652',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF666666)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Text('号码保护中',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF999999))),
                    ),
                    const SizedBox(width: 6),
                    const Text('取件出示虚拟号 ›',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFFFF5000))),
                    const Spacer(),
                    Icon(
                      _addressExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: const Color(0xFFBBBBBB),
                    ),
                  ],
                ),
                // 展开区：完整收货信息（对齐真实淘宝点击地址展开）
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _addrInfoRow('收货人',
                            _item.receiver.isEmpty ? '黑山灰' : _item.receiver),
                        const SizedBox(height: 6),
                        _addrInfoRow('手机号', '86-186****5652（号码保护中）'),
                        const SizedBox(height: 6),
                        _addrInfoRow(
                            '收货地址',
                            _item.address.isEmpty
                                ? '中房大厦C座1001'
                                : _item.address.replaceAll('\n', ' ')),
                        const SizedBox(height: 6),
                        _addrInfoRow('虚拟号', '86-186****5652（取件出示）'),
                      ],
                    ),
                  ),
                  crossFadeState: _addressExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
          // 承诺发货行（移到地址下方，可编辑文字，可隐藏）
          if (_isPendingShip && _item.showDeliveryPromise) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onDoubleTap: () => _editText('修改发货承诺', _item.deliveryPromise, (v) {
                provider.updateOrderItem(_item, deliveryPromise: v);
              }),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: Color(0xFF4caf50), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _item.deliveryPromise.isEmpty
                          ? '承诺48小时内发货'
                          : _item.deliveryPromise,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333)),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      size: 14, color: Color(0xFF999999)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ 准时送达卡（独立白色框架，上下灰条间隔，单排/双排两种样式可选） ============
  int get _onTimeStyle => _item.onTimeStyle >= 0
      ? _item.onTimeStyle
      : _item.title.hashCode.abs() % 2;

  String get _onTimeMainText {
    final t = _item.onTimeText;
    if (t.isEmpty || t == '准时送达') {
      return _onTimeStyle == 0 ? '预计明天送达' : '承诺08月30日送货上门';
    }
    return t;
  }

  Widget _buildOnTimeCard() {
    final provider = context.read<CartProvider>();
    // v1.9.99：图标换用户提供的 UI 贴图，字体加大（对齐真实淘宝准时达卡）
    const textStyle = TextStyle(
        fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A));
    const clockIcon = Image(
        image: AssetImage('assets/images/icons/ontime_clock.png'),
        width: 18,
        height: 18);
    const boxIcon = Image(
        image: AssetImage('assets/images/icons/ontime_box.png'),
        width: 18,
        height: 18);
    if (_onTimeStyle == 0) {
      // 样式0：单排「预计XX送达」+ 箭头
      return Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: GestureDetector(
          onDoubleTap: () => _editText('修改准时送达文字', _item.onTimeText, (v) {
            provider.updateOrderItem(_item, onTimeText: v);
          }),
          child: Row(
            children: [
              clockIcon,
              const SizedBox(width: 8),
              Expanded(
                child: Text(_onTimeMainText, style: textStyle),
              ),
              const Icon(Icons.chevron_right,
                  size: 16, color: Color(0xFF999999)),
            ],
          ),
        ),
      );
    }
    // 样式1：双排「承诺XX送货上门」/「送货上门」（中间细分隔线）
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          GestureDetector(
            onDoubleTap: () =>
                _editText('修改准时送达文字', _item.onTimeText, (v) {
              provider.updateOrderItem(_item, onTimeText: v);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  clockIcon,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_onTimeMainText, style: textStyle),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFf0f0f0)),
          GestureDetector(
            onDoubleTap: () =>
                _editText('修改第二行文字', _item.onTimeText2, (v) {
              provider.updateOrderItem(_item, onTimeText2: v);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  boxIcon,
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _item.onTimeText2.isEmpty
                          ? '送货上门'
                          : _item.onTimeText2,
                      style: textStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 状态头物流条文字：交易成功/待评价对齐真实淘宝（"已签收  黑山灰 送至 …"），
  /// 待发货=备货文案，其余状态沿用物流文字
  String get _bannerLogisticsText {
    final l = _item.logistics;
    final category = CartProvider.statusCategory(
        _item.statusTitle.isEmpty ? _shop.orderSubStatus : _item.statusTitle);
    if (_isWaitRate || category == '已完成') {
      if (l.contains('签收')) return l;
      final recv = _item.receiver.isEmpty ? '黑山灰' : _item.receiver;
      final addr = _item.address.isEmpty
          ? '中房大厦C座1001'
          : _item.address.replaceAll('\n', ' ');
      return '$recv 86-186****5652 送至 $addr';
    }
    if (category == '待发货' || category == '待付款') {
      // 未发货不展示物流（对齐真实淘宝），备货文案
      return '商家正在备货，将在承诺时间内尽快发货';
    }
    return l.isEmpty ? '包裹正在运输途中，请耐心等待' : l;
  }

  /// 根据物流文字推断阶段标签和图标
  (String, IconData) _logisticsStage() {
    final l = _item.logistics;
    final t = _item.statusTitle;
    final category = CartProvider.statusCategory(
        t.isEmpty ? _shop.orderSubStatus : t);
    // 交易成功/待评价订单物流条固定为已签收（对齐真实淘宝交易成功单）
    // v1.9.86：不再只看待评价——退款等状态改成交易成功后同样是已签收
    if (_isWaitRate || category == '已完成') {
      return ('已签收', Icons.check_circle);
    }
    // 待发货/待付款：固定等待发货（v1.9.86 修复：'待发货'含'发货'曾被误判成运输中）
    if (category == '待发货' || category == '待付款') {
      return ('等待发货', Icons.access_time);
    }
    if (l.contains('揽件')) {
      return ('已揽件', Icons.inventory_2_outlined);
    }
    if (l.contains('派送')) {
      return ('派送中', Icons.electric_moped_outlined);
    }
    if (l.contains('签收') || t.contains('签收')) {
      return ('已签收', Icons.check_circle);
    }
    if (l.contains('异常')) {
      return ('物流异常', Icons.error_outline);
    }
    return ('运输中', Icons.local_shipping_outlined);
  }

  // ============ 店铺卡片 ============
  Widget _buildShopCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 商家头像：双击从手机相册选择
              GestureDetector(
                onDoubleTap: () => _pickShopAvatar(),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFff0036),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: _shopAvatar(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onDoubleTap: () => _editText('修改店铺名', _shop.shopName, (v) {
                        context.read<CartProvider>().updateShop(_shop, shopName: v);
                      }),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_shop.shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                          ),
                          // v1.9.99：店名右侧 > 箭头已删（用户要求）
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    // 店名下方信息行：6 种样式可选（双击切换），对标真实淘宝
                    _shopInfoLine(),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // 进店逛逛：无边框，仅文字 + 箭头（对齐真实淘宝订单详情）
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('进店逛逛',
                      style: TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                  Icon(Icons.chevron_right,
                      color: Color(0xFF999999), size: 16),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- 店名下方信息行：6 种样式可选（-1=按店名随机），双击弹出切换 ----
  static const List<String> _shopLineOptions = [
    '随机（按店名）',
    '★星级 + 粉丝数',
    '88VIP好评率 + 平均退款时长',
    '88VIP好评率 + 客服满意度',
    '好评率 + 平均退款时长',
    '90天新增好评 + 平均退款时长',
    '90天新增好评',
  ];

  int get _shopLineStyle => _shop.shopLineStyle >= 0
      ? _shop.shopLineStyle
      : _shop.shopName.hashCode.abs() % 6;

  /// 90天新增好评条数：按店名稳定生成 20~99
  int get _shopNewReviews => 20 + _shop.shopName.hashCode.abs() % 80;

  void _pickShopLineStyle() {
    DialogHelpers.showOptionPicker(
      context,
      title: '店铺信息行样式',
      options: _shopLineOptions,
      currentValue: _shopLineOptions[_shop.shopLineStyle + 1],
    ).then((v) {
      if (v == null) return;
      final idx = _shopLineOptions.indexOf(v);
      context.read<CartProvider>().updateShop(_shop, shopLineStyle: idx - 1);
    });
  }

  Widget _shopInfoLine() {
    const grey = TextStyle(fontSize: 11, color: Color(0xFF999999));
    Widget child;
    switch (_shopLineStyle) {
      case 0:
        child = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(
                5,
                (_) => const Icon(Icons.star,
                    color: Color(0xFFFF5000), size: 12)),
            const SizedBox(width: 3),
            Text('${_shop.fansCount}粉丝',
                style: grey, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        );
        break;
      case 1:
        child = Text('88VIP好评率${_shop.goodRate}，平均17小时退款',
            style: grey, maxLines: 1, overflow: TextOverflow.ellipsis);
        break;
      case 2:
        child = Text('88VIP好评率${_shop.goodRate}，客服满意度${_shop.csRate}',
            style: grey, maxLines: 1, overflow: TextOverflow.ellipsis);
        break;
      case 3:
        child = Text('好评率${_shop.goodRate}，平均21小时退款',
            style: grey, maxLines: 1, overflow: TextOverflow.ellipsis);
        break;
      case 4:
        child = Text('90天新增$_shopNewReviews条好评，平均2天退款',
            style: grey, maxLines: 1, overflow: TextOverflow.ellipsis);
        break;
      default:
        child = Text('90天新增$_shopNewReviews条好评',
            style: grey, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return GestureDetector(onDoubleTap: _pickShopLineStyle, child: child);
  }

  /// 商家头像显示：优先相册替换图（以店铺名为 key 持久化）
  Widget _shopAvatar() {
    final override =
        context.watch<ProductImageProvider>().imageFor('shop_avatar:${_shop.shopName}');
    if (override != null) {
      return AppImage(url: override, width: 30, height: 30);
    }
    // v1.9.78：抓包真实店铺头像优先
    if (_shop.shopAvatar.isNotEmpty) {
      return AppImage(url: _shop.shopAvatar, width: 30, height: 30);
    }
    return const Icon(Icons.favorite, color: Colors.white, size: 16);
  }

  Future<void> _pickShopAvatar() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/shop_avatars');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'shop_${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(picked.path).copy('${saveDir.path}/$fileName');
      if (!mounted) return;
      // v1.9.102：存相对 Documents 路径——自签重装容器变化后头像不丢
      await context
          .read<ProductImageProvider>()
          .setOverride('shop_avatar:${_shop.shopName}',
              'shop_avatars/$fileName');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商家头像已替换'), duration: Duration(seconds: 1)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片选择失败')),
      );
    }
  }

  // ============ 商品卡片 ============
  /// 同订单（同单号）的全部商品（v1.9.96：合并订单详情显示全部商品卡）
  List<OrderItem> get _orderItems {
    final list = _shop.items
        .where((e) => e.orderNo.isNotEmpty && e.orderNo == _item.orderNo)
        .toList();
    return list.isEmpty ? [_item] : list;
  }

  /// 商品卡"实付价"行的单价：抓包新数据 price 本就是单价（如 32×2）；
  /// 但旧数据/手动录入的订单 price 可能存的是整单总价（如 99×2），
  /// 此时自动 ÷quantity 还原单价，对齐真实淘宝"¥32×2"而非"¥99×2"。
  /// v1.9.96：实付价不含运费——price≈actualTotal（整单实付，含运费）时
  /// 先把运费剥掉再 ÷数量（旧数据 price 被运费污染过的也能显示对）。
  double _unitPriceOf(OrderItem it) {
    if (it.quantity > 1) {
      // 优先用 actualTotal 判断（整单实付，含运费，最准）
      if (_shop.actualTotal > 0) {
        // price ≈ actualTotal → price 是总价（含运费）：剥运费后 ÷quantity
        if ((it.price - _shop.actualTotal).abs() < 1.0) {
          final ship = it.showShippingFee ? it.shippingFee : 0.0;
          return (it.price - ship) / it.quantity;
        }
        // price × qty ≈ actualTotal → price 是单价，直接用
        if ((it.price * it.quantity - _shop.actualTotal).abs() < 1.0) {
          return it.price;
        }
      }
      // actualTotal 缺失时退而用 productTotal（原价×数量，不含运费）
      if (it.productTotal > 0) {
        if ((it.price - it.productTotal).abs() < 1.0) {
          return it.price / it.quantity;
        }
      }
    }
    return it.price;
  }

  /// 同订单全部商品卡（v1.9.96：合并订单每商品一张卡，价格区只跟最后一张）
  List<Widget> _buildProductCards() {
    final items = _orderItems;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(_lineDivider());
      out.add(_buildProductCard(items[i],
          withPriceSection: i == items.length - 1));
    }
    return out;
  }

  Widget _buildProductCard(OrderItem it, {bool withPriceSection = true}) {
    final override = context.watch<ProductImageProvider>().imageFor(it.title);
    final imageUrl = override ?? it.imageUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onDoubleTap: () => _pickProductImage(it),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AppImage(
                    url: imageUrl,
                    width: 90,
                    height: 90,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // v1.9.99：标题>16字默认折叠1行（∨按钮展开），右侧灰色
                    // 单价（优惠前单价=商品总价÷数量，样式同商品总价）+ xN
                    Builder(builder: (context) {
                      final collapsible = it.title.length > 16;
                      final expanded =
                          _expandedTitles.contains(it.title);
                      final unitOriginal = it.productTotal > 0
                          ? it.productTotal /
                              (it.quantity > 0 ? it.quantity : 1)
                          : _unitPriceOf(it);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onDoubleTap: () =>
                                  _editText('修改商品标题', it.title, (v) {
                                context
                                    .read<CartProvider>()
                                    .updateOrderItem(it, title: v);
                              }),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(it.title,
                                        maxLines: collapsible && !expanded
                                            ? 1
                                            : 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.small),
                                  ),
                                  if (collapsible)
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        expanded
                                            ? _expandedTitles
                                                .remove(it.title)
                                            : _expandedTitles
                                                .add(it.title);
                                      }),
                                      child: Icon(
                                        expanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: const Color(0xFF999999),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  '¥${unitOriginal.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF666666))),
                              const SizedBox(height: 10),
                              // 数量双击可改（x1、x2…）
                              GestureDetector(
                                onDoubleTap: () => _editNumber(
                                    '修改数量', it.quantity.toDouble(), (v) {
                                  context
                                      .read<CartProvider>()
                                      .updateOrderItem(it,
                                          quantity: v.round() < 1
                                              ? 1
                                              : v.round());
                                }),
                                child: Text('x${it.quantity}',
                                    style: AppTextStyles.minSub),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onDoubleTap: () => _editText('修改规格', it.configuration, (v) {
                        context.read<CartProvider>().updateOrderItem(it, configuration: v);
                      }),
                      child: Text(it.configuration,
                          style: AppTextStyles.minSub),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      // v1.9.81：displayTags 合并去重——「7天无理由」与
                      // 「7天无理由退货」只保留后者；抓包无标签自动补默认
                      // v1.9.97：对齐真实淘宝——绿色字体不带框
                      children: [
                        ...it.displayTags.map(_greenTag),
                        const Icon(Icons.chevron_right,
                            size: 13, color: Color(0xFF00A870)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('实付价 ',
                            style: AppTextStyles.minSub),
                        Text('¥',
                            style: AppTextStyles.price
                                .copyWith(fontSize: 12)),
                        // v1.9.90：商品卡显示单价，对齐真实淘宝 ¥33×3 而非 ¥99×3。
                        // v1.9.96：实付价不含运费（旧数据 price 含运费时自动剥掉）
                        // v1.9.97：双击金额=直接改该商品实付价（多商品订单各改各的）
                        GestureDetector(
                          onDoubleTap: () => _editNumber(
                              '修改实付价（不含运费）', it.price, (v) {
                            context
                                .read<CartProvider>()
                                .updateOrderItem(it, price: v);
                          }),
                          child: Text(_unitPriceOf(it).toStringAsFixed(2),
                              style: AppTextStyles.price
                                  .copyWith(fontSize: 18)),
                        ),
                        const SizedBox(width: 6),
                        // v1.9.97：价格明细入口（对齐真实淘宝，绿色文字+箭头）
                        const Text('价格明细',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFF00A870))),
                        const Icon(Icons.chevron_right,
                            size: 12, color: Color(0xFF00A870)),
                        const Spacer(),
                        // v1.9.99：xN 已移至标题右侧灰色单价下方
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // v1.9.97：更换款式（对齐真实淘宝，橙色带框；点击=改规格）
              // v1.9.98：默认隐藏，⋯菜单「显示更换款式」开关打开才显示
              if (it.showStyleBtn && it.configuration.isNotEmpty) ...[
                _orangeOutlineBtn('更换款式', onTap: () => _editText(
                    '更换款式', it.configuration, (v) {
                  context
                      .read<CartProvider>()
                      .updateOrderItem(it, configuration: v);
                })),
                const SizedBox(width: 8),
              ],
              _outlineBtn('加入购物车', onTap: () => _reAddToCart(it)),
              const SizedBox(width: 8),
              // 对齐真实淘宝：待发货=申请退款，已发货/完成=申请售后，统一灰框黑字
              _outlineBtn(_isPendingShip ? '申请退款' : '申请售后',
                  onTap: () => _gotoRefund(it)),
            ],
          ),
          // v1.9.83：删除商品卡「加入购物车/申请售后」按钮下方那条空白虚线分隔线
          // v1.9.85：赠品栏（对齐真实淘宝：赠品 | 1件 + 缩略图 + >；双击编辑件数，0=隐藏）
          if (it.giftCount > 0) _giftRow(it),
          if (withPriceSection) ..._priceSectionChildren(),
        ],
      ),
    );
  }

  Future<void> _pickProductImage(OrderItem it) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/product_images');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(picked.path).copy('${saveDir.path}/$fileName');
      if (!mounted) return;
      // v1.9.102：存相对 Documents 路径——自签重装容器变化后图片不丢
      final rel = 'product_images/$fileName';
      await context
          .read<ProductImageProvider>()
          .setOverride(it.title, rel);
      context.read<CartProvider>().updateOrderItem(it, imageUrl: rel);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品图已替换'), duration: Duration(seconds: 1)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片选择失败')),
      );
    }
  }

  /// 把该订单商品重新加回购物车（再次购买）
  void _reAddToCart(OrderItem it) {
    context.read<CartProvider>().addToCart(
          shopName: _shop.shopName,
          title: it.title,
          price: it.price,
          imageUrl: it.imageUrl,
          spec: it.configuration,
          quantity: it.quantity,
        );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已加入购物车'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 申请售后：进入退款/售后详情页
  void _gotoRefund(OrderItem it) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RefundDetailScreen(shop: _shop, item: it),
      ),
    );
  }

  /// 赠品栏（v1.9.85）：对齐真实淘宝——左"赠品"，右"N件 + 缩略图 + >"
  /// 单击=编辑赠品件数（输入 0 隐藏），双击=换赠品图，长按=编辑赠品名
  Widget _giftRow(OrderItem it) {
    return GestureDetector(
      onTap: () =>
          _editNumber('修改赠品件数（0=隐藏赠品栏）', it.giftCount.toDouble(),
              (v) {
        context
            .read<CartProvider>()
            .updateOrderItem(it, giftCount: v.round());
      }),
      onDoubleTap: () => _pickGiftImage(it),
      onLongPress: () =>
          _editText('修改赠品名称', it.giftTitle, (v) {
        context.read<CartProvider>().updateOrderItem(it, giftTitle: v);
      }),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: Row(
          children: [
            const Text('赠品',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const Spacer(),
            Text('${it.giftCount}件',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF666666))),
            const SizedBox(width: 8),
            // v1.9.102：多张赠品缩略图（抓包 gifts 数组全量），
            // 最多展示 3 张；无图时灰色占位——之前只显示 1 张导致"赠品显示不全"
            for (final g in _giftThumbs(it).take(3))
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AppImage(url: g, width: 26, height: 26),
                ),
              ),
            if (_giftThumbs(it).isEmpty)
              Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.card_giftcard,
                    size: 16, color: Color(0xFFbbbbbb)),
              ),
            const Icon(Icons.chevron_right,
                color: Color(0xFFcccccc), size: 18),
          ],
        ),
      ),
    );
  }

  /// 赠品缩略图列表：giftImages（抓包多图）优先，空时回退 giftImage 单图
  List<String> _giftThumbs(OrderItem it) {
    if (it.giftImages.isNotEmpty) return it.giftImages;
    if (it.giftImage.isNotEmpty) return [it.giftImage];
    return const [];
  }

  /// 换赠品缩略图（双击赠品行触发）
  Future<void> _pickGiftImage(OrderItem it) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/gift_images');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'gift_${DateTime.now().millisecondsSinceEpoch}$ext';
      await File(picked.path).copy('${saveDir.path}/$fileName');
      if (!mounted) return;
      // v1.9.102：存相对 Documents 路径——自签重装容器变化后图片不丢
      final rel = 'gift_images/$fileName';
      context
          .read<CartProvider>()
          .updateOrderItem(it, giftImage: rel, giftImages: [rel]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片选择失败')),
      );
    }
  }

  // v1.9.97：服务标签对齐真实淘宝——绿色字体、不带框
  Widget _greenTag(String text) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFF00A870), fontSize: 10));
  }

  // ============ 价格明细（与商品卡同一栏目） ============
  List<Widget> _priceSectionChildren() {
    // v1.9.96：合并订单（多商品同单号）商品总价/件数按全订单聚合
    final productTotal = _orderItems.fold<double>(0, (s, e) {
      final pt = e.productTotal > 0
          ? e.productTotal
          : e.price + e.shopDiscount + e.platformCoupon;
      return s + pt;
    });
    final totalQty = _orderItems.fold<int>(0, (s, e) => s + e.quantity);
    // 实付款：抓包导入的订单带整单实付总额（单价×数量有分位差），优先用
    final total =
        _shop.actualTotal > 0 ? _shop.actualTotal : _item.price;
    // 优惠子项（v1.9.93）：抓包/手动编辑的明细优先，空则按总额确定性自动拆分；
    // 有明细时该组总额 = 子项之和（抓包导入的订单 shopDiscount/platformCoupon 为 0）
    final shopSubs = _discountSubs('shop');
    final platformSubs = _discountSubs('platform');
    final shopTotal =
        shopSubs.isNotEmpty ? _subsSum(shopSubs) : _item.shopDiscount;
    final platformTotal = platformSubs.isNotEmpty
        ? _subsSum(platformSubs)
        : _item.platformCoupon;
    // 共减 = 店铺优惠 + 平台优惠（优先用持久化的共减字段）
    final co = _item.coDiscount > 0
        ? _item.coDiscount
        : (_item.showShopDiscount ? shopTotal : 0) +
            (_item.showPlatformCoupon ? platformTotal : 0);
    return [
      _priceRow('商品总价', '共$totalQty件',
          '¥${productTotal.toStringAsFixed(2)}'),
      // 运费行：可在编辑菜单开启/修改，默认不显示（金额为 0 也不显示）
      if (_item.showShippingFee)
        _priceRow('运费', '', '¥${_item.shippingFee.toStringAsFixed(2)}',
            valueColor: const Color(0xFF1A1A1A)),
      // 对齐真实淘宝：商品总价与进口税同处一个矩阵、之间无分割线
      if (_item.showTax) _taxRow(),
      // v1.9.85：分割线固定在商品总价（矩阵）下方——不随进口税行隐藏而消失
      const Divider(height: 16, color: Color(0xFFf0f0f0)),
      // 店铺优惠/平台优惠：单击展开子项明细，双击编辑（v1.9.93）；
      // v1.9.94：不再要求金额>0——开关打开就显示（0 值也显示），双击可编辑
      if (_item.showShopDiscount)
        _discountGroupRow(
          group: 'shop',
          icon: Icons.storefront,
          label: '店铺优惠',
          sub: _item.shopDiscountLabel,
          total: shopTotal,
          subs: shopSubs,
          expanded: _shopDiscountExpanded,
          onToggle: () => setState(
              () => _shopDiscountExpanded = !_shopDiscountExpanded),
          onEditLabel: () => _pickDiscountLabel('shop'),
        ),
      if (_item.showPlatformCoupon)
        _discountGroupRow(
          group: 'platform',
          icon: Icons.confirmation_number,
          label: '平台优惠',
          sub: _item.platformCouponLabel,
          total: platformTotal,
          subs: platformSubs,
          expanded: _platformCouponExpanded,
          onToggle: () => setState(
              () => _platformCouponExpanded = !_platformCouponExpanded),
          onEditLabel: () => _pickDiscountLabel('platform'),
        ),
      Row(
        children: [
          const Text('实付款',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          if (co > 0) ...[
            const SizedBox(width: 6),
            Text('共减¥${co.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFff5000))),
            const SizedBox(width: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EC),
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('优惠解析',
                      style: TextStyle(
                          fontSize: 10, color: Color(0xFFff5000))),
                  Icon(Icons.chevron_right,
                      size: 12, color: Color(0xFFff5000)),
                ],
              ),
            ),
          ],
          const Spacer(),
          Text('¥',
              style: AppTextStyles.price.copyWith(fontSize: 12)),
          // 实付款：录入多少显示多少（不乘规格数量）
          Text(total.toStringAsFixed(2),
              style: AppTextStyles.price.copyWith(fontSize: 20)),
        ],
      ),
    ];
  }

  Widget _taxRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onDoubleTap: () => _editText('修改进口税内容', _item.taxContent, (v) {
          context.read<CartProvider>().updateOrderItem(_item, taxContent: v);
        }),
        child: Row(
          children: [
            Text('进口税', style: AppTextStyles.small),
            const Spacer(),
            Text(_item.taxContent,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF666666))),
          ],
        ),
      ),
    );
  }

  /// 红色小方块图标（对齐真实淘宝价格明细行左侧图标）
  Widget _discountIcon(IconData icon) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFF2046),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 11),
    );
  }

  Widget _priceRow(String label, String sub, String value,
      {Color? valueColor, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) _discountIcon(icon),
          Text(label, style: AppTextStyles.small),
          if (sub.isNotEmpty)
            Text('  $sub', style: AppTextStyles.minSub),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? const Color(0xFF666666))),
        ],
      ),
    );
  }

  // ============ 优惠明细（v1.9.93：可展开 + 双击编辑） ============
  static double _subsSum(List<Map<String, dynamic>> subs) {
    var s = 0.0;
    for (final e in subs) {
      s += (e['amount'] as num?)?.toDouble() ?? 0;
    }
    return double.parse(s.toStringAsFixed(2));
  }

  /// 优惠子项：抓包/手动编辑的 discountDetails JSON 优先，
  /// 没有时按该组总额 + 订单号哈希确定性自动拆分
  List<Map<String, dynamic>> _discountSubs(String group) {
    final raw = _item.discountDetails.trim();
    if (raw.isNotEmpty) {
      try {
        final list = (jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => e['group'] == group)
            .toList();
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }
    return _autoDiscountSubs(group);
  }

  /// 无抓包明细时的确定性自动拆分（对齐真实淘宝常见子项名）
  List<Map<String, dynamic>> _autoDiscountSubs(String group) {
    final total =
        group == 'shop' ? _item.shopDiscount : _item.platformCoupon;
    if (total <= 0) return const [];
    final rnd = Random('${_item.orderNo}_$group'.hashCode);
    double r2(double v) => double.parse(v.toStringAsFixed(2));
    if (group == 'shop') {
      if (total >= 40) {
        final a = r2(total * (0.35 + rnd.nextDouble() * 0.1));
        return [
          {'group': group, 'name': '官方立减', 'sub': '', 'amount': a},
          {
            'group': group,
            'name': '单品直降',
            'sub': '立减优惠',
            'amount': r2(total - a)
          },
        ];
      }
      return [
        {'group': group, 'name': '店铺优惠', 'sub': '', 'amount': r2(total)}
      ];
    }
    // 平台组：官方限时补贴/淘金币/红包/消费券
    if (total >= 40) {
      final coin = r2((3 + rnd.nextInt(10)).toDouble());
      final hb = r2((1 + rnd.nextInt(4)).toDouble());
      final subsidy = r2(total - coin - hb);
      if (subsidy > 0) {
        return [
          {
            'group': group,
            'name': '官方限时补贴',
            'sub': '秒杀直降',
            'amount': subsidy
          },
          {
            'group': group,
            'name': '淘金币',
            'sub': '已消耗${(coin * 100).round()}',
            'amount': coin
          },
          {'group': group, 'name': '红包', 'sub': '', 'amount': hb},
        ];
      }
    }
    if (total >= 10) {
      final coin = r2((2 + rnd.nextInt(6)).toDouble());
      return [
        {
          'group': group,
          'name': '淘金币',
          'sub': '已消耗${(coin * 100).round()}',
          'amount': coin
        },
        {
          'group': group,
          'name': '消费券',
          'sub': '消费券已抵${r2(total - coin)}元',
          'amount': r2(total - coin)
        },
      ];
    }
    return [
      {
        'group': group,
        'name': '消费券',
        'sub': '消费券已抵${r2(total)}元',
        'amount': r2(total)
      }
    ];
  }

  /// 优惠分组行（店铺优惠/平台优惠）：单击展开/收起子项，双击编辑明细
  Widget _discountGroupRow({
    required String group,
    required IconData icon,
    required String label,
    required String sub,
    required double total,
    required List<Map<String, dynamic>> subs,
    required bool expanded,
    required VoidCallback onToggle,
    VoidCallback? onEditLabel,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            onDoubleTap: () => _editDiscountDetails(group, label),
            child: Row(
              children: [
                _discountIcon(icon),
                Text(label, style: AppTextStyles.small),
                // v1.9.97：优惠标签（超级立减/官方立减等）橙色字体，双击可选择
                if (sub.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onDoubleTap: onEditLabel,
                    child: Text('  $sub',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFFff5000))),
                  ),
                const Spacer(),
                Text('-¥${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFFff5000))),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: const Color(0xFFff5000),
                ),
              ],
            ),
          ),
        ),
        if (expanded && subs.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 21, bottom: 8),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => _editDiscountDetails(group, label),
              child: const Row(
                children: [
                  Text('暂无子项，双击添加',
                      style:
                          TextStyle(fontSize: 12, color: Colors.black26)),
                ],
              ),
            ),
          ),
        if (expanded)
          ...subs.map((s) {
            final name = (s['name'] ?? '').toString();
            final ssub = (s['sub'] ?? '').toString();
            final amount = (s['amount'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(left: 21, bottom: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _editDiscountDetails(group, label),
                child: Row(
                  children: [
                    Text(name,
                        style: AppTextStyles.small
                            .copyWith(color: const Color(0xFF666666))),
                    if (ssub.isNotEmpty)
                      Text('  $ssub', style: AppTextStyles.minSub),
                    const Spacer(),
                    Text('-¥${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF666666))),
                    const Icon(Icons.chevron_right,
                        size: 14, color: Colors.black26),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  /// 编辑优惠明细（双击店铺优惠/平台优惠栏触发）：
  /// 可增删子项、改名称/副文案/金额；保存后该组总额自动 = 子项之和
  /// 多商品订单修改实付价：先选商品（v1.9.97）
  void _pickItemForPriceEdit(CartProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择要修改的商品', style: TextStyle(fontSize: 15)),
        children: _orderItems
            .map((e) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _editNumber('修改实付价（不含运费）', e.price, (v) {
                      provider.updateOrderItem(e, price: v);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${e.title.length > 12 ? '${e.title.substring(0, 12)}…' : e.title}  ¥${e.price.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  /// 优惠标签选择（v1.9.97）：双击店铺优惠/平台优惠右侧橙色标签弹出，
  /// 从常用标签里选，也可自定义或隐藏
  void _pickDiscountLabel(String group) {
    final isShop = group == 'shop';
    final presets = isShop
        ? const ['超级立减', '官方立减', '单品直降', '店铺满减', '会员专享价', '店铺券']
        : const ['满60元可减', '淘金币已抵', '88VIP专享', '跨店满减', '消费券', '红包已抵'];
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(isShop ? '选择店铺优惠标签' : '选择平台优惠标签',
            style: const TextStyle(fontSize: 15)),
        children: [
          ...presets.map((p) => SimpleDialogOption(
                onPressed: () {
                  context.read<CartProvider>().updateOrderItem(
                        _item,
                        shopDiscountLabel: isShop ? p : null,
                        platformCouponLabel: isShop ? null : p,
                      );
                  Navigator.pop(ctx);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(p,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFFff5000))),
                ),
              )),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _editText('自定义标签', '', (v) {
                context.read<CartProvider>().updateOrderItem(
                      _item,
                      shopDiscountLabel: isShop ? v : null,
                      platformCouponLabel: isShop ? null : v,
                    );
              });
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('自定义…', style: TextStyle(fontSize: 13)),
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              context.read<CartProvider>().updateOrderItem(
                    _item,
                    shopDiscountLabel: isShop ? '' : null,
                    platformCouponLabel: isShop ? null : '',
                  );
              Navigator.pop(ctx);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('隐藏标签',
                  style: TextStyle(fontSize: 13, color: Colors.black45)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDiscountDetails(String group, String label) async {
    // 其他组的明细原样保留
    final others = <Map<String, dynamic>>[];
    final raw = _item.discountDetails.trim();
    if (raw.isNotEmpty) {
      try {
        others.addAll((jsonDecode(raw) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => e['group'] != group));
      } catch (_) {}
    }
    final rows = _discountSubs(group)
        .map((e) => <String, TextEditingController>{
              'name':
                  TextEditingController(text: (e['name'] ?? '').toString()),
              'sub':
                  TextEditingController(text: (e['sub'] ?? '').toString()),
              'amount': TextEditingController(
                  text: ((e['amount'] as num?)?.toDouble() ?? 0)
                      .toStringAsFixed(2)),
            })
        .toList();
    if (rows.isEmpty) {
      rows.add({
        'name': TextEditingController(text: '官方立减'),
        'sub': TextEditingController(),
        'amount': TextEditingController(text: '0.00'),
      });
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, setState2) => AlertDialog(
          title: Text('编辑$label明细', style: const TextStyle(fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: rows[i]['name'],
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: '名称',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: rows[i]['sub'],
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: '副文案(可空)',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: rows[i]['amount'],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: '金额',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline,
                                size: 18, color: Colors.black38),
                            onPressed: () =>
                                setState2(() => rows.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState2(() => rows.add({
                            'name': TextEditingController(),
                            'sub': TextEditingController(),
                            'amount':
                                TextEditingController(text: '0.00'),
                          })),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('添加一项',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('保存',
                    style: TextStyle(color: Color(0xFFFF5000)))),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final subs = <Map<String, dynamic>>[];
    for (final r in rows) {
      final name = (r['name'] as TextEditingController).text.trim();
      final sub = (r['sub'] as TextEditingController).text.trim();
      final amount = double.tryParse(
              (r['amount'] as TextEditingController).text.trim()) ??
          0;
      if (name.isEmpty && amount <= 0) continue;
      subs.add({
        'group': group,
        'name': name.isEmpty ? '优惠' : name,
        'sub': sub,
        'amount': double.parse(amount.abs().toStringAsFixed(2)),
      });
    }
    final merged = [...others, ...subs];
    final sum = _subsSum(subs);
    if (!mounted) return;
    context.read<CartProvider>().updateOrderItem(
          _item,
          discountDetails: jsonEncode(merged),
          shopDiscount: group == 'shop' ? sum : null,
          platformCoupon: group == 'platform' ? sum : null,
        );
  }

  // ============ 订单信息（对齐 v3.4 image#13） ============
  Widget _buildOrderInfoCard() {
    final provider = context.read<CartProvider>();
    // 按 image#13 顺序：支付方式 -> 天猫积分 -> 微信/支付宝交易号 -> 创建时间 -> 付款时间 -> 发货时间
    final entries = <Widget>[
      _infoRow(
        label: '支付方式',
        value: _item.paymentMethod,
        onTap: () => _showPaymentPicker(provider),
      ),
      if (_item.showTmallPoints)
        _infoRow(
          label: '天猫积分',
          value: '获得${_item.tmallPoints}点积分',
          onTap: () => _editTmallPoints(provider),
        ),
      _infoRow(
        label: _item.paymentMethod.contains('微信') ? '微信交易号' : '支付宝交易号',
        value: _tradeNo,
        onTap: () => _copy(_tradeNo, '交易号已复制'),
        showCopy: true,
      ),
      _infoRow(
        label: '创建时间',
        value: _displayTime(_item.createTime),
        onTap: () => _editDateTime('修改创建时间', _item.createTime, (v) {
          provider.updateOrderItem(_item, createTime: v);
        }),
      ),
      _infoRow(
        label: '付款时间',
        value: _displayTime(_item.payTime),
        onTap: () => _editDateTime('修改付款时间', _item.payTime, (v) {
          provider.updateOrderItem(_item, payTime: v);
        }),
      ),
      // 发货时间：与其他信息行一致的普通行；显示/隐藏控制在右上角 ⋯ 菜单里
      // v1.9.77 起：shipTime 为空（待发货）时自动隐藏该行（对齐真实淘宝）
      if (_item.showShipTime && _item.shipTime.trim().isNotEmpty)
        _infoRow(
          label: '发货时间',
          value: _displayTime(_item.shipTime),
          onTap: () => _editDateTime('修改发货时间', _item.shipTime, (v) {
            provider.updateOrderItem(_item, shipTime: v);
          }),
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // v1.9.85：恢复折叠——点标题行展开/收起明细（对齐真实淘宝"共N项 ⌄"）
          GestureDetector(
            onTap: () =>
                setState(() => _orderInfoExpanded = !_orderInfoExpanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Text('订单信息',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                Text('  共${entries.length}项',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF999999))),
                Icon(
                    _orderInfoExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF999999),
                    size: 18),
                const Spacer(),
                GestureDetector(
                  onTap: () => _copy(_orderNo, '订单编号已复制'),
                  child: Row(
                    children: [
                      Text(_orderNo,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF666666))),
                      const SizedBox(width: 4),
                      const Icon(Icons.content_copy,
                          color: Color(0xFF999999), size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_orderInfoExpanded) ...[
            const SizedBox(height: 12),
            ...entries,
          ],
        ],
      ),
    );
  }

  /// 生成兜底发货时间：付款/创建时间 + 24 小时，格式与 _fmtTime 输出一致
  String _defaultShipTime() {
    final base = _parseTime(_item.payTime) ??
        _parseTime(_item.createTime) ??
        DateTime.now();
    final t = base.add(const Duration(hours: 24));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  /// 解析 yyyy-MM-dd HH:mm:ss（兼容 / 分隔），失败返回 null
  DateTime? _parseTime(String raw) {
    final m = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})[ T]'
            r'(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?')
        .firstMatch(raw);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    );
  }

  /// 订单状态：9 个固定选项，改动后自动归入对应栏目
  void _showStatusPicker() {
    DialogHelpers.showOptionPicker(
      context,
      title: '修改订单状态',
      options: CartProvider.orderStatusOptions,
      currentValue: _item.statusTitle,
    ).then((v) {
      if (v != null) {
        context.read<CartProvider>().updateOrderStatus(_shop, _item, v);
      }
    });
  }

  /// 倒计时：滚动式选择器（天+小时双滚轮）
  void _editCountdown() {
    DialogHelpers.showCountdownPicker(
      context,
      title: '修改倒计时',
      initial: _item.countDown.isEmpty ? '还剩3天21小时自动确认' : _item.countDown,
    ).then((v) {
      if (v != null && v.isNotEmpty) {
        context.read<CartProvider>().updateOrderItem(_item, countDown: v);
      }
    });
  }

  /// 时间统一显示 yyyy-MM-dd HH:mm:ss 原始格式
  String _displayTime(String raw) {
    return raw;
  }

  Widget _infoRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    bool showCopy = false,
  }) {
    return GestureDetector(
      onDoubleTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.smallSub),
            const SizedBox(width: 12),
            Expanded(
              child: Text(value,
                  style: AppTextStyles.small,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (showCopy) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _copy(value, '$label已复制'),
                child: const Icon(Icons.content_copy,
                    color: Color(0xFF999999), size: 14),
              ),
            ],
            const Icon(Icons.chevron_right,
                color: Color(0xFFcccccc), size: 16),
          ],
        ),
      ),
    );
  }

  // ============ 订单保障（对齐真实淘宝：灰色胶囊行，退货包运费/大促价保/退货宝） ============
  Widget _buildGuaranteeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('订单保障',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const Spacer(),
              Text('凭据：今日下单交易快照', style: AppTextStyles.minSub),
              const Icon(Icons.chevron_right,
                  color: Color(0xFFcccccc), size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _guaranteePill(
                  title: '退货包运费',
                  subtitle: '上门取件可用',
                  subtitleColor: const Color(0xFF999999),
                  badge: '88VIP',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _guaranteePill(
                  title: '大促价保',
                  trailing: '申请价保',
                  subtitle: '至9/7 23:59',
                  subtitleColor: const Color(0xFFff5000),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _guaranteePill(
                  title: '退货宝',
                  subtitle: '服务已生效',
                  subtitleColor: const Color(0xFFff5000),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 保障小胶囊（88VIP 角标 + 标题 + ›，下方一行小字说明）
  Widget _guaranteePill({
    required String title,
    required String subtitle,
    Color subtitleColor = const Color(0xFF999999),
    String? badge,
    String? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (badge != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Color(0xFFFFD89E),
                          fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A))),
              ),
              if (trailing != null)
                Flexible(
                  child: Text(trailing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFff5000))),
                ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF999999), size: 13),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: subtitleColor)),
        ],
      ),
    );
  }

  // ============ 商品推荐（2 列瀑布流，素材池随机 6-8 个，双击图片可替换） ============
  List<SearchResultItem>? _recPicks;
  String? _recSig;

  Widget _buildRecommendCard() {
    // 素材池随机抽取（图+名对应）；素材变化时重抽；池空时回退内置数据
    final pool = context.watch<MaterialPoolProvider>();
    final sig =
        '${pool.entries.length}/${pool.entries.where((e) => e.title.isNotEmpty).length}';
    if (!pool.loading && (_recPicks == null || _recSig != sig)) {
      _recSig = sig;
      _recPicks = pool.recommendGoods(6 + Random().nextInt(3));
    }
    final picks = _recPicks ??
        (([...MockData.guessLikeGoods]..shuffle(Random()))
            .take(6)
            .toList());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('看了又看 · 为你推荐',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
            itemCount: picks.length,
            itemBuilder: (_, i) => _recommendGridCard(picks[i]),
          ),
        ],
      ),
    );
  }

  Widget _recommendGridCard(SearchResultItem g) {
    // 图片支持自定义替换（以商品标题为 key，全局同步，无"自定义"角标）
    final override =
        context.watch<ProductImageProvider>().imageFor(g.title);
    final imageUrl = override ?? g.imageUrl;
    return GestureDetector(
      onDoubleTap: () => pickProductImageFromGallery(context, g.title),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: AppImage(url: imageUrl, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(g.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, height: 1.3, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  Text('¥${g.price}',
                      style: const TextStyle(
                          color: Color(0xFFff5000),
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ 底部栏（v1.9.85 按状态照搬真实淘宝截图，图标用贴图） ============
  // 待发货（多数）：客服/投诉 + 催发货（橙）
  // 待发货（少数）：客服/投诉 + 申请开票 + 催发货 + 修改地址（橙）
  // 已发货/运输中/待确认收货：客服/更多 + 延长收货 + 查看物流 + 确认收货（橙）
  // 交易成功/待评价：客服/更多 + 追加评价 + 查看物流 + 再买一单（橙）
  // 退款/售后：客服/更多 + 加入购物车 + 钱款去向 + 联系商家（橙）
  Widget _buildBottomBar() {
    final category = CartProvider.statusCategory(
        _item.statusTitle.isEmpty ? _shop.orderSubStatus : _item.statusTitle);
    final isSignedPending = category == '待收货';
    final isTradeSuccess = _isWaitRate || category == '已完成';
    final isRefund = category == '退款/售后';
    // 待发货两种框架：多数=仅催发货；约 1/4（按订单号哈希）=申请开票+催发货+修改地址
    final pendingShipFull =
        _orderNo.isNotEmpty && _orderNo.hashCode.abs() % 4 == 0;
    // 左侧图标位：待发货=客服+投诉，其余=客服+更多
    final secondIsMore = !_isPendingShip;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              _bottomAction('assets/images/icons/order_kefu.png', '客服',
                  onTap: _gotoServiceChat),
              _bottomAction(
                  secondIsMore
                      ? 'assets/images/icons/order_gengduo.png'
                      : 'assets/images/icons/order_tousu.png',
                  secondIsMore ? '更多' : '投诉',
                  onTap: secondIsMore ? _showMoreSheet : _gotoComplaint),
              const Spacer(),
              if (_isPendingShip) ...[
                if (pendingShipFull) ...[
                  _outlineBtn('申请开票', onTap: () => _demoToast('申请开票')),
                  const SizedBox(width: 8),
                  _outlineBtn('催发货', onTap: _urgeShip),
                  const SizedBox(width: 8),
                  _primaryBtn('修改地址',
                      color: const Color(0xFFff5000), onTap: _editAddress),
                ] else
                  _primaryBtn('催发货',
                      color: const Color(0xFFff5000), onTap: _urgeShip),
              ] else if (isTradeSuccess) ...[
                _outlineBtn('追加评价', onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RateOrderScreen(shop: _shop, item: _item),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                _outlineBtn('查看物流', onTap: _gotoLogistics),
                const SizedBox(width: 8),
                _primaryBtn('再买一单',
                    color: const Color(0xFFff5000), onTap: () => _reAddToCart(_item)),
              ] else if (isSignedPending) ...[
                _outlineBtn('延长收货', onTap: () => _demoToast('已延长收货时间')),
                const SizedBox(width: 8),
                _outlineBtn('查看物流', onTap: _gotoLogistics),
                const SizedBox(width: 8),
                _primaryBtn('确认收货', color: const Color(0xFFff5000),
                    onTap: () {
                  context.read<CartProvider>().markSigned(_shop, _item);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('已确认收货'),
                    duration: Duration(seconds: 1),
                  ));
                }),
              ] else if (isRefund) ...[
                _outlineBtn('加入购物车', onTap: () => _reAddToCart(_item)),
                const SizedBox(width: 8),
                _outlineBtn('钱款去向', onTap: () => _gotoRefund(_item)),
                const SizedBox(width: 8),
                _primaryBtn('联系商家',
                    color: const Color(0xFFff5000), onTap: _gotoServiceChat),
              ] else if (category == '待付款') ...[
                // v1.9.86：待付款对齐真实淘宝——取消订单 + 立即付款
                _outlineBtn('取消订单', onTap: () => _demoToast('取消订单')),
                const SizedBox(width: 8),
                _primaryBtn('立即付款',
                    color: const Color(0xFFff5000),
                    onTap: () => _demoToast('立即付款')),
              ] else
                _primaryBtn('查看详情',
                    color: const Color(0xFFff5000), onTap: () {}),
            ],
          ),
        ),
      ),
    );
  }

  /// 「催发货」提醒
  void _urgeShip() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('已提醒商家尽快发货'),
      duration: Duration(seconds: 1),
    ));
  }

  /// 平台功能类按钮：演示样式仅提示
  void _demoToast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 1),
    ));
  }

  /// 底部「客服」→ 旺旺聊天页（照搬真实淘宝店铺客服会话）
  void _gotoServiceChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: Conversation(
            avatar: '',
            title: _shop.shopName,
            description: '店铺客服在线',
            createAt: '',
          ),
          accentColor: const Color(0xFFFF5000),
        ),
      ),
    );
  }

  /// 底部「投诉」→ 投诉商家页
  void _gotoComplaint() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComplaintScreen(shop: _shop, item: _item),
      ),
    );
  }

  /// 底部「更多」→ 更多操作弹层
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
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined, size: 22),
              title: const Text('查看物流', style: TextStyle(fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                _gotoLogistics();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  size: 22, color: Color(0xFFff0036)),
              title: const Text('删除订单',
                  style: TextStyle(fontSize: 14, color: Color(0xFFff0036))),
              onTap: () {
                context.read<CartProvider>().removeItem(_item);
                Navigator.of(ctx).pop();
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _gotoLogistics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LogisticsScreen(item: _item, shopName: _shop.shopName),
      ),
    );
  }

  /// 修改地址（底部按钮与地址区双击共用）
  void _editAddress() {
    final provider = context.read<CartProvider>();
    _editText('修改地址（第一行收件人，第二行起地址）',
        '${_item.receiver}\n${_item.address}', (v) {
      final lines = v
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isNotEmpty) {
        provider.updateOrderItem(_item, receiver: lines.first);
      }
      if (lines.length > 1) {
        provider.updateOrderItem(_item, address: lines.sublist(1).join('\n'));
      }
    }, maxLines: 3);
  }

  /// 底栏图标位（v1.9.85：用高清贴图，对齐真实淘宝截图）
  Widget _bottomAction(String asset, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(asset, width: 22, height: 22),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF666666), fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // 底部次按钮：灰底圆角矩形（对齐真实淘宝切图：#F2F2F4 底、圆角约 10、字号 13）
  Widget _outlineBtn(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        constraints: const BoxConstraints(minWidth: 72, minHeight: 30),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(text,
              style: const TextStyle(color: Color(0xFF333333), fontSize: 13)),
        ),
      ),
    );
  }

  // v1.9.97：橙色带框按钮（更换款式，对齐真实淘宝：白底+橙框+橙字）
  Widget _orangeOutlineBtn(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        constraints: const BoxConstraints(minWidth: 72, minHeight: 30),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFff5000)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(text,
              style: const TextStyle(color: Color(0xFFff5000), fontSize: 13)),
        ),
      ),
    );
  }

  // 底部主按钮：橙底白字圆角矩形（对齐真实淘宝切图）
  Widget _primaryBtn(String text, {required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        constraints: const BoxConstraints(minWidth: 80, minHeight: 32),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // ============ 编辑弹窗 ============
  /// 地址展开区的一行（标签灰 + 内容黑）
  Widget _addrInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF999999))),
        ),
        Expanded(
          child: Text(value,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF333333))),
        ),
      ],
    );
  }

  void _editText(String title, String initial, ValueChanged<String> onSave,
      {int maxLines = 1}) {
    DialogHelpers.showTextInput(context,
            title: title, initial: initial, maxLines: maxLines)
        .then((v) {
      if (v != null && v.isNotEmpty) onSave(v);
    });
  }

  void _editDateTime(
      String title, String initial, ValueChanged<String> onSave) {
    DialogHelpers.showDateTimePicker(context, title: title, initial: initial)
        .then((v) {
      if (v != null && v.isNotEmpty) onSave(v);
    });
  }

  void _showOptionPicker({
    required String title,
    required List<String> options,
    required String currentValue,
    required ValueChanged<String> onSave,
  }) {
    DialogHelpers.showOptionPicker(
      context,
      title: title,
      options: options,
      currentValue: currentValue,
    ).then((v) {
      if (v != null) onSave(v);
    });
  }

  void _copy(String text, String tip) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tip), duration: const Duration(seconds: 1)));
  }

  // ============ 支付方式（image#10 二选一） ============
  void _showPaymentPicker(CartProvider provider) {
    const options = ['支付宝支付', '微信支付'];
    DialogHelpers.showOptionPicker(
      context,
      title: '修改支付方式',
      options: options,
      currentValue: _item.paymentMethod,
    ).then((v) {
      if (v == null) return;
      provider.updateOrderItem(_item, paymentMethod: v);
    });
  }

  // ============ 天猫积分编辑 ============
  void _editTmallPoints(CartProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('天猫积分',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('显示', style: TextStyle(fontSize: 14)),
                      Switch(
                        value: _item.showTmallPoints,
                        onChanged: (v) => setState(() {
                          provider.updateOrderItem(
                              _item, showTmallPoints: v);
                        }),
                        activeColor: const Color(0xFFff5000),
                      ),
                    ],
                  ),
                  TextField(
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                        text: _item.tmallPoints.toString()),
                    decoration: const InputDecoration(
                      labelText: '积分数量',
                      hintText: '请输入积分',
                    ),
                    onSubmitted: (s) {
                      final n = int.tryParse(s) ?? _item.tmallPoints;
                      provider.updateOrderItem(_item, tmallPoints: n);
                    },
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFff5000)),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============ 编辑标签（订单保障） ============
  void _editTags() {
    final allTags = [
      '极速退款',
      '7天无理由',
      '退货宝',
      '海外直邮',
      '大促价保',
      '假一赔四',
      '破损包退',
      '15天价保',
      '15天退货',
      '88VIP 退货运费险',
      '88VIP 极速退款',
      '88VIP 7天无理由',
    ];
    final provider = context.read<CartProvider>();
    final selected = Set<String>.from(_item.detailTags);
    DialogHelpers.showMultiOptionPicker(
      context,
      title: '编辑标签（显示/隐藏）',
      options: allTags,
      initiallySelected: selected,
    ).then((result) {
      if (result == null) return;
      provider.updateOrderItem(
        _item,
        detailTags: result.toList()..sort((a, b) {
          final ia = allTags.indexOf(a);
          final ib = allTags.indexOf(b);
          return ia.compareTo(ib);
        }),
      );
    });
  }

  // ============ 右上角编辑菜单 ============
  void _showEditMenu() {
    final provider = context.read<CartProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                        onTap: () => Navigator.of(ctx).pop(),
                        child: const Icon(Icons.close,
                            color: Color(0xFF999999)),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _editTile(Icons.label_outline, '编辑标签（显示/隐藏）', () {
                        _editTags();
                      }),
                      _editTile(Icons.edit_note, '修改 7天无理由 文字', () {
                        _editText('修改 7天无理由 文字', _item.returnText, (v) {
                          provider.updateOrderItem(_item, returnText: v);
                        });
                      }),
                      _editTile(Icons.title, '修改状态标题', () {
                        _showStatusPicker();
                      }),
                      // 倒计时只在待收货类状态可见，其它状态下修改无效（不显示该入口）
                      if (CartProvider.statusCategory(_item.statusTitle) ==
                          '待收货')
                        _editTile(Icons.timelapse, '修改倒计时', () {
                          _editCountdown();
                        }),
                      _editTile(Icons.local_shipping, '修改物流状态', () {
                        _showOptionPicker(
                          title: '修改物流状态',
                          options: [
                            '已揽件 · 预计后天送达',
                            '运输中 · 预计明天送达',
                            '派送中 · 快递员正在派送',
                            '已签收 · 包裹已到达',
                            '已到达代收点',
                            '物流异常 · 请联系快递员',
                          ],
                          currentValue: _item.logistics,
                          onSave: (v) => provider.updateOrderItem(
                              _item, logistics: v),
                        );
                      }),
                      const Divider(height: 1),
                      _editTile(Icons.location_on, '修改地址', () {
                        _editText('修改地址', _item.address, (v) {
                          provider.updateOrderItem(_item, address: v);
                        });
                      }),
                      _editTile(Icons.person, '修改收件人', () {
                        _editText('修改收件人', _item.receiver, (v) {
                          provider.updateOrderItem(_item, receiver: v);
                        });
                      }),
                      _editTile(Icons.access_time, '修改送达文字', () {
                        _editText('修改送达文字', _item.deliveryText, (v) {
                          provider.updateOrderItem(_item, deliveryText: v);
                        });
                      }),
                      _switchTile(Icons.visibility_off, '隐藏"发货时间"行',
                          value: !_item.showShipTime, onChanged: (v) {
                        // 重新显示时若时间为空，自动按付款/创建时间 +24h 兜底
                        if (!v && _item.shipTime.trim().isEmpty) {
                          provider.updateOrderItem(_item,
                              showShipTime: true,
                              shipTime: _defaultShipTime());
                        } else {
                          provider.updateOrderItem(_item, showShipTime: !v);
                        }
                        setSheetState(() {});
                      }),
                      _switchTile(Icons.visibility_off, '隐藏"承诺发货"行',
                          value: !_item.showDeliveryPromise, onChanged: (v) {
                        provider.updateOrderItem(_item, showDeliveryPromise: !v);
                        setSheetState(() {});
                      }),
                      _switchTile(Icons.visibility_off, '隐藏"准时送达"行',
                          value: !_item.showOnTime, onChanged: (v) {
                        provider.updateOrderItem(_item, showOnTime: !v);
                        setSheetState(() {});
                      }),
                      _editTile(Icons.view_agenda_outlined, '准时送达卡片样式', () {
                        const options = [
                          '随机',
                          '单排 · 预计送达',
                          '双排 · 承诺+送货上门',
                        ];
                        DialogHelpers.showOptionPicker(
                          context,
                          title: '准时送达卡片样式',
                          options: options,
                          currentValue: options[_item.onTimeStyle + 1],
                        ).then((v) {
                          if (v == null) return;
                          provider.updateOrderItem(_item,
                              onTimeStyle: options.indexOf(v) - 1);
                        });
                      }),
                      // v1.9.80：「平台加补后/领券后」价格行已从列表卡片删除，
                      // 对应的两个隐藏开关无效，移除避免误导
                      _switchTile(Icons.visibility_off, '隐藏"进口税"行',
                          value: !_item.showTaxInfoLine, onChanged: (v) {
                        provider.updateOrderItem(_item, showTaxInfoLine: !v);
                        setSheetState(() {});
                      }),
                      _editTile(Icons.check_circle, '标记为已签收', () {
                        provider.markSigned(_shop, _item);
                        Navigator.of(ctx).pop();
                      }),
                      const Divider(height: 1),
                      _editTile(Icons.store, '修改店铺名', () {
                        _editText('修改店铺名', _shop.shopName, (v) {
                          provider.updateShop(_shop, shopName: v);
                        });
                      }),
                      _editTile(Icons.short_text, '店铺信息行样式', () {
                        _pickShopLineStyle();
                      }),
                      _editTile(Icons.thumb_up, '修改好评率', () {
                        _editText('修改好评率', _shop.goodRate, (v) {
                          provider.updateShop(_shop, goodRate: v);
                        });
                      }),
                      _editTile(Icons.sentiment_satisfied, '修改客服满意度', () {
                        _editText('修改客服满意度', _shop.csRate, (v) {
                          provider.updateShop(_shop, csRate: v);
                        });
                      }),
                      _editTile(Icons.people, '修改粉丝数', () {
                        _editText('修改粉丝数', _shop.fansCount, (v) {
                          provider.updateShop(_shop, fansCount: v);
                        });
                      }),
                      const Divider(height: 1),
                      _editTile(Icons.payment, '修改支付方式', () {
                        _showPaymentPicker(provider);
                      }),
                      _editTile(Icons.account_balance_wallet, '修改交易号', () {
                        _editText('修改交易号', _tradeNo, (v) {
                          if (_item.paymentMethod.contains('微信')) {
                            provider.updateOrderItem(
                                _item, wechatTradeNo: v);
                          } else {
                            provider.updateOrderItem(
                                _item, alipayTradeNo: v);
                          }
                        });
                      }),
                      const Divider(height: 1),
                      _editTile(Icons.monetization_on, '修改商品总价', () {
                        _editNumber('修改商品总价', _item.productTotal, (v) {
                          provider.updateOrderItem(_item, productTotal: v);
                        });
                      }),
                      // v1.9.96：实付价（商品卡单价行）与实付款（订单总额）分开编辑
                      // v1.9.97：多商品订单先选要改哪个商品（也可直接双击商品卡上的金额）
                      _editTile(Icons.price_check, '修改实付价', () {
                        if (_orderItems.length > 1) {
                          _pickItemForPriceEdit(provider);
                        } else {
                          _editNumber('修改实付价（不含运费）', _item.price, (v) {
                            // 直接写入实付价，provider 不会再用组成项重算覆盖
                            provider.updateOrderItem(_item, price: v);
                          });
                        }
                      }),
                      _editTile(Icons.payments, '修改实付款', () {
                        _editNumber('修改实付款（整单总额，含运费）',
                            _shop.actualTotal > 0
                                ? _shop.actualTotal
                                : _item.price, (v) {
                          // 实付款是订单级字段，直接写店铺 actualTotal；
                          // 之后若再改实付价/优惠等组成项，会按组成项重算覆盖
                          provider.updateShop(_shop, actualTotal: v);
                        });
                      }),
                      // v1.9.98：更换款式按钮默认隐藏，需要时从这里打开
                      _switchTile(Icons.swap_horiz, '显示更换款式',
                          value: _item.showStyleBtn, onChanged: (v) {
                        provider.updateOrderItem(_item, showStyleBtn: v);
                        setSheetState(() {});
                      }),
                      _switchTile(Icons.local_shipping_outlined, '显示运费行',
                          value: _item.showShippingFee, onChanged: (v) {
                        provider.updateOrderItem(_item, showShippingFee: v);
                        setSheetState(() {});
                      }),
                      _editTile(Icons.local_shipping, '修改运费', () {
                        _editNumber('修改运费', _item.shippingFee, (v) {
                          provider.updateOrderItem(_item, shippingFee: v);
                        });
                      }),
                      _switchTile(Icons.visibility_off, '隐藏店铺优惠',
                          value: !_item.showShopDiscount, onChanged: (v) {
                        provider.updateOrderItem(
                            _item, showShopDiscount: !v);
                        setSheetState(() {});
                      }),
                      _editTile(Icons.money_off, '修改店铺优惠', () {
                        _editNumber('修改店铺优惠', _item.shopDiscount, (v) {
                          provider.updateOrderItem(_item, shopDiscount: v);
                        });
                      }),
                      _switchTile(Icons.visibility_off, '隐藏平台优惠',
                          value: !_item.showPlatformCoupon, onChanged: (v) {
                        provider.updateOrderItem(
                            _item, showPlatformCoupon: !v);
                        setSheetState(() {});
                      }),
                      _editTile(Icons.local_offer, '修改平台优惠', () {
                        _editNumber('修改平台优惠', _item.platformCoupon, (v) {
                          provider.updateOrderItem(_item, platformCoupon: v);
                        });
                      }),
                      _editTile(Icons.exposure_minus_1, '修改共减', () {
                        _editNumber('修改共减', _item.coDiscount, (v) {
                          provider.updateOrderItem(_item, coDiscount: v);
                        });
                      }),
                      _editTile(Icons.public, '修改进口税内容', () {
                        _editText('修改进口税内容', _item.taxContent, (v) {
                          provider.updateOrderItem(_item, taxContent: v);
                        });
                      }),
                      _switchTile(Icons.visibility_off, '隐藏进口税',
                          value: !_item.showTax, onChanged: (v) {
                        provider.updateOrderItem(_item, showTax: !v);
                        setSheetState(() {});
                      }),
                      _editTile(Icons.card_giftcard, '修改天猫积分', () {
                        _editTmallPoints(provider);
                      }),
                      // v1.9.87：赠品栏开关——没有赠品数据的订单也能手动调出来
                      _editTile(
                          Icons.redeem,
                          _item.giftCount > 0 ? '隐藏赠品栏' : '显示赠品栏', () {
                        if (_item.giftCount > 0) {
                          provider.updateOrderItem(_item, giftCount: 0);
                        } else {
                          provider.updateOrderItem(_item,
                              giftCount: 1,
                              giftTitle: _item.giftTitle.isEmpty
                                  ? '赠品'
                                  : _item.giftTitle);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('赠品栏已显示：单击改件数，双击换图，长按改名'),
                                  duration: Duration(seconds: 2)));
                        }
                        Navigator.of(ctx).pop();
                      }),
                      const Divider(height: 1),
                      _editTile(Icons.edit, '编辑商品（标题/规格/数量/实付价）', () {
                        _editProductFields(provider);
                      }),
                      ListTile(
                        leading: const Icon(Icons.delete,
                            color: Color(0xFFff0036)),
                        title: const Text('删除',
                            style: TextStyle(color: Color(0xFFff0036))),
                        onTap: () {
                          provider.removeItem(_item);
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _editTile(IconData icon, String label, VoidCallback onTap) {
    // 编辑菜单内的按钮：单击直接修改（入口双击、菜单内单击规则）
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF666666), size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing:
          const Icon(Icons.chevron_right, color: Color(0xFFcccccc), size: 18),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  Widget _switchTile(IconData icon, String label,
      {required bool value, required ValueChanged<bool> onChanged}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF666666), size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFff5000),
      ),
      // 整行可点击切换，修复只有点小开关才有反应的问题
      onTap: () => onChanged(!value),
    );
  }

  void _editNumber(String title, double initial, ValueChanged<double> onSave) {
    final controller = TextEditingController(text: initial.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '请输入金额'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim()) ?? initial;
              if (v >= 0) onSave(v);
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _editProductFields(CartProvider provider) {
    final titleCtrl = TextEditingController(text: _item.title);
    final specCtrl = TextEditingController(text: _item.configuration);
    final qtyCtrl = TextEditingController(text: '${_item.quantity}');
    final priceCtrl =
        TextEditingController(text: _item.price.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑商品'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: '商品标题')),
            TextField(
                controller: specCtrl,
                decoration:
                    const InputDecoration(labelText: '规格（如：蓝莓味80粒+柠檬味80粒）')),
            TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '数量')),
            TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '实付价（不含运费）')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final price =
                  double.tryParse(priceCtrl.text.trim()) ?? _item.price;
              final qty =
                  int.tryParse(qtyCtrl.text.trim()) ?? _item.quantity;
              provider.updateOrderItem(
                _item,
                title: titleCtrl.text.trim(),
                configuration: specCtrl.text.trim(),
                quantity: qty,
                price: price,
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
