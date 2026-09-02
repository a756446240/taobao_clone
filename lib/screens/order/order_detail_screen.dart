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

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _shop = widget.shop;
  }

  bool get _isPendingShip => _item.statusTitle.contains('待发货');

  /// 订单编号（订单信息行）：5127 开头 19 位
  String get _orderNo => _item.orderNo;

  /// 交易号：按支付方式取 支付宝/微信 交易号（28 位）
  String get _tradeNo => context.read<CartProvider>().tradeNoFor(_item);

  @override
  Widget build(BuildContext context) {
    context.watch<CartProvider>();
    context.watch<ProductImageProvider>();

    final title = _item.statusTitle.isEmpty ? '订单详情' : _item.statusTitle;
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
                    _greyBar(),
                    _buildShopCard(),
                    _greyBar(),
                    // 商品与价格明细合并在同一栏目（中间无空白分隔框）
                    _buildProductCard(),
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
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
          // 物流状态行（双击换选项）
          GestureDetector(
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
                        text: _item.logistics.isEmpty
                            ? '您的快件已领取，收件人在[代收点](...)'
                            : _item.logistics,
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
          // 地址区（双击手动输入：第一行收件人，其余地址）
          const SizedBox(height: 14),
          GestureDetector(
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
                      ? '中房房大厦C座1001'
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
                  ],
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
          // 准时送达行（可编辑文字，可隐藏）
          if (_item.showOnTime) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onDoubleTap: () => _editText('修改准时送达文字', _item.onTimeText, (v) {
                provider.updateOrderItem(_item, onTimeText: v);
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt,
                        color: Color(0xFF2A9655), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _item.onTimeText.isEmpty
                            ? '准时送达 | 8月26日为您准时送达'
                            : _item.onTimeText,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF333333)),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 14, color: Color(0xFF999999)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 根据物流文字推断阶段标签和图标
  (String, IconData) _logisticsStage() {
    final l = _item.logistics;
    final t = _item.statusTitle;
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
    if (l.contains('运输') ||
        t.contains('发货') ||
        t.contains('收货') ||
        t.contains('签收')) {
      return ('运输中', Icons.local_shipping_outlined);
    }
    return ('等待发货', Icons.access_time);
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
                  width: 36,
                  height: 36,
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
                                style: AppTextStyles.smallBold),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Color(0xFF999999), size: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onDoubleTap: () => _editText('修改店铺副标题', _shop.shopSubtitle, (v) {
                        context.read<CartProvider>().updateShop(_shop, shopSubtitle: v);
                      }),
                      child: Text(
                        _shop.shopSubtitle.isEmpty
                            ? '德国直邮 · 保税仓发货 · 正品保障'
                            : _shop.shopSubtitle,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF999999)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFff5000)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('进店逛逛',
                    style: TextStyle(
                        color: Color(0xFFff5000),
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _rateText('好评率', _shop.goodRate),
              const SizedBox(width: 10),
              _rateText('客服满意度', _shop.csRate),
              const SizedBox(width: 10),
              _rateText('粉丝', _shop.fansCount),
              const Spacer(),
              const Icon(Icons.star, color: Color(0xFFFFB300), size: 14),
              Text(_shop.shopScore.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Color(0xFFff5000),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  /// 商家头像显示：优先相册替换图（以店铺名为 key 持久化）
  Widget _shopAvatar() {
    final override =
        context.watch<ProductImageProvider>().imageFor('shop_avatar:${_shop.shopName}');
    if (override != null) {
      return AppImage(url: override, width: 36, height: 36);
    }
    return const Icon(Icons.favorite, color: Colors.white, size: 18);
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
      final saved = await File(picked.path).copy('${saveDir.path}/$fileName');
      if (!mounted) return;
      await context
          .read<ProductImageProvider>()
          .setOverride('shop_avatar:${_shop.shopName}', saved.path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商家头像已替换'), duration: Duration(seconds: 1)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片选择失败')),
      );
    }
  }

  Widget _rateText(String label, String value) {
    return GestureDetector(
      onDoubleTap: () {
        if (label == '好评率') {
          _editText('修改好评率', _shop.goodRate, (v) {
            context.read<CartProvider>().updateShop(_shop, goodRate: v);
          });
        } else if (label == '客服满意度') {
          _editText('修改客服满意度', _shop.csRate, (v) {
            context.read<CartProvider>().updateShop(_shop, csRate: v);
          });
        } else {
          _editText('修改粉丝数', _shop.fansCount, (v) {
            context.read<CartProvider>().updateShop(_shop, fansCount: v);
          });
        }
      },
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: '$label ',
            style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
        TextSpan(
            text: value,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFff5000),
                fontWeight: FontWeight.bold)),
      ])),
    );
  }

  // ============ 商品卡片 ============
  Widget _buildProductCard() {
    final override = context.watch<ProductImageProvider>().imageFor(_item.title);
    final imageUrl = override ?? _item.imageUrl;

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
                onDoubleTap: () => _pickProductImage(),
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
                    GestureDetector(
                      onDoubleTap: () => _editText('修改商品标题', _item.title, (v) {
                        context.read<CartProvider>().updateOrderItem(_item, title: v);
                      }),
                      child: Text(_item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.small),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onDoubleTap: () => _editText('修改规格', _item.configuration, (v) {
                        context.read<CartProvider>().updateOrderItem(_item, configuration: v);
                      }),
                      child: Text(_item.configuration,
                          style: AppTextStyles.minSub),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: _item.detailTags.map(_redTag).toList(),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('实付价 ',
                            style: AppTextStyles.minSub),
                        Text('¥',
                            style: AppTextStyles.price
                                .copyWith(fontSize: 12)),
                        Text(_item.price.toStringAsFixed(2),
                            style: AppTextStyles.price
                                .copyWith(fontSize: 18)),
                        const Spacer(),
                        Text('x${_item.quantity}',
                            style: AppTextStyles.minSub),
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
              _outlineBtn('加入购物车', onTap: _reAddToCart),
              const SizedBox(width: 8),
              _orangeOutlineBtn('申请售后', onTap: _gotoRefund),
            ],
          ),
          // 价格明细与上方商品处于同一栏目（无空白虚框分隔）
          const Divider(height: 24, color: Color(0xFFf0f0f0)),
          ..._priceSectionChildren(),
        ],
      ),
    );
  }

  Future<void> _pickProductImage() async {
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
      final saved = await File(picked.path).copy('${saveDir.path}/$fileName');
      if (!mounted) return;
      await context
          .read<ProductImageProvider>()
          .setOverride(_item.title, saved.path);
      if (!mounted) return;
      context.read<CartProvider>().updateOrderItem(_item, imageUrl: saved.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品图已替换'), duration: Duration(seconds: 1)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片选择失败')),
      );
    }
  }

  /// 把该订单商品重新加回购物车（再次购买）
  void _reAddToCart() {
    context.read<CartProvider>().addToCart(
          shopName: _shop.shopName,
          title: _item.title,
          price: _item.price,
          imageUrl: _item.imageUrl,
          spec: _item.configuration,
          quantity: _item.quantity,
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
  void _gotoRefund() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RefundDetailScreen(shop: _shop, item: _item),
      ),
    );
  }

  Widget _redTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFff5000)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFFff5000), fontSize: 10)),
    );
  }

  // ============ 价格明细（与商品卡同一栏目） ============
  List<Widget> _priceSectionChildren() {
    final productTotal = _item.productTotal > 0
        ? _item.productTotal
        : _item.price + _item.shopDiscount + _item.platformCoupon;
    final total = _item.price;
    // 共减 = 店铺优惠 + 平台优惠（优先用持久化的共减字段）
    final co = _item.coDiscount > 0
        ? _item.coDiscount
        : (_item.showShopDiscount ? _item.shopDiscount : 0) +
            (_item.showPlatformCoupon ? _item.platformCoupon : 0);
    return [
      _priceRow('商品总价', '共${_item.quantity}件',
          '¥${productTotal.toStringAsFixed(2)}'),
      // 运费行：可在编辑菜单开启/修改，默认不显示（金额为 0 也不显示）
      if (_item.showShippingFee)
        _priceRow('运费', '', '¥${_item.shippingFee.toStringAsFixed(2)}',
            valueColor: const Color(0xFF1A1A1A)),
      // 分割线：商品总价/运费下方、进口税上方
      const Divider(height: 16, color: Color(0xFFf0f0f0)),
      if (_item.showTax) _taxRow(),
      if (_item.showShopDiscount)
        _priceRow('店铺优惠', '', '-¥${_item.shopDiscount.toStringAsFixed(2)}',
            valueColor: const Color(0xFFff5000),
            icon: Icons.storefront),
      if (_item.showPlatformCoupon)
        _priceRow('平台优惠券', _item.platformCouponLabel,
            '-¥${_item.platformCoupon.toStringAsFixed(2)}',
            valueColor: const Color(0xFFff5000),
            icon: Icons.confirmation_number),
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
      if (_item.showShipTime)
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
          Row(
            children: [
              const Text('订单信息',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              Text('  共${entries.length}项',
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF999999))),
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
              const Icon(Icons.chevron_right,
                  color: Color(0xFFcccccc), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          ...entries,
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
      if (!mounted) return;
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
      if (!mounted) return;
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

  // ============ 底部栏 ============
  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _bottomAction(Icons.headset_mic_outlined, '客服'),
          _bottomAction(Icons.report_problem_outlined, '投诉'),
          const Spacer(),
          if (_isPendingShip) ...[
            _primaryBtn('催发货', color: const Color(0xFFff5000)),
            const SizedBox(width: 8),
            _primaryBtn('修改地址', color: const Color(0xFFff0036)),
          ] else
            Expanded(
              child: _primaryBtn('查看详情', color: const Color(0xFFff5000)),
            ),
        ],
      ),
    );
  }

  Widget _bottomAction(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF666666), size: 22),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 10)),
        ],
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
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style: const TextStyle(color: Colors.black87, fontSize: 12)),
      ),
    );
  }

  Widget _orangeOutlineBtn(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFff5000)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text,
            style: const TextStyle(color: Color(0xFFff5000), fontSize: 12)),
      ),
    );
  }

  Widget _primaryBtn(String text, {required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: color,
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

  // ============ 编辑弹窗 ============
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
                      _switchTile(Icons.visibility_off, '隐藏"平台加补后"价',
                          value: !_item.showPlatformPriceRow, onChanged: (v) {
                        provider.updateOrderItem(_item, showPlatformPriceRow: !v);
                        setSheetState(() {});
                      }),
                      _switchTile(Icons.visibility_off, '隐藏"领券后"价',
                          value: !_item.showCouponPriceRow, onChanged: (v) {
                        provider.updateOrderItem(_item, showCouponPriceRow: !v);
                        setSheetState(() {});
                      }),
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
                      _editTile(Icons.short_text, '修改店铺副标题', () {
                        _editText('修改店铺副标题', _shop.shopSubtitle, (v) {
                          provider.updateShop(_shop, shopSubtitle: v);
                        });
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
                      _editTile(Icons.price_check, '修改实付款', () {
                        _editNumber('修改实付款', _item.price, (v) {
                          // 直接写入实付价，provider 不会再用组成项重算覆盖
                          provider.updateOrderItem(_item, price: v);
                        });
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
                      const Divider(height: 1),
                      _editTile(Icons.edit, '编辑商品', () {
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
                decoration: const InputDecoration(labelText: '规格')),
            TextField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '实付价')),
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
              provider.updateOrderItem(
                _item,
                title: titleCtrl.text.trim(),
                configuration: specCtrl.text.trim(),
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
