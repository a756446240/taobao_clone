import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/app_image.dart';
import '../product/shop_home_screen.dart';
import 'channel_order_sheets.dart';

/// 闪购(外卖)/飞猪(旅行)频道订单：确定性随机生成 + 卡片渲染
/// 数据按固定种子生成，每次进入一致；删除仅会话内生效
class ChannelOrder {
  final String id;
  final int kind; // 0=闪购 1=飞猪
  final String shopName;
  final String location; // 闪购门店位置（飞猪为空）
  final String status; // 闪购：已完成/待付款/配送中/退款中；飞猪：交易成功/待付款/待出行/待评价/交易关闭
  final String itemTitle;
  final String spec;
  final double price;
  final int quantity;
  final String image; // assets 路径
  final String promoTag; // 闪购促销标签，如「满128减35」

  const ChannelOrder({
    required this.id,
    required this.kind,
    required this.shopName,
    this.location = '',
    required this.status,
    required this.itemTitle,
    this.spec = '默认',
    required this.price,
    this.quantity = 1,
    required this.image,
    this.promoTag = '',
  });

  /// 支付后的状态流转副本（闪购→配送中，飞猪→待出行；仅会话内生效）
  ChannelOrder copyWithStatus(String newStatus) {
    return ChannelOrder(
      id: id,
      kind: kind,
      shopName: shopName,
      location: location,
      status: newStatus,
      itemTitle: itemTitle,
      spec: spec,
      price: price,
      quantity: quantity,
      image: image,
      promoTag: promoTag,
    );
  }
}

// ============ 固定数据（用户提供的外卖/旅行素材图，订单可重复使用同一素材） ============

/// 生成闪购订单（固定列表，素材来自用户提供的外卖图，可重复）
List<ChannelOrder> buildShangouOrders() {
  const auntJenny = 'assets/images/shangou/auntjenny.jpg';
  return const [
    ChannelOrder(
      id: 'sg_0', kind: 0,
      shopName: '沪上阿姨·精选', location: '淄博步行街店',
      status: '已完成',
      itemTitle: '好大一桶冰蓝海盐冰奶（1L）大桶',
      price: 7.1, image: auntJenny, promoTag: '满128减35',
    ),
    ChannelOrder(
      id: 'sg_1', kind: 0,
      shopName: '沪上阿姨·精选', location: '张店美食街店',
      status: '已完成',
      itemTitle: '好大一桶冰蓝海盐冰奶（1L）大桶',
      price: 7.1, image: auntJenny, promoTag: '满60减12',
    ),
    ChannelOrder(
      id: 'sg_2', kind: 0,
      shopName: '杭景元麻辣烫&炸串', location: '万象汇店',
      status: '已完成',
      itemTitle: '东北老式黏糊麻辣烫（单人豪华份）',
      price: 18.8, image: 'assets/images/shangou/malatang.jpg',
      promoTag: '新客立减5元',
    ),
    ChannelOrder(
      id: 'sg_3', kind: 0,
      shopName: '临榆炸鸡腿', location: '人民路店',
      status: '已完成',
      itemTitle: '招牌炸鸡腿3只装 大口吃肉',
      price: 15.9, image: 'assets/images/shangou/chicken.jpg',
    ),
    ChannelOrder(
      id: 'sg_4', kind: 0,
      shopName: '茶百道', location: '淄博银座店',
      status: '已完成',
      itemTitle: '西瓜啵啵（大杯/不含茶）',
      price: 14.0, image: 'assets/images/shangou/chapanda_watermelon.jpg',
    ),
    ChannelOrder(
      id: 'sg_5', kind: 0,
      shopName: '茶百道', location: '联通路店',
      status: '已完成',
      itemTitle: '酸甜青梅（限时特价 清爽解腻）',
      price: 12.0, image: 'assets/images/shangou/chapanda_plum.jpg',
      promoTag: '限时特价',
    ),
    ChannelOrder(
      id: 'sg_6', kind: 0,
      shopName: '肯德基', location: '人民路餐厅',
      status: '配送中',
      itemTitle: '藤椒风味鸡腿堡单人餐（微辣）',
      price: 25.5, image: 'assets/images/shangou/kfc.jpg',
    ),
    ChannelOrder(
      id: 'sg_7', kind: 0,
      shopName: '蒙自源过桥米线', location: '王府井店',
      status: '待付款',
      itemTitle: '番茄肥牛米线＋小酥肉',
      price: 22.9, image: 'assets/images/shangou/mixian.jpg',
    ),
    ChannelOrder(
      id: 'sg_8', kind: 0,
      shopName: '沪上阿姨·精选', location: '淄博王府井店',
      status: '退款中',
      itemTitle: '好大一桶冰蓝海盐冰奶（1L）大桶',
      price: 7.1, image: auntJenny,
    ),
    ChannelOrder(
      id: 'sg_9', kind: 0,
      shopName: '肯德基', location: '共青团路餐厅',
      status: '已完成',
      itemTitle: '藤椒风味鸡腿堡＋冰可乐',
      price: 19.9, image: 'assets/images/shangou/kfc.jpg',
      promoTag: '满60减12',
    ),
  ];
}

/// 生成飞猪订单（固定 2 单，素材来自用户提供的飞猪活动图）
List<ChannelOrder> buildFeizhuOrders() {
  return const [
    ChannelOrder(
      id: 'fz_0', kind: 1,
      shopName: '飞猪旅行小铺旗舰店',
      status: '交易关闭',
      itemTitle: '0.01元抢飞猪春节豪华酒店红包 最高省235元',
      spec: '×1',
      price: 0.01, image: 'assets/images/feizhu/hotel_redpack.jpg',
    ),
    ChannelOrder(
      id: 'fz_1', kind: 1,
      shopName: '飞猪会员旗舰店',
      status: '交易成功',
      itemTitle: '亲子暑期超值大礼包-含猫超卡亲子',
      spec: '×1',
      price: 0.1, image: 'assets/images/feizhu/kids_giftpack.jpg',
    ),
  ];
}

// ============ 卡片 ============

/// 闪购订单卡（对齐真实淘宝闪购频道）
class ShangouOrderCard extends StatelessWidget {
  final ChannelOrder order;
  final VoidCallback onRemove;
  final VoidCallback? onPay; // 去支付：真实状态流转（待付款→配送中）

  const ShangouOrderCard({
    super.key,
    required this.order,
    required this.onRemove,
    this.onPay,
  });

  String get _priceText {
    final p = order.price;
    return p == p.roundToDouble() && p >= 1 ? p.toStringAsFixed(0) : p.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头行：闪购标 + 餐具图标 + 店名 + 门店位置 + 状态
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFff5000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('闪购',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.dinner_dining,
                  size: 16, color: Color(0xFFff5000)),
              const SizedBox(width: 4),
              // 店名行（含箭头）单击 → 店铺首页
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            ShopHomeScreen(shopName: order.shopName)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text('${order.shopName}  ${order.location}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 16, color: Color(0xFF999999)),
                    ],
                  ),
                ),
              ),
              Text(order.status,
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFff5000),
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          // 门店标签行
          Row(
            children: [
              _outlineTag('门店'),
              const SizedBox(width: 6),
              _outlineTag('接受预订'),
            ],
          ),
          const SizedBox(height: 10),
          // 商品行
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(url: order.image, width: 72, height: 72),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.itemTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 6),
                    Text(order.spec,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF999999))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('¥$_priceText',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                    const SizedBox(height: 6),
                    Text('×${order.quantity}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF999999))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 实付款行
          Align(
            alignment: Alignment.centerRight,
            child: Text.rich(
              TextSpan(
                text: '含包装/配送费  实付款 ',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                children: [
                  TextSpan(
                    text: '¥$_priceText',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (order.promoTag.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfff1e8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(order.promoTag,
                      style: const TextStyle(
                          fontSize: 10, color: Color(0xFFff5000))),
                ),
                const SizedBox(width: 8),
              ],
              _greyBtn('删除订单', onRemove),
              if (order.status == '已完成') ...[
                const SizedBox(width: 8),
                _greyBtn('评价', () => showChannelRateSheet(context, order)),
              ],
              const SizedBox(width: 8),
              if (order.status == '待付款')
                _orangeBtn('去支付', () {
                  onPay?.call(); // 状态真实流转到「待收货（配送中）」
                  _toast(context, '支付成功，商家正在备餐');
                })
              else if (order.status == '配送中')
                _orangeBtn('查看进度', () => showDeliveryProgressSheet(context, order))
              else if (order.status == '退款中')
                _orangeBtn('查看详情', () => showChannelOrderDetailSheet(context, order))
              else
                _orangeBtn('再买一单', () {
                  // 真实加入购物车（购物车 Tab 可见，不再是模拟提示）
                  context.read<CartProvider>().addToCart(
                        shopName: order.shopName,
                        title: order.itemTitle,
                        price: order.price,
                        imageUrl: order.image,
                        spec: order.spec,
                        quantity: order.quantity,
                      );
                  _toast(context, '已加入购物车');
                }),
            ],
          ),
        ],
      ),
    );
  }
}

/// 飞猪订单卡（对齐真实淘宝飞猪频道）
class FeizhuOrderCard extends StatelessWidget {
  final ChannelOrder order;
  final VoidCallback onRemove;
  final VoidCallback? onPay; // 去支付：真实状态流转（待付款→待出行）

  const FeizhuOrderCard({
    super.key,
    required this.order,
    required this.onRemove,
    this.onPay,
  });

  String get _priceText {
    final p = order.price;
    return p == p.roundToDouble() && p >= 1 ? p.toStringAsFixed(0) : p.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头行：飞猪黄标 + 店名 + 状态
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFffe100),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('飞猪',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              // 店名行（含箭头）单击 → 店铺首页
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            ShopHomeScreen(shopName: order.shopName)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(order.shopName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 16, color: Color(0xFF999999)),
                    ],
                  ),
                ),
              ),
              Text(order.status,
                  style: TextStyle(
                      fontSize: 13,
                      color: order.status == '交易关闭'
                          ? const Color(0xFF999999)
                          : const Color(0xFFff5000),
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          // 商品行
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(url: order.image, width: 72, height: 72),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(order.itemTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('¥$_priceText',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 6),
                  Text('×${order.quantity}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF999999))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 实付款行
          Align(
            alignment: Alignment.centerRight,
            child: Text.rich(
              TextSpan(
                text: '实付款 ',
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                children: [
                  TextSpan(
                    text: '¥$_priceText',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 按钮行
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _greyBtn('删除订单', onRemove),
              const SizedBox(width: 8),
              if (order.status == '待付款')
                _orangeBtn('去支付', () {
                  onPay?.call(); // 状态真实流转到「待出行」
                  _toast(context, '支付成功，行程已确认');
                })
              else if (order.status == '待出行')
                _orangeBtn('查看行程', () => showTripSheet(context, order))
              else if (order.status == '待评价')
                _orangeBtn('评价', () => showChannelRateSheet(context, order))
              else
                _orangeBtn('查看详情', () => showChannelOrderDetailSheet(context, order)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============ 共用小组件 ============

Widget _outlineTag(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: const Color(0xFFfff1e8),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(text,
        style: const TextStyle(fontSize: 10, color: Color(0xFFff5000))),
  );
}

Widget _greyBtn(String text, VoidCallback onTap) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFf5f5f5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 13, color: Colors.black87)),
    ),
  );
}

Widget _orangeBtn(String text, VoidCallback onTap) {
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFfff1e8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.primary,
              fontWeight: FontWeight.bold)),
    ),
  );
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(milliseconds: 1200),
    ));
}
