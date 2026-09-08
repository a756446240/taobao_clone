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

  // ============ 订单状态固定选项（双向可逆，任意互切） ============
  static const List<String> orderStatusOptions = [
    '待发货',
    '已发货',
    '已经签收',
    '待确认收货',
    '仓库已发货',
    '交易成功',
    '交易关闭',
    '待商家退款',
    '退款成功',
    '退款结束',
  ];

  /// 状态 → 栏目归类（待发货 / 待收货 / 退款/售后 / 已完成）
  static String statusCategory(String status) {
    if (status.contains('待发货') ||
        status.contains('等待发货') ||
        status.contains('商家处理')) {
      return '待发货';
    }
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

  /// 已删除订单号黑名单：用户主动删掉的订单号会记在这里，
  /// 淘宝同步导入时永久跳过（防止已删订单复活）。
  final Set<String> _deletedTradeNos = {};

  /// 已删除黑名单中的订单号数量（同步导入页展示用）
  int get deletedTradeNosCount => _deletedTradeNos.length;

  /// 判断订单号是否在已删除黑名单里
  bool isTradeNoDeleted(String orderNo) => _deletedTradeNos.contains(orderNo);

  /// 把订单号记入已删除黑名单并持久化
  void _markDeleted(Iterable<String> orderNos) {
    var changed = false;
    for (final no in orderNos) {
      if (no.isNotEmpty && _deletedTradeNos.add(no)) changed = true;
    }
    if (changed) {
      PersistenceService.saveDeletedTradeNos(_deletedTradeNos.toList());
    }
  }

  /// 清空已删除黑名单（之后同步导入可重新导入这些订单）
  Future<void> clearDeletedTradeNos() async {
    _deletedTradeNos.clear();
    await PersistenceService.saveDeletedTradeNos(const []);
    notifyListeners();
  }

  /// 淘宝同步导入：按订单号去重，只追加本地不存在的新订单。
  /// 已在本地的订单（含用户编辑过的内容）绝不覆盖；
  /// 用户删除过的订单（黑名单）永久跳过、不会复活。
  /// 返回 (新增订单条数, 重复跳过条数, 已删除拦截条数)。
  ({int added, int skipped, int blocked}) importSyncedShops(
      List<ShoppingCartShop> incoming,
      {bool forceRefresh = false}) {
    final existingNos = <String>{
      for (final shop in _shops)
        for (final item in shop.items) item.orderNo,
    };
    var added = 0;
    var skipped = 0;
    var blocked = 0;
    var opsBackfilled = false;
    for (final shop in incoming) {
      // v1.9.75：已有订单只补缺省的抓包按钮序列（orderOps 是新版字段，
      // 用户不可能手动改过，补齐不违反"只增不改"原则）
      if (shop.orderOps.isNotEmpty) {
        final incomingNos = shop.items.map((e) => e.orderNo).toSet();
        for (final old in _shops) {
          if (old.orderOps.isNotEmpty) continue;
          if (old.items.any((e) => incomingNos.contains(e.orderNo))) {
            old.orderOps = shop.orderOps;
            opsBackfilled = true;
          }
        }
      }
      // v1.9.78：抓包真实店铺头像，按订单号匹配回填（只补空值）
      if (shop.shopAvatar.isNotEmpty) {
        final incomingNos = shop.items.map((e) => e.orderNo).toSet();
        for (final old in _shops) {
          if (old.shopAvatar.isNotEmpty) continue;
          if (old.items.any((e) => incomingNos.contains(e.orderNo))) {
            old.shopAvatar = shop.shopAvatar;
            opsBackfilled = true;
          }
        }
      }
      // v1.9.76：抓包真实物流（全量时间线/公司/单号）同步到已有订单——
      // 只补空值，用户双击改过的物流文字绝不覆盖
      for (final it in shop.items) {
        if (it.orderNo.isEmpty) continue;
        for (final old in _shops) {
          for (final oldItem in old.items) {
            if (oldItem.orderNo != it.orderNo) continue;
            if (oldItem.logisticsTraces.isEmpty &&
                it.logisticsTraces.isNotEmpty) {
              oldItem.logisticsTraces = it.logisticsTraces;
              opsBackfilled = true;
            }
            if (oldItem.shipCompany.isEmpty &&
                it.shipCompany.isNotEmpty) {
              oldItem.shipCompany = it.shipCompany;
              opsBackfilled = true;
            }
            if (oldItem.waybillNo.isEmpty && it.waybillNo.isNotEmpty) {
              oldItem.waybillNo = it.waybillNo;
              opsBackfilled = true;
            }
            if (oldItem.logistics.isEmpty && it.logistics.isNotEmpty) {
              oldItem.logistics = it.logistics;
              opsBackfilled = true;
            }
            // 发货时间：抓包真实值只补空（待发货本就为空，不反向清）
            if (oldItem.shipTime.isEmpty && it.shipTime.isNotEmpty) {
              oldItem.shipTime = it.shipTime;
              opsBackfilled = true;
            }
            // 快递官方 logo/客服电话（v1.9.79）：抓包真实值只补空
            if (oldItem.shipLogo.isEmpty && it.shipLogo.isNotEmpty) {
              oldItem.shipLogo = it.shipLogo;
              opsBackfilled = true;
            }
            if (oldItem.shipPhone.isEmpty && it.shipPhone.isNotEmpty) {
              oldItem.shipPhone = it.shipPhone;
              opsBackfilled = true;
            }
            // 赠品（v1.9.85）：抓包赠品信息只补零值，手动改过的绝不覆盖
            if (oldItem.giftCount == 0 && it.giftCount > 0) {
              oldItem.giftCount = it.giftCount;
              oldItem.giftImage = it.giftImage;
              oldItem.giftTitle = it.giftTitle;
              opsBackfilled = true;
            }
            // 优惠明细（v1.9.93）：抓包优惠子项只补空值，手动改过的绝不覆盖
            if (oldItem.discountDetails.isEmpty &&
                it.discountDetails.isNotEmpty) {
              oldItem.discountDetails = it.discountDetails;
              opsBackfilled = true;
            }
            // 服务标签（v1.9.91）：抓包 detailTags 只补空值——
            // 旧数据默认是 ['极速退款','7天无理由']（模型默认值），
            // 抓包有真实标签时替换；用户手动改过的（非默认值）绝不覆盖
            if (it.detailTags.isNotEmpty) {
              final isDefault = oldItem.detailTags.length == 2 &&
                  oldItem.detailTags.contains('极速退款') &&
                  (oldItem.detailTags.contains('7天无理由') ||
                      oldItem.detailTags.contains('7天无理由退货'));
              if (oldItem.detailTags.isEmpty || isDefault) {
                oldItem.detailTags = it.detailTags;
                // 抓包有真实标签时清空 returnText，避免 displayTags 合并重复
                oldItem.returnText = '';
                opsBackfilled = true;
              }
            }
          }
        }
      }
      final newItems = <OrderItem>[];
      for (final it in shop.items) {
        if (it.orderNo.isNotEmpty && _deletedTradeNos.contains(it.orderNo)) {
          blocked++;
        } else if (it.orderNo.isNotEmpty && existingNos.contains(it.orderNo)) {
          // v1.9.91：强制刷新模式——已有订单号不跳过，先从 _shops 删掉旧项，
          // 新项加入 newItems（用新数据替换旧数据，保留用户手动改过的字段）
          if (forceRefresh) {
            for (final oldShop in _shops) {
              oldShop.items.removeWhere((e) => e.orderNo == it.orderNo);
            }
            // 删掉空店铺（所有商品都被替换走的）
            _shops.removeWhere((s) => s.items.isEmpty);
            newItems.add(it);
          } else {
            skipped++;
          }
        } else {
          newItems.add(it);
        }
      }
      if (newItems.isEmpty) continue;
      // v1.9.84：导入订单统一「微信支付」+ 微信交易号（清空支付宝交易号）
      for (final it in newItems) {
        it.paymentMethod = '微信支付';
        if (it.wechatTradeNo.length != 28) {
          it.wechatTradeNo = _composeWechatTradeNo();
        }
        it.alipayTradeNo = '';
        // v1.9.85：非待发货/待付款订单缺发货时间时，按创建时间当天随机补齐
        final cat = statusCategory(
            it.statusTitle.isEmpty ? shop.orderSubStatus : it.statusTitle);
        if (cat != '待发货' &&
            cat != '待付款' &&
            it.shipTime.trim().isEmpty) {
          it.shipTime = _autoShipTimeSameDay(it);
        }
      }
      shop.items
        ..clear()
        ..addAll(newItems);
      _shops.add(shop);
      added += newItems.length;
    }
    if (added > 0 || opsBackfilled) {
      _persist();
      notifyListeners();
    }
    return (added: added, skipped: skipped, blocked: blocked);
  }

  /// AI 截图解析导入：把识别出的订单追加为新店铺卡片（自动持久化，无需重新构建）
  void importAiParsedOrder({
    required String shopName,
    required String productTitle,
    required double price,
    required String status,
  }) {
    final now = DateTime.now();
    String fmt(DateTime t) =>
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    final item = OrderItem(
      imageUrl: '',
      title: productTitle,
      configuration: '默认规格',
      stock: 99,
      price: price,
      quantity: 1,
      createTime: fmt(now),
      payTime: status.contains('待付款') ? '' : fmt(now),
      orderNo: '5127${List.generate(15, (_) => Random().nextInt(10)).join()}',
      productTotal: price,
      statusTitle: status,
    );
    // 尝试塞进已有同名店铺，否则新建店铺
    ShoppingCartShop? target;
    for (final s in _shops) {
      if (s.shopName == shopName) {
        target = s;
        break;
      }
    }
    if (target != null) {
      target.items.insert(0, item);
    } else {
      _shops.insert(
        0,
        ShoppingCartShop(
          shopName: shopName,
          shopType: ShopType.taoBao,
          items: [item],
          orderStatus: status,
          orderSubStatus: status,
          orderTotalTip: '共1件商品 合计：',
        ),
      );
    }
    _persist();
    notifyListeners();
  }

  /// 商品详情页加入购物车 / 立即购买：
  /// - asPendingOrder=false → 状态"购物车"（只在购物车 Tab 显示，不进订单列表）
  /// - asPendingOrder=true  → 状态"待付款"（模拟下单，出现在待付款 Tab）
  void addToCart({
    required String shopName,
    required String title,
    required double price,
    required String imageUrl,
    required String spec,
    required int quantity,
    bool asPendingOrder = false,
  }) {
    final now = DateTime.now();
    String fmt(DateTime t) =>
        '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
    final status = asPendingOrder ? '待付款' : '购物车';
    final item = OrderItem(
      imageUrl: imageUrl,
      title: title,
      configuration: spec,
      stock: 99,
      price: price,
      quantity: quantity,
      createTime: fmt(now),
      payTime: '',
      orderNo: '5127${List.generate(15, (_) => Random().nextInt(10)).join()}',
      productTotal: price * quantity,
      statusTitle: status,
    );
    // 尝试塞进已有同名店铺，否则新建店铺
    ShoppingCartShop? target;
    for (final s in _shops) {
      if (s.shopName == shopName &&
          s.orderSubStatus == status) {
        target = s;
        break;
      }
    }
    if (target != null) {
      target.items.insert(0, item);
    } else {
      _shops.insert(
        0,
        ShoppingCartShop(
          shopName: shopName,
          shopType: ShopType.taoBao,
          items: [item],
          orderStatus: status,
          orderSubStatus: status,
          orderTotalTip: '共$quantity件商品 合计：',
        ),
      );
    }
    _persist();
    notifyListeners();
  }

  /// 读取本地持久化的订单；有则覆盖默认生成
  Future<void> _restoreFromDisk() async {
    try {
      final saved = await PersistenceService.loadShops();
      // 加载已删除订单号黑名单（同步导入防复活）
      _deletedTradeNos.addAll(await PersistenceService.loadDeletedTradeNos());
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
      _shops.isNotEmpty &&
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

  /// 选中的商品行数（批量管理用，与 selectedCount 的件数口径区分）
  int get selectedItemCount {
    var count = 0;
    for (final shop in _shops) {
      for (final item in shop.items) {
        if (item.isSelected) count++;
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
    _markDeleted([
      for (final shop in _shops)
        for (final item in shop.items)
          if (item.isSelected) item.orderNo,
    ]);
    for (final shop in _shops) {
      shop.items.removeWhere((item) => item.isSelected);
    }
    _shops.removeWhere((shop) => shop.items.isEmpty);
    _persist();
    notifyListeners();
  }

  /// 购物车结算：把勾选商品从原店铺取出，按店铺名归并到"待付款"状态，
  /// 与商品详情页「立即购买」走同一套待付款订单模式（出现在订单页待付款 Tab）。
  /// 返回结算的商品件数；无勾选时返回 0 且不做任何改动。
  int checkoutSelected() {
    // 1. 收集勾选商品（保持店铺分组）
    final picked = <String, List<OrderItem>>{};
    var count = 0;
    for (final shop in _shops) {
      for (final item in shop.items) {
        if (!item.isSelected) continue;
        picked.putIfAbsent(shop.shopName, () => []).add(item);
        count += item.quantity;
      }
    }
    if (picked.isEmpty) return 0;

    // 2. 从原店铺移除
    for (final shop in _shops) {
      shop.items.removeWhere((item) => item.isSelected);
    }
    _shops.removeWhere((shop) => shop.items.isEmpty);

    // 3. 逐店铺塞入已有同名"待付款"店铺，否则新建（同 addToCart 逻辑）
    for (final entry in picked.entries) {
      final items = entry.value;
      for (final item in items) {
        item.isSelected = false;
        item.statusTitle = '待付款';
      }
      ShoppingCartShop? target;
      for (final s in _shops) {
        if (s.shopName == entry.key && s.orderSubStatus == '待付款') {
          target = s;
          break;
        }
      }
      final qty = items.fold<int>(0, (sum, it) => sum + it.quantity);
      if (target != null) {
        target.items.insertAll(0, items);
      } else {
        _shops.insert(
          0,
          ShoppingCartShop(
            shopName: entry.key,
            shopType: ShopType.taoBao,
            items: items,
            orderStatus: '待付款',
            orderSubStatus: '待付款',
            orderTotalTip: '共$qty件商品 合计：',
          ),
        );
      }
    }
    _persist();
    notifyListeners();
    return count;
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
    bool? showShipTime,
    String? address,
    String? receiver,
    bool? isSigned,
    String? returnText,
    String? deliveryText,
    bool? showOnTime,
    String? onTimeText,
    int? onTimeStyle,
    String? onTimeText2,
    String? imageUrl,
    String? deliveryPromise,
    bool? showDeliveryPromise,
    String? shipPromise,
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
    double? shippingFee,
    bool? showShippingFee,
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
    String? refundSteps,
    String? pickupCode,
    String? pickupGuarantee,
    String? pickupTimeText,
    String? pickupInsuranceText,
    bool? showPickupCard,
    String? shipCompany,
    String? waybillNo,
    String? shipLogo,
    String? shipPhone,
    String? logisticsTraces,
    int? giftCount,
    String? giftImage,
    String? giftTitle,
    String? discountDetails,
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
      item.wechatTradeNo = _composeWechatTradeNo();
    }
    if (shipTime != null) item.shipTime = shipTime;
    if (showShipTime != null) item.showShipTime = showShipTime;
    if (address != null) item.address = address;
    if (receiver != null) item.receiver = receiver;
    if (isSigned != null) item.isSigned = isSigned;
    if (returnText != null) item.returnText = returnText;
    if (deliveryText != null) item.deliveryText = deliveryText;
    if (showOnTime != null) item.showOnTime = showOnTime;
    if (onTimeText != null) item.onTimeText = onTimeText;
    if (onTimeStyle != null) item.onTimeStyle = onTimeStyle;
    if (onTimeText2 != null) item.onTimeText2 = onTimeText2;
    if (imageUrl != null) item.imageUrl = imageUrl;
    if (deliveryPromise != null) item.deliveryPromise = deliveryPromise;
    if (showDeliveryPromise != null) item.showDeliveryPromise = showDeliveryPromise;
    if (shipPromise != null) item.shipPromise = shipPromise;
    if (paymentMethod != null) {
      item.paymentMethod = paymentMethod;
      // 切换支付方式时确保交易号同步呈现（保留之前的具体值，避免覆盖用户手动改的）
      // 但若账户对应的交易号是空的则生成
      if (paymentMethod.contains('微信') && item.wechatTradeNo.isEmpty) {
        item.wechatTradeNo = _composeWechatTradeNo();
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
    if (shippingFee != null) item.shippingFee = shippingFee;
    if (showShippingFee != null) item.showShippingFee = showShippingFee;
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
    if (refundSteps != null) item.refundSteps = refundSteps;
    if (pickupCode != null) item.pickupCode = pickupCode;
    if (pickupGuarantee != null) item.pickupGuarantee = pickupGuarantee;
    if (pickupTimeText != null) item.pickupTimeText = pickupTimeText;
    if (pickupInsuranceText != null) {
      item.pickupInsuranceText = pickupInsuranceText;
    }
    if (showPickupCard != null) item.showPickupCard = showPickupCard;
    if (shipCompany != null) item.shipCompany = shipCompany;
    if (waybillNo != null) item.waybillNo = waybillNo;
    if (shipLogo != null) item.shipLogo = shipLogo;
    if (shipPhone != null) item.shipPhone = shipPhone;
    if (logisticsTraces != null) item.logisticsTraces = logisticsTraces;
    if (giftCount != null) item.giftCount = giftCount;
    if (giftImage != null) item.giftImage = giftImage;
    if (giftTitle != null) item.giftTitle = giftTitle;
    if (discountDetails != null) item.discountDetails = discountDetails;
    // 实付款规则：
    // 1) 直接修改实付价（price）时，以录入值为准，绝不再用其它字段重算覆盖
    // 2) 修改商品总价/运费/优惠等组成项时，才自动重算实付款
    final priceComposingChanged = productTotal != null ||
        shopDiscount != null ||
        showShopDiscount != null ||
        platformCoupon != null ||
        showPlatformCoupon != null ||
        shippingFee != null ||
        showShippingFee != null;
    if (price == null && priceComposingChanged) {
      _recalcPaidAmount(item);
    }
    // 实付款全局联动（v1.9.80）：直接改实付价或组成项重算后，
    // 同步刷新所在店铺的整单实付 actualTotal，
    // 详情页下方实付款 + 订单列表合计立即跟随变化
    if (price != null || priceComposingChanged) {
      _syncShopActualTotal(item);
    }
    _persist();
    notifyListeners();
  }

  /// 把 item 所在店铺的 actualTotal 重算为各商品实付价之和
  void _syncShopActualTotal(OrderItem item) {
    for (final shop in _shops) {
      if (shop.items.contains(item)) {
        if (shop.actualTotal > 0) {
          final sum = shop.items.fold<double>(0, (s, e) => s + e.price);
          shop.actualTotal = double.parse(sum.toStringAsFixed(2));
        }
        return;
      }
    }
  }

  /// 实付款 = 商品总价 + 运费（显示中） - 所有（显示中的）优惠
  void _recalcPaidAmount(OrderItem item) {
    if (item.productTotal <= 0) return;
    var paid = item.productTotal;
    if (item.showShippingFee) paid += item.shippingFee;
    if (item.showShopDiscount) paid -= item.shopDiscount;
    if (item.showPlatformCoupon) paid -= item.platformCoupon;
    if (paid < 0) paid = 0;
    item.price = double.parse(paid.toStringAsFixed(2));
  }

  /// 修改订单状态，并自动归类到对应栏目。
  /// 状态双向可逆：退款类 ⇄ 普通类（待发货/已发货/交易成功…）可任意互切。
  void updateOrderStatus(ShoppingCartShop shop, OrderItem item, String status) {
    item.statusTitle = status;
    shop.orderSubStatus = status;
    final category = statusCategory(status);
    shop.orderStatus = category == '退款/售后' ? '退款/售后' : category;
    // v1.9.85：状态切换到已发货/待收货/交易成功/退款类时自动补发货时间
    // （创建时间当天往后随机、限当天）；切回待发货/待付款则清空（对齐真实淘宝）
    if (category == '待发货' || category == '待付款') {
      item.shipTime = '';
      // 未发货无物流信息（对齐真实淘宝），清掉切换前的残留物流文字
      item.logistics = '';
    } else if (item.shipTime.trim().isEmpty) {
      item.shipTime = _autoShipTimeSameDay(item);
    }
    // v1.9.89：切入发货类状态时，物流小窗无文字的自动生成在途文案
    // + 从抓包运单池分配真实单号（否则列表卡片物流条空白，且无法联网跟踪）
    if (category == '待收货') {
      if (item.logistics.trim().isEmpty) {
        item.logistics = _autoTransitText(item);
      }
      if (item.waybillNo.trim().isEmpty) {
        _assignWaybillFromPool(item);
      }
    }
    // 退款类状态同步退款详情页字段（三个退款状态互斥且都可逆）
    if (category == '退款/售后') {
      if (status.contains('成功')) {
        item.refundStatus = '退款成功';
      } else if (status.contains('结束')) {
        item.refundStatus = '退款结束';
      } else {
        item.refundStatus = '待商家退款';
      }
      item.refundTitle = item.refundStatus;
    } else {
      // v1.9.86：切出退款类时清掉退款残留字段——
      // 否则退款单改成交易成功后，审核页/退款条仍按退款单误判
      item.refundStatus = '';
      item.refundTitle = '';
    }
    _persist();
    notifyListeners();
  }

  /// 自动确认收货（对齐真实淘宝 10 天倒计时结束）：
  /// 「待收货」分类订单付款（无付款时间用创建时间）满 10 天 → 自动跳「交易成功」。
  /// 在订单列表页打开时扫描一次（v1.9.88）。
  void sweepAutoConfirm() {
    final now = DateTime.now();
    var backfilled = false;
    for (final shop in shops) {
      for (final it in shop.items) {
        if (statusCategory(it.statusTitle) != '待收货') continue;
        // v1.9.89：顺带回填存量订单——待收货但物流条空白/无单号的补齐
        if (it.logistics.trim().isEmpty) {
          it.logistics = _autoTransitText(it);
          backfilled = true;
        }
        if (it.waybillNo.trim().isEmpty) {
          _assignWaybillFromPool(it);
          backfilled = true;
        }
        final raw = it.payTime.isNotEmpty ? it.payTime : it.createTime;
        final base = DateTime.tryParse(raw.replaceAll(' ', 'T'));
        if (base == null) continue;
        if (now.difference(base).inDays >= 10) {
          updateOrderStatus(shop, it, '交易成功');
        }
      }
    }
    if (backfilled) {
      _persist();
      notifyListeners();
    }
  }

  /// 生成在途物流文案（按订单号哈希确定性，对齐真实淘宝列表物流条格式）
  String _autoTransitText(OrderItem item) {
    const origins = ['长沙', '杭州', '广州', '金华', '武汉', '上海', '郑州', '义乌'];
    const dests = ['济南', '淄博', '青岛', '潍坊', '烟台', '临沂'];
    final seed = (item.orderNo.isEmpty ? item.title : item.orderNo)
        .hashCode
        .abs();
    final o = origins[seed % origins.length];
    final d = dests[(seed ~/ 7) % dests.length];
    return '您的快件离开【$o转运中心】，已发往【$d】';
  }

  /// 无单号订单：从抓包运单池按订单号哈希稳定分配一个真实单号，
  /// 连带快递公司/官方头像/客服电话（与物流页 v1.9.88 逻辑同源）
  void _assignWaybillFromPool(OrderItem item) {
    final pool = <OrderItem>[
      for (final s in _shops)
        for (final e in s.items)
          if (!identical(e, item) && e.waybillNo.isNotEmpty) e,
    ];
    if (pool.isEmpty) return;
    final seed = (item.orderNo.isEmpty ? item.title : item.orderNo)
        .hashCode
        .abs();
    final donor = pool[seed % pool.length];
    item.waybillNo = donor.waybillNo;
    if (item.shipCompany.isEmpty) item.shipCompany = donor.shipCompany;
    if (item.shipLogo.isEmpty) item.shipLogo = donor.shipLogo;
    if (item.shipPhone.isEmpty) item.shipPhone = donor.shipPhone;
  }

  /// 生成当天发货时间：创建时间之后、限当天 23:59 前随机（按订单号哈希确定性）
  String _autoShipTimeSameDay(OrderItem item) {
    final base = _parseCreateTime(item.createTime) ??
        _parseCreateTime(item.payTime) ??
        DateTime.now();
    final seed = item.orderNo.isNotEmpty
        ? item.orderNo.hashCode
        : (item.title + item.createTime).hashCode;
    final rand = Random(seed);
    final endOfDay = DateTime(base.year, base.month, base.day, 23, 59, 59);
    final spanSec = endOfDay.difference(base).inSeconds;
    final t = spanSec > 120
        ? base.add(Duration(seconds: 60 + rand.nextInt(spanSec - 60)))
        : base.add(const Duration(minutes: 30));
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  void removeItem(OrderItem item) {
    _markDeleted([item.orderNo]);
    for (final shop in _shops) {
      shop.items.remove(item);
    }
    _shops.removeWhere((shop) => shop.items.isEmpty);
    _persist();
    notifyListeners();
  }

  /// 删除整单（订单管理页左滑删除）
  void removeShop(ShoppingCartShop shop) {
    _markDeleted(shop.items.map((e) => e.orderNo));
    _shops.remove(shop);
    _persist();
    notifyListeners();
  }

  /// 一键清空全部商品订单（仅淘宝商品订单 _shops，不影响闪购/飞猪）。
  /// 与逐单删除不同：**不写入已删黑名单**，方便清空后立即重新导入抓包订单。
  /// 返回清掉的订单（店铺块）数。
  int clearAllShops() {
    final n = _shops.length;
    if (n == 0) return 0;
    _shops.clear();
    _persist();
    notifyListeners();
    return n;
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
    bool needOrderNo(String no) => !((no.startsWith('512') && no.length == 19) ||
        RegExp(r'^\d{15,20}$').hasMatch(no)); // 512生成单号与真实淘宝单号（15-20位）都保留
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
          item.wechatTradeNo = _composeWechatTradeNo();
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
          final base = item.price;
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
    int? orderBtnStyle,
    int? shopLineStyle,
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
    if (orderBtnStyle != null) shop.orderBtnStyle = orderBtnStyle;
    if (shopLineStyle != null) shop.shopLineStyle = shopLineStyle;
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

  /// 发表评价后调用：订单移出「待评价」，标记为交易成功
  void markRated(ShoppingCartShop shop, OrderItem item) {
    item.statusTitle = '交易成功';
    shop.orderStatus = '交易成功';
    shop.orderSubStatus = '交易成功';
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

  /// 拼接微信交易号：420000 固定前缀 + 22 位随机数字 = 28 位
  /// （对齐真实微信支付 transaction_id 格式：420000 开头 28 位纯数字）
  String _composeWechatTradeNo() {
    final rand = Random();
    final tail =
        List.generate(22, (_) => rand.nextInt(10).toString()).join();
    return '420000$tail';
  }

  /// 从 OrderItem 中根据支付方式获取应展示的交易号
  String tradeNoFor(OrderItem item) {
    if (item.paymentMethod.contains('微信')) return item.wechatTradeNo;
    return item.alipayTradeNo;
  }
}
