/// 数据模型层（全新架构：不可变模型 + 手写 fromJson）
library;

// ============================= 首页 =============================

/// 金刚区入口项
class KingKongItem {
  final String title;
  final String picUrl;
  final String jumpUrl;

  const KingKongItem({
    required this.title,
    required this.picUrl,
    this.jumpUrl = '',
  });

  factory KingKongItem.fromJson(Map<String, dynamic> json) => KingKongItem(
        title: json['title'] ?? '',
        picUrl: json['pic_url'] ?? '',
        jumpUrl: json['jump_url'] ?? '',
      );
}

/// 新品推荐卡片项
class RecommendItem {
  final String title;
  final String subtitle;
  final String picUrl;
  final String bgColor;
  final String titleColor;
  final String subtitleColor;

  const RecommendItem({
    required this.title,
    required this.subtitle,
    required this.picUrl,
    this.bgColor = '#ffffff',
    this.titleColor = '#333333',
    this.subtitleColor = '#fd4f51',
  });

  factory RecommendItem.fromJson(Map<String, dynamic> json) => RecommendItem(
        title: json['title'] ?? '',
        subtitle: json['subtitle'] ?? '',
        picUrl: json['pic_url'] ?? '',
        bgColor: json['bg_color'] ?? '#ffffff',
        titleColor: json['title_color'] ?? '#333333',
        subtitleColor: json['subtitle_color'] ?? '#fd4f51',
      );
}

/// 首页顶部 Tab（猜你喜欢等）
class HomeTab {
  final String title;
  final String subtitle;

  const HomeTab({required this.title, this.subtitle = ''});
}

/// 首页新版图标入口（圆形彩色徽标 + 文字，离线绘制）
class HomeIconEntry {
  final String title; // 图标下方文字
  final String badge; // 圆形徽标内文字（1-2 字）
  final int color; // 徽标主色 0xFFRRGGBB

  const HomeIconEntry(this.title, this.badge, this.color);
}

/// 首页"淘宝直播/百亿补贴"四卡栏目
class HomeLiveCard {
  final String title;
  final int titleColor;
  final String imageUrl; // 本地 asset 路径
  final String priceText;
  final int priceColor;

  const HomeLiveCard({
    required this.title,
    required this.titleColor,
    required this.imageUrl,
    required this.priceText,
    required this.priceColor,
  });
}

// ============================= 搜索 =============================

/// 搜索结果项
class SearchResultItem {
  final String imageUrl;
  final String title;
  final String shopName;
  final String price;
  final String commentCount;
  final String goodRate;
  final String coupon;
  final String discount;

  const SearchResultItem({
    required this.imageUrl,
    required this.title,
    required this.shopName,
    required this.price,
    this.commentCount = '',
    this.goodRate = '',
    this.coupon = '',
    this.discount = '',
  });
}

// ============================= 购物车 =============================

enum ShopType { tianMao, taoBao }

/// 购物车商品（订单项）
class OrderItem {
  String imageUrl;
  String title;
  String configuration;
  final int stock;
  double price;
  double? originalPrice; // 划线价（平台加补前）
  final List<String> discountLabels; // 立减/补贴/官方立减 标签
  final List<String> serviceTags; // 退货宝/大促价保/超级爆款
  final String taxInfo; // "进口税·价格已含税"
  int quantity;
  bool isSelected;

  // ===== 订单编辑字段（3.4 待发货/待收货可修改）=====
  String statusTitle; // 状态标题，如"运输中""已发货"
  String countDown; // 倒计时文字，如"还剩2天自动确认"
  String logistics; // 物流状态，如"已揽件·预计后天送达"
  String createTime; // 创建时间
  String payTime; // 付款时间
  String shipTime; // 发货时间
  String address; // 地址
  String receiver; // 收件人
  bool isSigned; // 是否已签收
  String returnText; // 7天无理由/15天退货 文字
  String deliveryText; // 签收/派送文字
  bool showOnTime; // 是否显示"准时送达"行
  String onTimeText; // 准时送达文字

  // ===== 3.4 订单详情页字段 =====
  String deliveryPromise; // 待发货承诺文案，如"承诺48小时内发货"（显示在地址下方）
  bool showDeliveryPromise; // 是否显示"承诺发货"行
  String paymentMethod; // 支付方式
  String orderNo; // 订单编号（订单信息行）：5127 开头 19 位
  String alipayTradeNo; // 支付宝交易号：付款时间前8位 + 20位随机 = 28 位
  String wechatTradeNo; // 微信交易号：付款时间前8位 + 20位随机 = 28 位
  double productTotal; // 商品总价（明细）
  double shopDiscount; // 店铺优惠金额
  bool showShopDiscount; // 是否显示店铺优惠
  double platformCoupon; // 平台优惠券金额
  String platformCouponLabel; // 平台优惠券门槛文案
  bool showPlatformCoupon; // 是否显示平台优惠券
  double coDiscount; // 共减金额
  double shippingFee; // 运费金额（默认 0）
  bool showShippingFee; // 是否显示运费行（默认 false）
  String taxContent; // 进口税内容
  bool showTax; // 是否显示进口税
  List<String> detailTags; // 详情页红色标签（极速退款/7天无理由等）

  // 列表页价格行显示/隐藏（image#2 红框区域）
  bool showPlatformPriceRow; // 平台加补后
  bool showCouponPriceRow; // 领消费券后约
  bool showTaxInfoLine; // 进口税·价格已含税

  // ===== 天猫积分 =====
  int tmallPoints; // 天猫积分数
  bool showTmallPoints; // 是否展示天猫积分

  // ===== 退款/售后字段（3.4 退款详情页） =====
  String refundStatus; // 退款状态：待商家退款/退款成功/退款结束
  String refundTitle; // 退款大标题
  String refundSubtitle; // 退款副标题（空=自动生成）
  double refundAmount; // 退款金额（<=0 时自动取实付价）
  String refundMethod; // 退款方式：支付宝/银行卡/微信支付
  String refundLogistics; // 退款物流（空=不显示物流卡）
  String refundApplyTime; // 申请时间
  String refundDoneTime; // 完成时间
  int refundBarStyle; // 售后卡片退款条样式：0极速退款/1退款金额/2支付渠道/3平台支持退款（-1=待随机生成）
  double refundDiscount; // 退款优惠金额（随机生成，0=无）
  bool showRefundDiscount; // 是否在退款条显示优惠

  OrderItem({
    required this.imageUrl,
    required this.title,
    required this.configuration,
    required this.stock,
    required this.price,
    this.originalPrice,
    this.discountLabels = const [],
    this.serviceTags = const [],
    this.taxInfo = '',
    this.quantity = 1,
    this.isSelected = true,
    this.statusTitle = '',
    this.countDown = '',
    this.logistics = '',
    this.createTime = '',
    this.payTime = '',
    this.shipTime = '',
    this.address = '',
    this.receiver = '',
    this.isSigned = false,
    this.returnText = '7天无理由退货',
    this.deliveryText = '',
    this.showOnTime = true,
    this.onTimeText = '准时送达',
    this.deliveryPromise = '承诺48小时内发货',
    this.showDeliveryPromise = true,
    this.paymentMethod = '支付宝支付',
    this.orderNo = '',
    this.alipayTradeNo = '',
    this.wechatTradeNo = '',
    this.productTotal = 0,
    this.shopDiscount = 0,
    this.showShopDiscount = true,
    this.platformCoupon = 0,
    this.platformCouponLabel = '满60元可减',
    this.showPlatformCoupon = true,
    this.coDiscount = 0,
    this.shippingFee = 0,
    this.showShippingFee = false,
    this.taxContent = '价格已含税',
    this.showTax = true,
    this.detailTags = const ['极速退款', '7天无理由'],
    this.tmallPoints = 35,
    this.showTmallPoints = false,
    this.showPlatformPriceRow = true,
    this.showCouponPriceRow = true,
    this.showTaxInfoLine = true,
    this.refundStatus = '退款成功',
    this.refundTitle = '',
    this.refundSubtitle = '',
    this.refundAmount = 0,
    this.refundMethod = '',
    this.refundLogistics = '',
    this.refundApplyTime = '',
    this.refundDoneTime = '',
    this.refundBarStyle = -1,
    this.refundDiscount = 0,
    this.showRefundDiscount = true,
  });
}

/// 购物车/订单 店铺分组
class ShoppingCartShop {
  String shopName;
  final ShopType shopType;
  final bool hasCoupons;
  final bool hasTmallEasyBuy;
  final String discounts;
  bool isInternational; // 是否国际/海外店
  String shopBadge; // 店铺角标（"国际"/"淘工厂"/"淘宝" 等）
  final List<OrderItem> items;
  bool isSelected;

  // ===== 订单状态字段 =====
  String orderStatus; // 订单状态标签，如"待发货""已发货"
  String orderSubStatus; // 店铺名右侧状态，如"待付款""已发货"
  String orderTotalTip; // 店铺合计提示，如"共1件商品 合计："

  // ===== 3.4 店铺信息字段 =====
  String shopSubtitle; // 店铺副标题，如"德国直邮 · 保税仓发货 · 正品保障"
  String goodRate; // 好评率
  String csRate; // 客服满意度
  String fansCount; // 粉丝数
  double shopScore; // 店铺评分

  ShoppingCartShop({
    required this.shopName,
    required this.shopType,
    this.hasCoupons = false,
    this.hasTmallEasyBuy = false,
    this.discounts = '',
    this.isInternational = false,
    this.shopBadge = '',
    required this.items,
    this.isSelected = true,
    this.orderStatus = '',
    this.orderSubStatus = '',
    this.orderTotalTip = '',
    this.shopSubtitle = '',
    this.goodRate = '99%',
    this.csRate = '96%',
    this.fansCount = '8600',
    this.shopScore = 5.0,
  });
}

// ============================= 消息 =============================

/// 消息会话
class Conversation {
  final String avatar;
  final String title;
  final String description;
  final String createAt;
  final String type;
  final int titleColor;
  final int unReadCount;
  final bool isMute;
  final bool isNetwork;

  const Conversation({
    required this.avatar,
    required this.title,
    required this.description,
    required this.createAt,
    this.type = '',
    this.titleColor = 0xff000000,
    this.unReadCount = 0,
    this.isMute = false,
    this.isNetwork = false,
  });
}

/// 聊天消息
class ChatMessage {
  final String content;
  final bool isMe;
  final String time;

  const ChatMessage({
    required this.content,
    required this.isMe,
    this.time = '',
  });
}

// ============================= 微淘 =============================

/// 微淘帖子
class PostModel {
  final String name;
  final String avatar;
  final String address;
  final String message;
  final List<String> photos;
  final int readCount;
  final int likesCount;
  final int commentsCount;
  final String postTime;
  final bool isLike;

  const PostModel({
    required this.name,
    required this.avatar,
    this.address = '',
    required this.message,
    this.photos = const [],
    this.readCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.postTime = '',
    this.isLike = false,
  });
}
