import 'dart:math';

import '../models/models.dart';

/// 购物车随机商品生成器（每次启动生成 4-5 个店铺分组，店铺风格相近）
class CartGenerator {
  CartGenerator._();

  static final _rand = Random();

  /// 本地商品图池（r0038 ~ r0054 为真实商品图）
  static const List<String> _localProductImages = [
    'assets/images/remote/r0038.jpg',
    'assets/images/remote/r0039.jpg',
    'assets/images/remote/r0040.jpg',
    'assets/images/remote/r0041.jpg',
    'assets/images/remote/r0042.jpg',
    'assets/images/remote/r0043.jpg',
    'assets/images/remote/r0044.jpg',
    'assets/images/remote/r0045.jpg',
    'assets/images/remote/r0046.jpg',
    'assets/images/remote/r0047.jpg',
    'assets/images/remote/r0048.jpg',
    'assets/images/remote/r0049.jpg',
    'assets/images/remote/r0050.jpg',
    'assets/images/remote/r0051.jpg',
    'assets/images/remote/r0052.jpg',
    'assets/images/remote/r0053.jpg',
    'assets/images/remote/r0054.jpg',
  ];

  /// 主题模板（商品 + 店铺风格相近的归为一组）
  static const List<_ThemeTemplate> _templates = [
    _ThemeTemplate(
      category: '海外保健',
      shopPrefix: ['SAH', 'Swisse', 'Blackmores', 'Centrum'],
      shopSuffix: '海外旗舰店',
      badge: '国际',
      isInternational: true,
      itemTitles: [
        '高活性胶原蛋白粉 1000mg 抗衰逆龄',
        '护肝片 100片 澳洲进口 应酬必备',
        '维生素B族片 60片 全家适用',
        '葡萄籽精华 100粒 抗氧化',
      ],
      specTemplates: ['1盒装', '2盒装', '3盒装'],
      priceRange: [120, 980],
      taxInfo: '进口税·价格已含税',
    ),
    _ThemeTemplate(
      category: '国产食品',
      shopPrefix: ['蒙牛', '伊利', '光明', '君乐宝'],
      shopSuffix: '官方旗舰店',
      badge: '',
      isInternational: false,
      itemTitles: [
        '纯牛奶 250ml*16盒 整箱装 早餐奶',
        '原味酸奶 200g*12盒 助消化',
        '高钙奶 250ml*24盒 中老年补钙',
        '脱脂牛奶 250ml*16盒 健身代餐',
      ],
      specTemplates: ['整箱装', '单盒装', '2箱装'],
      priceRange: [35, 180],
      taxInfo: '',
    ),
    _ThemeTemplate(
      category: '国产保健',
      shopPrefix: ['江中', '同仁堂', '云南白药', '修正'],
      shopSuffix: '官方旗舰店',
      badge: '',
      isInternational: false,
      itemTitles: [
        '健胃消食片 50片 儿童成人 健脾',
        '六味地黄丸 浓缩丸 200丸',
        '感冒灵颗粒 10g*9袋 风寒感冒',
        '板蓝根颗粒 10g*20袋 清热解毒',
      ],
      specTemplates: ['1盒装', '3盒装', '5盒装'],
      priceRange: [12, 128],
      taxInfo: '',
    ),
    _ThemeTemplate(
      category: '清洁日化',
      shopPrefix: ['立白', '蓝月亮', '汰渍', '奥妙'],
      shopSuffix: '官方旗舰店',
      badge: '',
      isInternational: false,
      itemTitles: [
        '大师香氛洗衣液 1kg 持久留香',
        '亮白增艳洗衣粉 3kg 大袋装',
        '柔顺剂 4L 衣物护理 抗静电',
        '强力去污洗衣液 2kg 深层洁净',
      ],
      specTemplates: ['1瓶装', '2瓶装', '整箱装'],
      priceRange: [3, 89],
      taxInfo: '',
    ),
    _ThemeTemplate(
      category: '国际美妆',
      shopPrefix: ['Shiseido', 'Estee Lauder', "Kiehl's", 'Lancome'],
      shopSuffix: '官方旗舰店',
      badge: '国际',
      isInternational: true,
      itemTitles: [
        '新红妍肌活精华露 50ml 修护',
        '小棕瓶眼霜 15ml 抗蓝光',
        '金盏花爽肤水 250ml 舒缓',
        '小黑瓶肌底液 50ml 抗老',
      ],
      specTemplates: ['正装', '赠品装', '礼盒装'],
      priceRange: [320, 1880],
      taxInfo: '进口税·价格已含税',
    ),
  ];

  /// 每次启动随机生成 4-5 个店铺；itemCount 可强制指定每店商品数（1/2/3）
  static List<ShoppingCartShop> generate({int count = 4, int? itemCount}) {
    // 随机打乱模板顺序
    final templates = [..._templates]..shuffle(_rand);
    final picked = templates.take(count).toList();

    return picked.map((t) => _buildShop(t, itemCount: itemCount)).toList();
  }

  static ShoppingCartShop _buildShop(_ThemeTemplate t, {int? itemCount}) {
    final shopName = '${t.shopPrefix[_rand.nextInt(t.shopPrefix.length)]} ${t.shopSuffix}';

    // 每个店铺 1-3 个商品（可强制指定）
    final n = itemCount ?? (1 + _rand.nextInt(2));
    final itemCount2 = n.clamp(1, t.itemTitles.length);
    final titlePool = [...t.itemTitles]..shuffle(_rand);
    final items = <OrderItem>[];
    for (var i = 0; i < itemCount2 && i < titlePool.length; i++) {
      final price = (t.priceRange[0] +
              _rand.nextInt(t.priceRange[1] - t.priceRange[0]))
          .toDouble();
      final originalPrice =
          (price * (1.2 + _rand.nextDouble() * 0.5)).roundToDouble();
      final imageIndex = _rand.nextInt(_localProductImages.length);
      final imageUrl = _localProductImages[imageIndex];
      final today = DateTime.now();
      final shopDiscount = (price * 0.28).roundToDouble();
      final productTotal = price + shopDiscount + 0.27;
      final payTime = _formatTime(today.add(const Duration(minutes: 5)));
      // 订单编号：5127 开头 + 15 位随机数字 = 19 位（与交易号分开）
      final orderNo = '5127${_randTail(15)}';
      // 交易号：付款时间前 8 位（yyyyMMdd）+ 20 位随机数字 = 28 位
      final tradePrefix = _timePrefix8(payTime);
      final alipayNo = '$tradePrefix${_randTail(20)}';
      final wechatNo = '$tradePrefix${_randTail(20)}';
      items.add(OrderItem(
        imageUrl: imageUrl,
        title: titlePool[i],
        configuration: t.specTemplates[_rand.nextInt(t.specTemplates.length)],
        stock: 0,
        price: price,
        originalPrice: originalPrice,
        discountLabels: _randDiscountLabels(price),
        serviceTags: _randServiceTags(),
        taxInfo: t.taxInfo,
        quantity: 1,
        // 订单编辑字段默认值
        statusTitle: '待发货',
        countDown: '还剩2天自动发货',
        logistics: '已揽件 · 预计后天送达',
        createTime: _formatTime(today),
        payTime: payTime,
        shipTime: _formatTime(today.add(const Duration(hours: 4))),
        address: '中房大厦C座1001室\n黑山灰 86-186****5652',
        receiver: '黑山灰',
        isSigned: false,
        returnText: '7天无理由退货',
        deliveryText: '预计后天送达',
        showOnTime: true,
        onTimeText: '准时送达 | 8月26日',
        // 3.4 订单详情字段默认值
        deliveryPromise: '承诺48小时内发货',
        paymentMethod: '支付宝支付',
        orderNo: orderNo,
        alipayTradeNo: alipayNo,
        wechatTradeNo: wechatNo,
        productTotal: productTotal,
        shopDiscount: shopDiscount,
        platformCoupon: 0.27,
        platformCouponLabel: '满60元可减',
        coDiscount: shopDiscount + 0.27,
        taxContent: t.taxInfo.isEmpty ? '价格已含税' : t.taxInfo,
        detailTags: const ['极速退款', '7天无理由'],
        tmallPoints: 10 + _rand.nextInt(90),
        showTmallPoints: true,
        showPlatformPriceRow: true,
        showCouponPriceRow: true,
        showTaxInfoLine: true,
        // 售后卡片退款条：样式与优惠金额随机生成并持久化
        refundBarStyle: _rand.nextInt(4),
        refundDiscount:
            double.parse(((price * 0.04) + _rand.nextDouble() * price * 0.12)
                .toStringAsFixed(2)),
      ));
    }

    return ShoppingCartShop(
      shopName: shopName,
      shopType: t.isInternational ? ShopType.tianMao : ShopType.tianMao,
      hasCoupons: _rand.nextBool(),
      hasTmallEasyBuy: _rand.nextBool(),
      discounts: _rand.nextBool() ? '满${100 + _rand.nextInt(200)}减${20 + _rand.nextInt(50)}' : '',
      isInternational: t.isInternational,
      shopBadge: t.badge,
      items: items,
      orderStatus: '待发货',
      orderSubStatus: '等待发货',
      orderTotalTip: '共${items.length}件商品 合计：',
      // 3.4 店铺信息字段默认值
      shopSubtitle: t.isInternational ? '德国直邮 · 保税仓发货 · 正品保障' : '官方正品 · 极速发货 · 售后无忧',
      goodRate: '${90 + _rand.nextInt(10)}%',
      csRate: '${90 + _rand.nextInt(9)}%',
      fansCount: '${8000 + _rand.nextInt(4000)}',
      shopScore: 4.8 + _rand.nextInt(3) * 0.1,
    );
  }

  /// 随机立减/补贴/官方立减 标签
  static List<String> _randDiscountLabels(double price) {
    final n = 1 + _rand.nextInt(3); // 1-3 个标签
    final pool = <String>[];
    final off1 = (price * 0.1).round();
    final off2 = (price * 0.15).round();
    final off3 = (price * 0.2).round();
    pool.add('官方立减$off1元');
    pool.add('补贴${off2}元');
    pool.add('立减$off3元');
    pool.shuffle(_rand);
    return pool.take(n).toList();
  }

  /// 随机服务标签
  static List<String> _randServiceTags() {
    final pool = ['退货宝', '大促价保', '超级爆款', '7天无理由', '极速退款'];
    pool.shuffle(_rand);
    return pool.take(2 + _rand.nextInt(2)).toList();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 2026-08-26 11:28:56
  static String _formatTime(DateTime t) {
    return '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
  }

  /// "2026-08-26 11:28:56" -> "20260826"（交易号前 8 位）
  static String _timePrefix8(String time) {
    final m = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(time);
    if (m == null) {
      final n = DateTime.now();
      return '${n.year}${_two(n.month)}${_two(n.day)}';
    }
    return '${m.group(1)}${m.group(2)!.padLeft(2, '0')}${m.group(3)!.padLeft(2, '0')}';
  }

  /// n 位随机数字
  static String _randTail([int n = 20]) {
    return List.generate(n, (_) => _rand.nextInt(10).toString()).join();
  }
}

class _ThemeTemplate {
  final String category;
  final List<String> shopPrefix;
  final String shopSuffix;
  final String badge;
  final bool isInternational;
  final List<String> itemTitles;
  final List<String> specTemplates;
  final List<int> priceRange;
  final String taxInfo;

  const _ThemeTemplate({
    required this.category,
    required this.shopPrefix,
    required this.shopSuffix,
    required this.badge,
    required this.isInternational,
    required this.itemTitles,
    required this.specTemplates,
    required this.priceRange,
    required this.taxInfo,
  });
}
