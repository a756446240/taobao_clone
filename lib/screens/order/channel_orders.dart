import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/app_image.dart';

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
}

// ============ 确定性随机数据生成 ============

const _imgs = [
  'assets/images/remote/r0038.jpg',
  'assets/images/remote/r0039.jpg',
  'assets/images/remote/r0040.jpg',
  'assets/images/remote/r0041.jpg',
  'assets/images/remote/r0042.jpg',
  'assets/images/remote/r0043.jpg',
  'assets/images/remote/r0047.jpg',
  'assets/images/remote/r0048.jpg',
  'assets/images/remote/r0049.jpg',
  'assets/images/remote/r0050.jpg',
  'assets/images/remote/r0051.jpg',
  'assets/images/remote/r0052.jpg',
  'assets/images/remote/r0053.jpg',
  'assets/images/remote/r0054.jpg',
];

const _shangouShops = [
  ['沪上阿姨·精选', '淄博步行街店'],
  ['蜜雪冰城', '张店美食街店'],
  ['瑞幸咖啡', '淄博王府井店'],
  ['肯德基', '人民路餐厅'],
  ['星巴克', '万象汇店'],
  ['麦当劳', '共青团路餐厅'],
  ['古茗', '淄博银座店'],
  ['华莱士', '联通路店'],
];

const _shangouItems = <(String, double)>[
  ('好大一桶冰蓝海盐冰奶（1L）大桶', 7.1),
  ('珍珠奶茶大杯＋芋圆双拼', 13.5),
  ('美式咖啡双杯套餐', 19.9),
  ('香辣鸡腿堡单人餐', 25.5),
  ('拿铁（大杯）＋可颂', 32.0),
  ('麦辣鸡翅四块＋中薯', 21.5),
  ('杨枝甘露轻盈版（大杯）', 16.0),
  ('脆皮全鸡一只', 29.9),
];

const _shangouStatus = ['已完成', '已完成', '已完成', '待付款', '配送中', '已完成', '退款中', '已完成'];

const _feizhuShops = [
  '飞猪旅行小铺旗舰店',
  '飞猪会员旗舰店',
  '杭州西湖希尔顿酒店旗舰店',
  '上海迪士尼度假区旗舰店',
  '携程机票旗舰店',
  '乌镇旅游官方旗舰店',
];

const _feizhuItems = <(String, double)>[
  ('0.01元抢飞猪春节豪华酒店红包', 0.01),
  ('亲子暑期超值大礼包-含猫超卡亲子', 0.1),
  ('杭州西湖希尔顿酒店豪华房1晚含双早', 688.0),
  ('上海迪士尼乐园双人一日票', 998.0),
  ('北京-三亚往返机票经济舱含税', 1580.0),
  ('乌镇西栅景区门票＋摇橹船票双人', 260.0),
];

const _feizhuStatus = ['交易关闭', '交易成功', '待出行', '待评价', '待付款', '交易成功'];

const _promoTags = ['满128减35', '满60减12', '新客立减5元', ''];

/// 生成闪购订单（确定性，与索引绑定）
List<ChannelOrder> buildShangouOrders() {
  return [
    for (var i = 0; i < _shangouShops.length; i++)
      ChannelOrder(
        id: 'sg_$i',
        kind: 0,
        shopName: _shangouShops[i][0],
        location: _shangouShops[i][1],
        status: _shangouStatus[i],
        itemTitle: _shangouItems[i].$1,
        price: _shangouItems[i].$2,
        image: _imgs[(i * 5 + 2) % _imgs.length],
        promoTag: _promoTags[(i * 3 + 1) % _promoTags.length],
      ),
  ];
}

/// 生成飞猪订单（确定性，与索引绑定）
List<ChannelOrder> buildFeizhuOrders() {
  return [
    for (var i = 0; i < _feizhuShops.length; i++)
      ChannelOrder(
        id: 'fz_$i',
        kind: 1,
        shopName: _feizhuShops[i],
        status: _feizhuStatus[i],
        itemTitle: _feizhuItems[i].$1,
        spec: '×1',
        price: _feizhuItems[i].$2,
        image: _imgs[(i * 7 + 5) % _imgs.length],
      ),
  ];
}

// ============ 卡片 ============

/// 闪购订单卡（对齐真实淘宝闪购频道）
class ShangouOrderCard extends StatelessWidget {
  final ChannelOrder order;
  final VoidCallback onRemove;

  const ShangouOrderCard({
    super.key,
    required this.order,
    required this.onRemove,
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
                _greyBtn('评价', () => _toast(context, '已跳转发表评价（闪购暂不支持晒单）')),
              ],
              const SizedBox(width: 8),
              if (order.status == '待付款')
                _orangeBtn('去支付', () => _toast(context, '已完成支付（模拟）'))
              else if (order.status == '配送中')
                _orangeBtn('查看进度', () => _toast(context, '骑手距您约 1.2km，预计 15 分钟送达'))
              else if (order.status == '退款中')
                _orangeBtn('查看详情', () => _toast(context, '退款审核中，预计 24 小时内原路退回'))
              else
                _orangeBtn('再买一单', () => _toast(context, '已加入购物车（模拟）')),
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

  const FeizhuOrderCard({
    super.key,
    required this.order,
    required this.onRemove,
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
                _orangeBtn('去支付', () => _toast(context, '已完成支付（模拟）'))
              else if (order.status == '待出行')
                _orangeBtn('查看行程', () => _toast(context, '行程单已发送至您的淘宝消息'))
              else if (order.status == '待评价')
                _orangeBtn('评价', () => _toast(context, '已跳转发表评价（飞猪暂不支持晒单）'))
              else
                _orangeBtn('查看详情', () => _toast(context, '订单详情（模拟）')),
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
