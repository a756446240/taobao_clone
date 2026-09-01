import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/models.dart';
import '../providers/product_image_provider.dart';
import 'app_image.dart';
import 'image_picker_helper.dart';

/// 商品卡片（双列网格，用于猜你喜欢 / 搜索结果）
/// 点击商品图可从相册选择图片替换，替换结果持久化保存。
class ProductCard extends StatelessWidget {
  final SearchResultItem item;

  const ProductCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // 监听替换结果，实时刷新
    final overrideUrl =
        context.watch<ProductImageProvider>().imageFor(item.title);
    final imageUrl = overrideUrl ?? item.imageUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onDoubleTap: () => pickProductImageFromGallery(context, item.title),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: const Color(0xFFF0F0F0), width: 1),
                ),
                child: imageUrl.isEmpty
                    ? _buildPlaceholder(item.shopName)
                    : AppImage(url: imageUrl, fit: BoxFit.cover),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('¥', style: AppTextStyles.price.copyWith(fontSize: 12)),
                    Text(item.price, style: AppTextStyles.price),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.commentCount,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.min,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.min.copyWith(color: AppColors.subText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 智能占位：根据 shopName 选 icon 和背景色
  Widget _buildPlaceholder(String shopName) {
    IconData icon = Icons.shopping_bag;
    Color bg = const Color(0xFF8e8e8e);
    if (shopName.contains('立白') || shopName.contains('洗')) {
      icon = Icons.local_laundry_service;
      bg = const Color(0xFF26a69a);
    } else if (shopName.contains('SAH') ||
        shopName.contains('Swisse') ||
        shopName.contains('保健') ||
        shopName.contains('健康') ||
        shopName.contains('胶原') ||
        shopName.contains('护肝')) {
      icon = Icons.spa;
      bg = const Color(0xFF66bb6a);
    } else if (shopName.contains('蒙牛') || shopName.contains('奶')) {
      icon = Icons.local_drink;
      bg = const Color(0xFFffa726);
    } else if (shopName.contains('太太乐') || shopName.contains('鸡')) {
      icon = Icons.restaurant;
      bg = const Color(0xFFef5350);
    } else if (shopName.contains('江中') ||
        shopName.contains('药') ||
        shopName.contains('消食')) {
      icon = Icons.medication;
      bg = const Color(0xFF42a5f5);
    } else if (shopName.contains('海外')) {
      icon = Icons.public;
      bg = const Color(0xFF5c6bc0);
    } else if (shopName.contains('旗舰店')) {
      icon = Icons.storefront;
      bg = AppColors.primary;
    }
    return Container(
      color: bg,
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: 56),
    );
  }
}

/// 商品行（单列，用于搜索结果列表模式）
class ProductRow extends StatelessWidget {
  final SearchResultItem item;

  const ProductRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final overrideUrl =
        context.watch<ProductImageProvider>().imageFor(item.title);
    final imageUrl = overrideUrl ?? item.imageUrl;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onDoubleTap: () => pickProductImageFromGallery(context, item.title),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                    color: const Color(0xFFF0F0F0), width: 1),
              ),
              child: AppImage(url: imageUrl, width: 100, height: 100),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.small,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('¥', style: AppTextStyles.price.copyWith(fontSize: 13)),
                    Text(item.price, style: AppTextStyles.price),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.commentCount}  ${item.goodRate}',
                  style: AppTextStyles.min,
                ),
                const SizedBox(height: 4),
                Text(
                  item.shopName,
                  style: AppTextStyles.min.copyWith(color: AppColors.subText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
