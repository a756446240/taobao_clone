import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/material_pool_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/shop_type_badge.dart';

/// 购物车页（1:1 复刻 3.4 新版）
/// 商品项右滑显示“换图 / 编辑 / 删除”，不再直接显示编辑入口。
/// 商品图与名称参与素材库随机分配（图名对应），未命名素材自动 AI 匹配名称。
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  /// 购物车商品的分配 key：优先订单编号（稳定唯一），兜底用标题
  static String cartItemKey(OrderItem item) =>
      item.orderNo.isNotEmpty ? item.orderNo : item.title;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

/// 购物车页状态：管理模式下底部切换为批量操作栏（全选 / 移入收藏 / 删除）
class _CartScreenState extends State<CartScreen> {
  bool _managing = false;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final shops = cart.shops;
    // 素材池：为购物车商品随机分配"图+名对应"的素材（每次启动重抽，会话内稳定）
    final pool = context.watch<MaterialPoolProvider>();
    if (!pool.loading && !pool.isEmpty) {
      final keys = <String>[
        for (final s in shops)
          for (final it in s.items) CartScreen.cartItemKey(it),
      ];
      pool.assignCartMaterials(keys);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(context),
            _buildCouponBar(context),
            Expanded(
              child: shops.isEmpty
                  ? const Center(
                      child: Text('购物车是空的', style: AppTextStyles.middleSub))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: shops.length,
                      itemBuilder: (ctx, i) =>
                          _ShopCard(ctx, shop: shops[i], pool: pool),
                    ),
            ),
            _buildBottomBar(context, cart),
          ],
        ),
      ),
    );
  }

  // ============ 顶部工具栏（AI省钱 / 搜索 / 对比 / 管理）============
  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          // AI省钱：更紧凑，避免小屏溢出
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('AI',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 3),
              const Text('省钱',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          // 右侧操作统一放在一个紧凑 Row 里
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.search, size: 20, color: Colors.black87),
                onPressed: () {},
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () {
                  // 点击"对比"：随机添加 4-5 个商品
                  final added =
                      context.read<CartProvider>().addRandomProducts();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已随机添加 $added 个商品'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text('对比',
                    style: TextStyle(fontSize: 13, color: Colors.black87)),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                // 单击：进入/退出批量管理模式；双击：店铺编辑菜单
                onTap: () => setState(() => _managing = !_managing),
                onDoubleTap: () => _showManageSheet(context),
                child: Text(_managing ? '完成' : '管理',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.black87)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============ 顶部消费券提示条 ============
  Widget _buildCouponBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_offer, color: Colors.red, size: 16),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('您有3张共61元消费券待领取',
                style: TextStyle(fontSize: 12, color: Colors.red)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('领61元',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ============ 店铺卡片 ============
  Widget _ShopCard(BuildContext context,
      {required ShoppingCartShop shop, required MaterialPoolProvider pool}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 店铺头
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _selectIcon(shop.isSelected,
                    onTap: () => context
                        .read<CartProvider>()
                        .toggleShopSelection(shop)),
                const SizedBox(width: 8),
                // 店铺类型徽章（天猫/淘宝/国际，双击可切换）
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onDoubleTap: () => _pickShopType(context, shop),
                    child: ShopTypeBadge(shop: shop),
                  ),
                ),
                Expanded(
                  child: Text(shop.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.smallBold),
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFc4c4c4), size: 16),
                const SizedBox(width: 8),
                if (shop.hasCoupons)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('领券',
                        style: TextStyle(
                            color: AppColors.primary, fontSize: 10)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // 商品列表（带右滑操作，展示素材库随机分配的图+名）
          ...shop.items.map((item) => _SlidableCartItem(
                item: item,
                material: pool.cartMaterialFor(CartScreen.cartItemKey(item)),
              )),
        ],
      ),
    );
  }

  // ============ 商品项（右滑显示“换图 / 编辑 / 删除”）============
  Widget _SlidableCartItem({required OrderItem item, MaterialEntry? material}) {
    return Builder(
      builder: (context) => Slidable(
        key: ValueKey(item.hashCode),
        direction: Axis.horizontal,
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.38,
          children: [
            CustomSlidableAction(
              onPressed: (_) => _pickCartItemImage(context, item),
              backgroundColor: const Color(0xFF5C6BC0),
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image, size: 20),
                  SizedBox(height: 2),
                  Text('换图', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => _showEditCartItemSheet(context, item),
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(height: 2),
                  Text('编辑', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) {
                context.read<CartProvider>().removeItem(item);
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(height: 2),
                  Text('删除', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        child:
            _CartItemContent(context: context, item: item, material: material),
      ),
    );
  }

  Future<void> _pickCartItemImage(BuildContext context, OrderItem item) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/cart_images');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'cart_${DateTime.now().millisecondsSinceEpoch}$ext';
      final saved = await File(picked.path).copy('${saveDir.path}/$fileName');
      if (!context.mounted) return;
      context.read<CartProvider>().updateOrderItem(
            item,
            imageUrl: saved.path,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品图已替换'), duration: Duration(seconds: 1)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片替换失败')),
      );
    }
  }

  void _showEditCartItemSheet(BuildContext context, OrderItem item) {
    final titleCtrl = TextEditingController(text: item.title);
    final specCtrl = TextEditingController(text: item.configuration);
    final priceCtrl =
        TextEditingController(text: item.price.toStringAsFixed(item.price % 1 == 0 ? 0 : 2));
    final originCtrl = TextEditingController(
        text: item.originalPrice?.toStringAsFixed(
                (item.originalPrice ?? 0) % 1 == 0 ? 0 : 0) ??
            '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('编辑商品', style: AppTextStyles.normalBold),
              const SizedBox(height: 12),
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '标题')),
              TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(labelText: '规格')),
              TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '价格')),
              TextField(
                  controller: originCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '划线价（可空）')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final price = double.tryParse(priceCtrl.text);
                        final origin = originCtrl.text.isEmpty
                            ? null
                            : double.tryParse(originCtrl.text);
                        context.read<CartProvider>().updateOrderItem(
                              item,
                              title: titleCtrl.text,
                              configuration: specCtrl.text,
                              price: price,
                              originalPrice: origin,
                            );
                        Navigator.pop(ctx);
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ============ 店铺类型切换（点击徽章：天猫/淘宝/国际） ============
  void _pickShopType(BuildContext context, ShoppingCartShop shop) {
    DialogHelpers.showOptionPicker(
      context,
      title: '切换店铺类型',
      options: ShopTypeBadge.typeOptions,
      currentValue: ShopTypeBadge.resolve(shop).text,
    ).then((v) {
      if (v == null) return;
      context.read<CartProvider>().updateShop(
            shop,
            shopBadge: v,
            isInternational: v == '国际',
          );
    });
  }

  // ============ 管理（店铺编辑入口集中在这里） ============
  void _showManageSheet(BuildContext context) {
    final shops = context.read<CartProvider>().shops;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('管理',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: shops.length,
                  itemBuilder: (_, i) {
                    final shop = shops[i];
                    return ListTile(
                      leading: ShopTypeBadge(shop: shop),
                      title: Text(shop.shopName,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${shop.items.length} 件商品',
                          style: const TextStyle(fontSize: 12)),
                      trailing: GestureDetector(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showShopEditSheet(context, shop);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border:
                                Border.all(color: const Color(0xFFc4c4c4)),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('编辑',
                              style: TextStyle(
                                  color: Colors.black87, fontSize: 12)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============ 店铺编辑（店名 + 店铺类型 天猫/淘宝/国际） ============
  void _showShopEditSheet(BuildContext context, ShoppingCartShop shop) {
    final nameCtrl = TextEditingController(text: shop.shopName);
    var selectedType = ShopTypeBadge.resolve(shop).text;
    if (!ShopTypeBadge.typeOptions.contains(selectedType)) {
      selectedType = '天猫';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Text('编辑店铺',
                          style: AppTextStyles.normalBold)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: '店铺名称')),
                  const SizedBox(height: 12),
                  const Text('店铺类型',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Row(
                    children: ShopTypeBadge.typeOptions.map((t) {
                      final selected = t == selectedType;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedType = t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white,
                              border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : const Color(0xFFc4c4c4)),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(t,
                                style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontSize: 13)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            context.read<CartProvider>().updateShop(
                                  shop,
                                  shopName: name,
                                  shopBadge: selectedType,
                                  isInternational: selectedType == '国际',
                                );
                            Navigator.pop(ctx);
                          },
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============ 商品项内容（3.4 风格）============
  /// 商品图/名称优先展示素材库随机分配结果（图名严格对应）；
  /// 素材未命名时自动触发豆包 AI 识别起名，识别完成后界面自动刷新。
  Widget _CartItemContent(
      {required BuildContext context,
      required OrderItem item,
      MaterialEntry? material}) {
    // 未命名的素材自动 AI 匹配名称（识别中/失败过的会自动跳过）
    if (material != null && material.title.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.read<MaterialPoolProvider>().aiNameEntry(material);
        }
      });
    }
    final displayImage = material?.imagePath ?? item.imageUrl;
    final displayTitle =
        (material != null && material.title.isNotEmpty)
            ? material.title
            : item.title;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selectIcon(item.isSelected,
              onTap: () =>
                  Provider.of<CartProvider>(context, listen: false).toggleItemSelection(item)),
          const SizedBox(width: 8),
          // 商品图（素材库随机分配，图名对应）
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AppImage(url: displayImage, width: 84, height: 84),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small),
                const SizedBox(height: 4),
                Text(item.configuration,
                    style: AppTextStyles.min
                        .copyWith(color: AppColors.subText)),
                const SizedBox(height: 6),
                // 立减/补贴/官方立减 标签
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: item.discountLabels
                      .map((l) => _discountChip(l))
                      .toList(),
                ),
                const SizedBox(height: 6),
                // 服务标签（退货宝/大促价保/超级爆款）
                if (item.serviceTags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: item.serviceTags
                        .map((t) => _serviceTag(t))
                        .toList(),
                  ),
                const SizedBox(height: 6),
                // 价格区（基线对齐，修复金额字体不齐）
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text('平台加补后',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFF999999))),
                    const SizedBox(width: 4),
                    Text('¥',
                        style: AppTextStyles.price.copyWith(fontSize: 12)),
                    Text(
                      item.price.toStringAsFixed(
                          item.price % 1 == 0 ? 0 : 1),
                      style: AppTextStyles.price.copyWith(fontSize: 20),
                    ),
                    const SizedBox(width: 6),
                    if (item.originalPrice != null)
                      Text(
                        '¥${item.originalPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
                if (item.taxInfo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.taxInfo,
                      style: const TextStyle(
                          color: Color(0xFF999999), fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _discountChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.red, fontSize: 10)),
    );
  }

  Widget _serviceTag(String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFe8f5e9),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(tag,
          style: const TextStyle(
              color: Color(0xFF2e7d32), fontSize: 10)),
    );
  }

  Widget _selectIcon(bool selected, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFc4c4c4),
            width: 1.5,
          ),
          color: selected ? AppColors.primary : Colors.transparent,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : null,
      ),
    );
  }

  // ============ 底部栏（结算 / 管理两种模式） ============
  Widget _buildBottomBar(BuildContext context, CartProvider cart) {
    if (_managing) return _buildManageBar(context, cart);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => cart.toggleAllSelection(),
            child: Row(
              children: [
                _selectIcon(cart.isAllSelected, onTap: () => cart.toggleAllSelection()),
                const SizedBox(width: 4),
                const Text('全选', style: AppTextStyles.small),
              ],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text('合计：', style: AppTextStyles.small),
                  Text('¥',
                      style: AppTextStyles.price.copyWith(fontSize: 13)),
                  Text(
                    cart.totalPrice.toStringAsFixed(2),
                    style: AppTextStyles.price.copyWith(fontSize: 22),
                  ),
                ],
              ),
              const Text('不含运费', style: AppTextStyles.min),
            ],
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '结算 ${cart.selectedCount} 件商品，共 ¥${cart.totalPrice.toStringAsFixed(2)}'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                '结算(${cart.selectedCount})',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ 管理模式底部栏（全选 / 移入收藏 / 删除） ============
  Widget _buildManageBar(BuildContext context, CartProvider cart) {
    final hasSelection = cart.selectedItemCount > 0;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => cart.toggleAllSelection(),
            child: Row(
              children: [
                _selectIcon(cart.isAllSelected,
                    onTap: () => cart.toggleAllSelection()),
                const SizedBox(width: 4),
                const Text('全选', style: AppTextStyles.small),
              ],
            ),
          ),
          const Spacer(),
          // 移入收藏（无选中时置灰）
          GestureDetector(
            onTap: hasSelection
                ? () => _moveSelectedToFavorites(context, cart)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(
                    color: hasSelection
                        ? AppColors.primary
                        : const Color(0xFFc4c4c4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('移入收藏',
                  style: TextStyle(
                      color: hasSelection
                          ? AppColors.primary
                          : const Color(0xFFc4c4c4),
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          // 删除（无选中时置灰）
          GestureDetector(
            onTap: hasSelection ? () => _deleteSelected(context, cart) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: hasSelection
                    ? AppColors.primary
                    : const Color(0xFFc4c4c4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('删除(${cart.selectedItemCount})',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _moveSelectedToFavorites(BuildContext context, CartProvider cart) {
    final count = cart.selectedItemCount;
    cart.removeSelected();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('已将 $count 件商品移入收藏夹'),
          duration: const Duration(seconds: 1)),
    );
  }

  Future<void> _deleteSelected(
      BuildContext context, CartProvider cart) async {
    final count = cart.selectedItemCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除商品'),
        content: Text('确定要删除选中的 $count 件商品吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    cart.removeSelected();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('已删除 $count 件商品'),
          duration: const Duration(seconds: 1)),
    );
  }
}
