import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/app_image.dart';

/// 订单管理页：从待发货页右上角入口进入
/// - 订单按创建时间自动排序（创建时间靠前的往下排）
/// - 左滑删除订单
class OrderManagerScreen extends StatelessWidget {
  const OrderManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CartProvider>();
    final shops = provider.shops;

    return Scaffold(
      backgroundColor: const Color(0xFFf5f5f5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        ),
        title: const Text('订单管理',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        actions: [
          // 创建订单（单个 / 2个商品一店 / 3个商品一店）
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline,
                color: Color(0xFFff5000), size: 24),
            onSelected: (v) {
              final count = int.tryParse(v) ?? 1;
              provider.createRandomOrder(itemCount: count);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('已创建 $count 个商品一个店铺的新订单'),
                    duration: const Duration(seconds: 1)),
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: '1', child: Text('创建单个商品订单')),
              PopupMenuItem(value: '2', child: Text('创建2个商品一个店铺的订单')),
              PopupMenuItem(value: '3', child: Text('创建3个商品一个店铺的订单')),
            ],
          ),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('订单已按创建时间自动排序，新订单在最上方'),
                    duration: Duration(seconds: 1)),
              );
            },
            child: const Text(
              '按创建时间排序中',
              style: TextStyle(color: Color(0xFFff5000), fontSize: 13),
            ),
          ),
        ],
      ),
      body: shops.isEmpty
          ? const Center(
              child: Text('暂无订单', style: AppTextStyles.middleSub))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: shops.length,
              itemBuilder: (ctx, i) => _ShopTile(shop: shops[i]),
            ),
    );
  }
}

class _ShopTile extends StatelessWidget {
  final ShoppingCartShop shop;

  const _ShopTile({required this.shop});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<CartProvider>();
    final item = shop.items.isNotEmpty ? shop.items.first : null;

    return Slidable(
      key: ValueKey(shop.hashCode),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.22,
        children: [
          CustomSlidableAction(
            onPressed: (_) {
              provider.removeShop(shop);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('订单已删除'),
                    duration: Duration(seconds: 1)),
              );
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: 22),
                SizedBox(height: 2),
                Text('删除', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (item != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AppImage(url: item.imageUrl, width: 60, height: 60),
              ),
            if (item != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shop.shopName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.smallBold),
                  const SizedBox(height: 4),
                  if (item != null)
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.minSub),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('状态：${shop.orderSubStatus}',
                          style: AppTextStyles.min),
                      const Spacer(),
                      Text(
                        item?.createTime ?? '',
                        style: AppTextStyles.minSub,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
