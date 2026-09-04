import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/cart_generator.dart';
import '../models/models.dart';

/// 本地持久化：保存订单/资料到 SharedPreferences
/// 退出 App 后再次进入依然保留用户之前的修改
class PersistenceService {
  PersistenceService._();

  static const _kShops = 'persisted_shops_v1';
  static const _kProfile = 'persisted_profile_v1';
  static const _kDeletedTitle = 'persisted_deleted_titles_v1';
  static const _kOrderSort = 'persisted_order_sort_v1';
  static const _kPresetVersion = 'imported_preset_version_v1';
  static const _kDeletedTradeNos = 'persisted_deleted_trade_nos_v1';

  static Future<List<ShoppingCartShop>?> loadShops() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kShops);
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => _shopFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveShops(List<ShoppingCartShop> shops) async {
    final prefs = await SharedPreferences.getInstance();
    final list = shops.map(_shopToJson).toList();
    await prefs.setString(_kShops, jsonEncode(list));
  }

  static Future<Map<String, String>?> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return m.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveProfile({
    required String avatar,
    required String nickname,
    required String level,
    required String slogan,
    required String address,
    String headerBg = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kProfile,
      jsonEncode({
        'avatar': avatar,
        'nickname': nickname,
        'level': level,
        'slogan': slogan,
        'address': address,
        'headerBg': headerBg,
      }),
    );
  }

  static Future<List<String>> loadDeletedTitles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kDeletedTitle) ?? const [];
  }

  static Future<void> saveDeletedTitles(List<String> titles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDeletedTitle, titles);
  }

  /// 已删除订单号黑名单：用户删掉的订单，淘宝同步导入时永久跳过（防止复活）
  static Future<List<String>> loadDeletedTradeNos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kDeletedTradeNos) ?? const [];
  }

  static Future<void> saveDeletedTradeNos(List<String> nos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kDeletedTradeNos, nos);
  }

  static Future<bool> loadOrderSort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOrderSort) ?? true;
  }

  static Future<void> saveOrderSort(bool byCreateTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOrderSort, byCreateTime);
  }

  /// 已导入的预置订单数据版本（用于增量合并，避免重复导入/用户删除后复活）
  static Future<int> loadImportedPresetVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kPresetVersion) ?? 0;
  }

  static Future<void> saveImportedPresetVersion(int version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPresetVersion, version);
  }

  // ============ 序列化 ============

  static Map<String, dynamic> _itemToJson(OrderItem item) {
    return {
      'imageUrl': item.imageUrl,
      'title': item.title,
      'configuration': item.configuration,
      'stock': item.stock,
      'price': item.price,
      'originalPrice': item.originalPrice,
      'discountLabels': item.discountLabels,
      'serviceTags': item.serviceTags,
      'taxInfo': item.taxInfo,
      'quantity': item.quantity,
      'isSelected': item.isSelected,
      'statusTitle': item.statusTitle,
      'countDown': item.countDown,
      'logistics': item.logistics,
      'createTime': item.createTime,
      'payTime': item.payTime,
      'shipTime': item.shipTime,
      'showShipTime': item.showShipTime,
      'address': item.address,
      'receiver': item.receiver,
      'isSigned': item.isSigned,
      'returnText': item.returnText,
      'deliveryText': item.deliveryText,
      'showOnTime': item.showOnTime,
      'onTimeText': item.onTimeText,
      'onTimeStyle': item.onTimeStyle,
      'onTimeText2': item.onTimeText2,
      'deliveryPromise': item.deliveryPromise,
      'showDeliveryPromise': item.showDeliveryPromise,
      'shipPromise': item.shipPromise,
      'paymentMethod': item.paymentMethod,
      'orderNo': item.orderNo,
      'alipayTradeNo': item.alipayTradeNo,
      'wechatTradeNo': item.wechatTradeNo,
      'productTotal': item.productTotal,
      'shopDiscount': item.shopDiscount,
      'showShopDiscount': item.showShopDiscount,
      'platformCoupon': item.platformCoupon,
      'platformCouponLabel': item.platformCouponLabel,
      'showPlatformCoupon': item.showPlatformCoupon,
      'coDiscount': item.coDiscount,
      'shippingFee': item.shippingFee,
      'showShippingFee': item.showShippingFee,
      'taxContent': item.taxContent,
      'showTax': item.showTax,
      'detailTags': item.detailTags,
      'tmallPoints': item.tmallPoints,
      'showTmallPoints': item.showTmallPoints,
      'showPlatformPriceRow': item.showPlatformPriceRow,
      'showCouponPriceRow': item.showCouponPriceRow,
      'showTaxInfoLine': item.showTaxInfoLine,
      'refundStatus': item.refundStatus,
      'refundTitle': item.refundTitle,
      'refundSubtitle': item.refundSubtitle,
      'refundAmount': item.refundAmount,
      'refundMethod': item.refundMethod,
      'refundLogistics': item.refundLogistics,
      'refundApplyTime': item.refundApplyTime,
      'refundDoneTime': item.refundDoneTime,
      'refundBarStyle': item.refundBarStyle,
      'refundDiscount': item.refundDiscount,
      'showRefundDiscount': item.showRefundDiscount,
      'shipCompany': item.shipCompany,
      'waybillNo': item.waybillNo,
      'logisticsTraces': item.logisticsTraces,
      'refundSteps': item.refundSteps,
      'pickupCode': item.pickupCode,
      'pickupGuarantee': item.pickupGuarantee,
      'pickupTimeText': item.pickupTimeText,
      'pickupInsuranceText': item.pickupInsuranceText,
      'showPickupCard': item.showPickupCard,
    };
  }

  static OrderItem _itemFromJson(Map<String, dynamic> j) {
    return OrderItem(
      imageUrl: j['imageUrl'] ?? '',
      title: j['title'] ?? '',
      configuration: j['configuration'] ?? '',
      stock: j['stock'] ?? 0,
      price: (j['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (j['originalPrice'] as num?)?.toDouble(),
      discountLabels:
          (j['discountLabels'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      serviceTags:
          (j['serviceTags'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      taxInfo: j['taxInfo'] ?? '',
      quantity: j['quantity'] ?? 1,
      isSelected: j['isSelected'] ?? true,
      statusTitle: j['statusTitle'] ?? '',
      countDown: j['countDown'] ?? '',
      logistics: j['logistics'] ?? '',
      createTime: j['createTime'] ?? '',
      payTime: j['payTime'] ?? '',
      shipTime: j['shipTime'] ?? '',
      showShipTime: j['showShipTime'] ?? true,
      address: j['address'] ?? '',
      receiver: j['receiver'] ?? '',
      isSigned: j['isSigned'] ?? false,
      returnText: j['returnText'] ?? '7天无理由退货',
      deliveryText: j['deliveryText'] ?? '',
      showOnTime: j['showOnTime'] ?? true,
      onTimeText: j['onTimeText'] ?? '准时送达',
      onTimeStyle: j['onTimeStyle'] ?? -1,
      onTimeText2: j['onTimeText2'] ?? '送货上门',
      deliveryPromise: j['deliveryPromise'] ?? '承诺48小时内发货',
      showDeliveryPromise: j['showDeliveryPromise'] ?? true,
      shipPromise: j['shipPromise'] ?? '',
      paymentMethod: j['paymentMethod'] ?? '支付宝支付',
      orderNo: j['orderNo'] ?? '',
      alipayTradeNo: j['alipayTradeNo'] ?? '',
      wechatTradeNo: j['wechatTradeNo'] ?? '',
      productTotal: (j['productTotal'] as num?)?.toDouble() ?? 0,
      shopDiscount: (j['shopDiscount'] as num?)?.toDouble() ?? 0,
      showShopDiscount: j['showShopDiscount'] ?? true,
      platformCoupon: (j['platformCoupon'] as num?)?.toDouble() ?? 0,
      platformCouponLabel: j['platformCouponLabel'] ?? '满60元可减',
      showPlatformCoupon: j['showPlatformCoupon'] ?? true,
      coDiscount: (j['coDiscount'] as num?)?.toDouble() ?? 0,
      shippingFee: (j['shippingFee'] as num?)?.toDouble() ?? 0,
      showShippingFee: j['showShippingFee'] ?? false,
      taxContent: j['taxContent'] ?? '价格已含税',
      showTax: j['showTax'] ?? true,
      detailTags: (j['detailTags'] as List?)?.map((e) => e.toString()).toList() ??
          const ['极速退款', '7天无理由'],
      tmallPoints: j['tmallPoints'] ?? 0,
      showTmallPoints: j['showTmallPoints'] ?? false,
      showPlatformPriceRow: j['showPlatformPriceRow'] ?? true,
      showCouponPriceRow: j['showCouponPriceRow'] ?? true,
      showTaxInfoLine: j['showTaxInfoLine'] ?? true,
      refundStatus: j['refundStatus'] ?? '退款成功',
      refundTitle: j['refundTitle'] ?? '',
      refundSubtitle: j['refundSubtitle'] ?? '',
      refundAmount: (j['refundAmount'] as num?)?.toDouble() ?? 0,
      refundMethod: j['refundMethod'] ?? '',
      refundLogistics: j['refundLogistics'] ?? '',
      refundApplyTime: j['refundApplyTime'] ?? '',
      refundDoneTime: j['refundDoneTime'] ?? '',
      refundBarStyle: j['refundBarStyle'] ?? -1,
      refundDiscount: (j['refundDiscount'] as num?)?.toDouble() ?? 0,
      showRefundDiscount: j['showRefundDiscount'] ?? true,
      shipCompany: j['shipCompany'] ?? '',
      waybillNo: j['waybillNo'] ?? '',
      logisticsTraces: j['logisticsTraces'] ?? '',
      refundSteps: j['refundSteps'] ?? '',
      pickupCode: j['pickupCode'] ?? '',
      pickupGuarantee: j['pickupGuarantee'] ?? '',
      pickupTimeText: j['pickupTimeText'] ?? '',
      pickupInsuranceText: j['pickupInsuranceText'] ?? '',
      showPickupCard: j['showPickupCard'] ?? true,
    );
  }

  static Map<String, dynamic> _shopToJson(ShoppingCartShop shop) {
    return {
      'shopName': shop.shopName,
      'shopType': shop.shopType.index,
      'hasCoupons': shop.hasCoupons,
      'hasTmallEasyBuy': shop.hasTmallEasyBuy,
      'discounts': shop.discounts,
      'isInternational': shop.isInternational,
      'shopBadge': shop.shopBadge,
      'isSelected': shop.isSelected,
      'orderStatus': shop.orderStatus,
      'orderSubStatus': shop.orderSubStatus,
      'orderTotalTip': shop.orderTotalTip,
      'actualTotal': shop.actualTotal,
      'orderBtnStyle': shop.orderBtnStyle,
      'orderOps': shop.orderOps,
      'shopAvatar': shop.shopAvatar,
      'shopLineStyle': shop.shopLineStyle,
      'shopSubtitle': shop.shopSubtitle,
      'goodRate': shop.goodRate,
      'csRate': shop.csRate,
      'fansCount': shop.fansCount,
      'shopScore': shop.shopScore,
      'items': shop.items.map(_itemToJson).toList(),
    };
  }

  static ShoppingCartShop _shopFromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List?)
            ?.map((e) => _itemFromJson(e as Map<String, dynamic>))
            .toList() ??
        <OrderItem>[];
    return ShoppingCartShop(
      shopName: j['shopName'] ?? '',
      shopType:
          (j['shopType'] == 1) ? ShopType.taoBao : ShopType.tianMao,
      hasCoupons: j['hasCoupons'] ?? false,
      hasTmallEasyBuy: j['hasTmallEasyBuy'] ?? false,
      discounts: j['discounts'] ?? '',
      isInternational: j['isInternational'] ?? false,
      shopBadge: j['shopBadge'] ?? '',
      items: items,
      isSelected: j['isSelected'] ?? true,
      orderStatus: j['orderStatus'] ?? '',
      orderSubStatus: j['orderSubStatus'] ?? '',
      orderTotalTip: j['orderTotalTip'] ?? '',
      actualTotal: (j['actualTotal'] as num?)?.toDouble() ?? 0,
      orderBtnStyle: j['orderBtnStyle'] ?? -1,
      orderOps: j['orderOps'] ?? '',
      shopAvatar: j['shopAvatar'] ?? '',
      shopLineStyle: j['shopLineStyle'] ?? -1,
      shopSubtitle: j['shopSubtitle'] ?? '',
      goodRate: j['goodRate'] ?? '99%',
      csRate: j['csRate'] ?? '96%',
      fansCount: j['fansCount'] ?? '8600',
      shopScore: (j['shopScore'] as num?)?.toDouble() ?? 5.0,
    );
  }

  /// 首次启动时生成默认订单
  static List<ShoppingCartShop> generateDefault() {
    return CartGenerator.generate(count: 4);
  }

  /// 公开的店铺 JSON 解析（供预置订单加载器复用）
  static ShoppingCartShop shopFromJson(Map<String, dynamic> j) =>
      _shopFromJson(j);
}
