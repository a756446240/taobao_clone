import 'package:flutter/material.dart';

import '../models/models.dart';

/// 店铺类型徽章：天猫(红) / 淘宝(橙) / 国际(紫)
/// 购物车、订单列表等处统一使用，保证样式一致。
class ShopTypeBadge extends StatelessWidget {
  final ShoppingCartShop shop;
  final double fontSize;

  const ShopTypeBadge({super.key, required this.shop, this.fontSize = 10});

  /// 可编辑的三类店铺类型
  static const List<String> typeOptions = ['天猫', '淘宝', '国际'];

  /// 推导徽章文字与颜色
  static ({String text, Color color}) resolve(ShoppingCartShop shop) {
    if (shop.isInternational || shop.shopBadge == '国际') {
      return (text: '国际', color: const Color(0xFF7C4DFF));
    }
    if (shop.shopBadge == '淘宝') {
      return (text: '淘宝', color: const Color(0xFFFF5000));
    }
    if (shop.shopBadge == '天猫') {
      return (text: '天猫', color: const Color(0xFFFF0036));
    }
    // 未显式设置时按 ShopType 兜底（生成器默认 tianMao）
    if (shop.shopType == ShopType.taoBao) {
      return (text: '淘宝', color: const Color(0xFFFF5000));
    }
    return (text: '天猫', color: const Color(0xFFFF0036));
  }

  @override
  Widget build(BuildContext context) {
    final badge = resolve(shop);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: badge.color, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badge.text,
        style: TextStyle(
          color: badge.color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
