import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/cart_generator.dart';
import '../data/preset_orders.dart';
import '../models/models.dart';
import 'persistence_service.dart';

/// 购物车状态管理（Provider）
/// 修改订单后自动写入 SharedPreferences，重启 App 保留
class CartProvider extends ChangeNotifier {
  CartProvider() {
    _shops = PersistenceService.generateDefault();
    _restoreFromDisk();
  }

  // ============ 订单状态固定 9 选项 ============
  static const List<String> orderStatusOptions = [
    '已发货',
    '已经签收',
    '待确认收货',
    '仓库已发货',
    '交易关闭',
    '交易成功',
    '退款成功',
    '待商家退款',
    '待发货',
  ];

  /// 状态 → 栏目归类（待发货 / 待收货 / 退款/售后 / 已完成）
  static String statusCategory(String status) {
    if (status.contains('待发货') || status.contains('等待发货')) return '待发货';
    if (status.contains('发货') ||
        status.contains('签收') ||
        status.contains('收货') ||
        status.contains('运输中') ||
        status.contains('派送中')) {
      return '待收货';
    }
    if (status.contains('退款') || status.contains('售后')) return '退款/售后';
    if (status.contains('待付款') || status.contains('等待付款')) return '待付款';
    return '已完成';
  }

  List<ShoppingCartShop> _shops = [];
  bool _loading = true;

  /// 读取本地持久化的订单；有则覆盖默认生成
  Future<void> _restoreFromDisk() async {
    try {
      final saved = await PersistenceService.loadShops();
      if (saved != null && saved.isNotEmpty) {
        _shops = saved;
        _migrateTradeNos();
        _migrateRefundBar();
      } else {
        // 本地无数据时，优先加载打包内置的预置订单
        final preset = await PresetOrders.loadWithVersion();
        if (preset != null) {
          _shops = preset.shops;
          _migrateTradeNos();
          _migrateRefundBar();
          await PersistenceService.saveShops(_shops);
          await PersistenceService.saveImportedPresetVersion(preset.version);
        }
      }
      // 老用户增量合并：预置数据版本更新时，只追加本地不存在的新订单
      await _mergeNewPresetOrders();
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  /// 增量导入预置订单：
  /// 预置 JSON 版本号高于已导入版本时，把本地没有的订单（按订单号去重）追加进来。
  /// 用户手动删除过的订单不会复活（版本号只导入一次）。
  Future<void> _mergeNewPresetOrders() async {
    final preset = await PresetOrders.loadWithVersion();
    if (preset == null) return;
    final imported =
        await PersistenceService.loadImportedPresetVersion();
    if (preset.version <= imported) return;
    final existingNos = <String>{
      for (final shop in _shops)
        for (final item in shop.items) item.orderNo,
    };
    var added = 0;
    for (final shop in preset.shops) {
      final newItems = shop.items
          .where((it) => it.orderNo.isEmpty || !existingNos.contains(it.orderNo))
          .toList();
      if (newItems.isEmpty) continue;
      shop.items
        ..clear()
        ..addAll(newItems);
      _shops.add(shop);
      added += newItems.length;
    }
    if (added > 0) {
      _migrateTradeNos();
      _migrateRefundBar();
      _persist();
    }
    await PersistenceService.saveImportedPresetVersion(preset.version);
  }

  bool get loading => _loading;

  /// 订单始终按创建时间自动排序（不可关闭）：时间靠后的订单自动排在上方
  List<ShoppingCartShop> get shops {
    // 按每单最早创建时间降序（最新创建的订单排在最上面）
    final sorted = [..._shops]..sort((a, b) {
      final ta = _earliestCreateTime(a);
      final tb = _earliestCreateTime(b);
      return tb.compareTo(ta);
    });
    return sorted;
  }

  String _earliestCreateTime(ShoppingCartShop shop) {
    if (shop.items.isEmpty) return '0000';
    DateTime? min;
    for (final item in shop.items) {
      final t = _parseCreateTime(item.createTime);
      if (t != null && (min == null || t.isBefore(min))) {
        min = t;
      }
    }
    if (min == null) return '0000';
    return min.toIso8601String();
  }

  /// 解析形如 "2026-08-26 11:28:56" / "2026-08-26 11:28" / "8月30日 9:59" 的时间
  DateTime? _parseCreateTime(String s) {
    if (s.isEmpty) return null;
    try {
      // 2026-08-26 11:28:56 / 2026/08/26 11:28
      final normalized = s.replaceAll('/', '-').trim();
      if (normalized.contains('-')) {
        final m = RegExp(
                r'(\d{4})-(\d{1,2})-(\d{1,2})(?:\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?')
            .firstMatch(normalized);
        if (m != null) {
          return DateTime(
            int.parse(m.group(1)!),
            int.parse(m.group(2)!),
            int.parse(m.group(3)!),
            m.group(4) != null ? int.parse(m.group(4)!) : 0,
            m.group(5) != null ? int.parse(m.group(5)!) : 0,
            m.group(6) != null ? int.parse(m.group(6)!) : 0,
          );
        }
      }
      // 8月30日 9:59
      final m = RegExp(r'(\d+)月(\d+)日\s*(\d+):(\d+)').firstMatch(s);
      if (m != null) {
        final now = DateTime.now();
        return DateTime(
            now.year, int.parse(m.group(1)!), int.parse(m.group(2)!),
            int.parse(m.group(3)!), int.parse(m.group(4)!));
      }
    } catch (_) {}
    return null;
  }

  void _persist() {
    PersistenceService.saveShops(_shops);
  }

  bool get isAllSelected =>
      _shops.every((shop) => shop.items.every((item) => item.isSelected));

  int get selectedCount {
    var count = 0;
    for (final shop in _shops) {
      for (final item in shop.items) {
        if (item.isSelected) count += item.quantity;
      }
    }
    return count;
  }

  double get totalPrice {
    var total = 0.0;
    for (final shop in _shops) {
      for (final item in shop.items) {
        if (item.isSelected) total += item.price * item.quantity;
      }
    }
    return total;
  }

  void toggleItemSelection(OrderItem item) {
    item.isSelected = !item.isSelected;
    _syncShopSelection();
    _persist();
    notifyListeners();
  }

  void toggleShopSelection(ShoppingCartShop shop) {
    shop.isSelected = !shop.isSelected;
    for (final item in shop.items) {
      item.isSelected = shop.isSelected;
    }
    _persist();
    notifyListeners();
  }

  void toggleAllSelection() {
    final target = !isAllSelected;
    for (final shop in _shops) {
      shop.isSelected = target;
      for (final item in shop.items) {
        item.isSelected = target;
      }
    }
    _persist();
    notifyListeners();
  }

  void changeQuantity(OrderItem item, int delta) {
    item.quantity = (item.quantity + delta).clamp(1, 99);
    _persist();
    notifyListeners();
  }

  void removeSelected() {
    for (final shop in _shops) {
      shop.items.removeWhere((item) => item.isSelected);
    }
    _shops.removeWhere((shop) => shop.items.isEmpty);
    _persist();
    notifyListeners();
  }

  void _syncShopSelection() {
    for (final shop in _shops) {
      shop.isSelected = shop.items.every((item) => item.isSelected);
    }
  }

  void updateOrderItem(
    OrderItem item, {
    String? title,
    String? configuration,
    double? price,
    double? originalPrice,
    String? statusTitle,
    String? countDown,
    String? logistics,
    String? createTime,
    String? payTime,
    String? shipTime,
    String? address,
    String? receiver,
    bool? isSigned,
    String? returnText,
    String? deliveryText,
    bool? showOnTime,
    String? onTimeText,
    String? imageUrl,
    String? deliveryPromise,
    bool? showDeliveryPromise,
    String? paymentMethod,
    String? alipayTradeNo,
    String? wechatTradeNo,
    double? productTotal,
    double? shopDiscount,
    bool? showShopDiscount,
    double? platformCoupon,
    String? platformCouponLabel,
    bool? showPlatformCoupon,
    double? coDiscount,
    String? taxContent,
    bool? showTax,
    List<String>? detailTags,
    int? tmallPoints,
    bool? showTmallPoints,
    bool? showPlatformPriceRow,
    bool? showCouponPriceRow,
    bool? showTaxInfoLine,
    String? refundStatus,
    String? refundTitle,
    String? refundSubtitle,
    double? refundAmount,
    String? refundMethod,
    String? refundLogistics,
    String? refundApplyTime,
    String? refundDoneTime,
    int? refundBarStyle,
    double? refundDiscount,
    bool? showRefundDiscount,
  }) {
    if (title != null) item.title = title;
    if (configuration != null) item.configuration = configuration;
    if (price != null) item.price = price;
    if (originalPrice != null) item.originalPrice = originalPrice;
    if (statusTitle != null) item.statusTitle = statusTitle;
    if (countDown != null) item.countDown = countDown;
    if (logistics != null) item.logistics = logistics;
    if (createTime != null) {
      item.createTime = createTime;
    }
    if (payTime != null) {
      item.payTime = payTime;
      // 交易号前 8 位跟随付款时间（yyyyMMdd）+ 20 位随机 = 28 位
      final first8 = _timePrefix(payTime);
      item.alipayTradeNo = _composeTradeNo(first8);
      item.wechatTradeNo = _composeTradeNo(first8);
    }
    if (shipTime != null) item.shipTime = shipTime;
    if (address != null) item.address = address;
    if (receiver != null) item.receiver = receiver;
    if (isSigned != null) item.isSigned = isSigned;
    if (returnText != null) item.returnText = returnText;
    if (deliveryText != null) item.deliveryText = deliveryText;
    if (showOnTime != null) item.showOnTime = showOnTime;
    if (onTimeText != null) item.onTimeText = onTimeText;
    if (imageUrl != null) item.imageUrl = imageUrl;
    if (deliveryPromise != null) item.deliveryPromise = deliveryPromise;
    if (showDeliveryPromise != null) item.showDeliveryPromise = showDeliveryPromise;
    if (paymentMethod != null) {
      item.paymentMethod = paymentMethod;
      // 切换支付方式时确保交易号同步呈现（保留之前的具体值，避免覆盖用户手动改的）
      // 但若账户对应的交易号是空的则生成
      if (paymentMethod.contains('微信') && item.wechatTradeNo.isEmpty) {
        item.wechatTradeNo = _composeTradeNo(_timePrefix(item.payTime));
      } else if (paymentMethod.contains('支付宝') && item.alipayTradeNo.isEmpty) {
        item.alipayTradeNo = _composeTradeNo(_timePrefix(item.payTime));
      }
    }
    if (alipayTradeNo != null && alipayTradeNo.isNotEmpty) {
      item.alipayTradeNo = alipayTradeNo;
    }
    if (wechatTradeNo != null && wechatTradeNo.isNotEmpty) {
      item.wechatTradeNo = wechatTradeNo;
    }
    if (productTotal != null) item.productTotal = productTotal;
    if (shopDiscount != null) item.shopDiscount = shopDiscount;
    if (showShopDiscount != null) item.showShopDiscount = showShopDiscount;
    if (platformCoupon != null) item.platformCoupon = platformCoupon;
    if (platformCouponLabel != null) item.platformCouponLabel = platformCouponLabel;
    if (showPlatformCoupon != null) item.showPlatformCoupon = showPlatformCoupon;
    if (coDiscount != null) item.coDiscount = coDiscount;
    if (taxContent != null) item.taxContent = taxContent;
    if (showTax != null) item.showTax = showTax;
    if (detailTags != null) item.detailTags = detailTags;
    if (tmallPoints != null) item.tmallPoints = tmallPoints;
    if (showTmallPoints != null) item.showTmallPoints = showTmallPoints;
    if (showPlatformPriceRow != null) item.showPlatformPriceRow = showPlatformPriceRow;
    if (showCouponPriceRow != null) item.showCouponPriceRow = showCouponPriceRow;
    if (showTaxInfoLine != null) item.showTaxInfoLine = showTaxInfoLine;
    if (refundStatus != null) item.refundStatus = refundStatus;
    if (refundTitle != null) item.refundTitle = refundTitle;
    if (refundSubtitle != null) item.refundSubtitle = refundSubtitle;
    if (refundAmount != null) item.refundAmount = refundAmount;
    if (refundMethod != null) item.refundMethod = refundMethod;
    if (refundLogistics != null) item.refundLogistics = refundLogistics;
    if (refundApplyTime != null) item.refundApplyTime = refundApplyTime;
    if (refundDoneTime != null) item.refundDoneTime = refundDoneTime;
    if (refundBarStyle != null) item.refundBarStyle = refundBarStyle;
    if (refundDiscount != null) item.refundDiscount = refundDiscount;
    if (showRefundDiscount != null) {
      item.showRefundDiscount = showRefundDiscount;
    }
    // 价格相关字段变动后，自动重算实付款并同步到所有展示位置
    _recalcPaidAmount(item);
    _persist();
    notifyListeners();
  }

  /// 实付款 = 商品总价 - 所有（显示中的）优惠，自动同步
  void _recalcPaidAmount(OrderItem item) {
    if (item.productTotal <= 0) return;
    var paid = item.productTotal;
    if (item.showShopDiscount) paid -= item.shopDiscount;
    if (item.showPlatformCoupon) paid -= item.platformCoupon;
    if (paid < 0) paid = 0;
    item.price = double.parse(paid.toStringAsFixed(2));
  }

  /// 修改订单状态（9 个固定选项），并自动归类到对应栏目
  void updateOrderStatus(ShoppingCartShop shop, OrderItem item, String status) {
    item.statusTitle = status;
    shop.orderSubStatus = status;
    final category = statusCategory(status);
    shop.orderStatus = category == '退款/售后' ? '退款/售后' : category;
    // 退款类状态同步退款详情页字段
    if (category == '退款/售后') {
      item.refundStatus = status.contains('成功') ? '退款成功' : '待商家退款';
      item.refundTitle = item.refundStatus;
    }
    _persist();
    notifyListeners();
  }

  void removeItem(OrderItem item) {
    for (final shop in _shops) {
      shop.items.remove(item);
    }
    _shops.removeWhere((shop) => shop.items.isEmpty);
    _persist();
    notifyListeners();
  }

  /// 删除整单（订单管理页左滑删除）
  void removeShop(ShoppingCartShop shop) {
    _shops.remove(shop);
    _persist();
    notifyListeners();
  }

  /// 创建随机新订单（itemCount：单个店铺内商品数 1/2/3）
  void createRandomOrder({int itemCount = 1}) {
    final newShop =
        CartGenerator.generate(count: 1, itemCount: itemCount).first;
    _shops.add(newShop);
    _persist();
    notifyListeners();
  }

  /// 随机添加 4-5 个商品（每店 1 件，购物车"对比"按钮触发）
  /// 返回实际添加的商品数
  int addRandomProducts() {
    final n = 4 + Random().nextInt(2); // 4 或 5
    final newShops = CartGenerator.generate(count: n, itemCount: 1);
    _shops.addAll(newShops);
    _persist();
    notifyListeners();
    return newShops.fold(0, (sum, s) => sum + s.items.length);
  }

  /// 单号迁移：订单编号固定 512 开头 19 位（真实单号 5125/5126/5127 均保留）；
  /// 交易号固定 28 位（付款时间前8位+20位随机）
  void _migrateTradeNos() {
    var changed = false;
    bool needOrderNo(String no) => !(no.startsWith('512') && no.length == 19);
    bool needTradeNo(String no) => no.length != 28;
    for (final shop in _shops) {
      for (final item in shop.items) {
        // 老版本订单编号与交易号同值（5127 开头 19 位），迁移时把它保留为订单编号
        if (needOrderNo(item.orderNo)) {
          final legacy = item.alipayTradeNo;
          item.orderNo = (!needOrderNo(legacy))
              ? legacy
              : _composeOrderNo();
          changed = true;
        }
        if (needTradeNo(item.alipayTradeNo)) {
          item.alipayTradeNo = _composeTradeNo(_timePrefix(item.payTime));
          changed = true;
        }
        if (needTradeNo(item.wechatTradeNo)) {
          item.wechatTradeNo = _composeTradeNo(_timePrefix(item.payTime));
          changed = true;
        }
      }
    }
    if (changed) _persist();
  }

  /// 售后卡片退款条迁移：老数据 refundBarStyle=-1 时随机生成样式与优惠金额并固化
  void _migrateRefundBar() {
    var changed = false;
    final rand = Random();
    for (final shop in _shops) {
      for (final item in shop.items) {
        if (item.refundBarStyle < 0) {
          item.refundBarStyle = rand.nextInt(4);
          final base = item.price * item.quantity;
          item.refundDiscount = double.parse(
              ((base * 0.04) + rand.nextDouble() * base * 0.12)
                  .toStringAsFixed(2));
          changed = true;
        }
      }
    }
    if (changed) _persist();
  }

  void updateShop(
    ShoppingCartShop shop, {
    String? shopName,
    String? shopBadge,
    bool? isInternational,
    String? orderStatus,
    String? orderSubStatus,
    String? orderTotalTip,
    String? shopSubtitle,
    String? goodRate,
    String? csRate,
    String? fansCount,
    double? shopScore,
  }) {
    if (shopName != null) shop.shopName = shopName;
    if (shopBadge != null) shop.shopBadge = shopBadge;
    if (isInternational != null) shop.isInternational = isInternational;
    if (orderStatus != null) shop.orderStatus = orderStatus;
    if (orderSubStatus != null) shop.orderSubStatus = orderSubStatus;
    if (orderTotalTip != null) shop.orderTotalTip = orderTotalTip;
    if (shopSubtitle != null) shop.shopSubtitle = shopSubtitle;
    if (goodRate != null) shop.goodRate = goodRate;
    if (csRate != null) shop.csRate = csRate;
    if (fansCount != null) shop.fansCount = fansCount;
    if (shopScore != null) shop.shopScore = shopScore;
    _persist();
    notifyListeners();
  }

  void markSigned(ShoppingCartShop shop, OrderItem item) {
    item.isSigned = true;
    item.statusTitle = '已签收';
    shop.orderStatus = '待评价';
    shop.orderSubStatus = '已签收';
    _persist();
    notifyListeners();
  }

  /// 重置全部数据为默认（清空所有修改）
  Future<void> resetAll() async {
    _shops = CartGenerator.generate(count: 4);
    _persist();
    notifyListeners();
  }

  // ============ 工具方法 ============

  /// 创建时间 -> 单号前 8 位
  /// "2026-08-26 11:28:56" -> "20260826"
  /// "8月30日 9:59"        -> 当前年月日
  String _timePrefix(String createTime) {
    final dt = _parseCreateTime(createTime) ?? DateTime.now();
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  /// 拼接订单编号：5127 开头 + 15 位随机数字 = 19 位
  String _composeOrderNo() {
    final rand = Random();
    final tail =
        List.generate(15, (_) => rand.nextInt(10).toString()).join();
    return '5127$tail';
  }

  /// 拼接交易号：付款时间前 8 位 + 20 位随机数字 = 28 位
  String _composeTradeNo(String prefix8) {
    final rand = Random();
    final p = prefix8.length == 8 ? prefix8 : _timePrefix('');
    final tail =
        List.generate(20, (_) => rand.nextInt(10).toString()).join();
    return '$p$tail';
  }

  /// 从 OrderItem 中根据支付方式获取应展示的交易号
  String tradeNoFor(OrderItem item) {
    if (item.paymentMethod.contains('微信')) return item.wechatTradeNo;
    return item.alipayTradeNo;
  }
}
