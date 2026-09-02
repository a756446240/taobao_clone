import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/app_image.dart';

/// 一个对比单元：商品 + 所属店铺
class CompareEntry {
  final ShoppingCartShop shop;
  final OrderItem item;
  const CompareEntry({required this.shop, required this.item});
}

/// 淘宝式商品对比页：勾选购物车商品后进入，横向多列逐项对比。
/// 价格行自动高亮最低价；包邮/运费险/发货地与搜索筛选同源派生。
class CartCompareScreen extends StatelessWidget {
  final List<CompareEntry> entries;

  const CartCompareScreen({super.key, required this.entries});

  static const _labelW = 64.0;
  static const _colW = 132.0;

  SearchResultItem _asItem(CompareEntry e) => SearchResultItem(
        imageUrl: e.item.imageUrl,
        title: e.item.title,
        shopName: e.shop.shopName,
        price: e.item.price.toStringAsFixed(2),
      );

  double get _minPrice => entries
      .map((e) => e.item.price)
      .fold(double.infinity, (a, b) => b < a ? b : a);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text('商品对比（${entries.length}件）',
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _goodsRow(),
              _row('现价', [
                for (final e in entries)
                  _priceCell(e.item.price,
                      best: e.item.price <= _minPrice),
              ]),
              _row('划线价', [
                for (final e in entries)
                  _textCell(e.item.originalPrice != null
                      ? '¥${e.item.originalPrice!.toStringAsFixed(2)}'
                      : '—')
              ]),
              _row('店铺', [for (final e in entries) _textCell(e.shop.shopName)]),
              _row('发货地', [
                for (final e in entries)
                  _textCell(MockData.shipFromOf(_asItem(e)))
              ]),
              _row('规格', [
                for (final e in entries)
                  _textCell(e.item.configuration.isEmpty
                      ? '默认'
                      : e.item.configuration)
              ]),
              _row('服务', [for (final e in entries) _serviceCell(e)]),
              _row('库存', [
                for (final e in entries) _textCell('${e.item.stock} 件')
              ]),
              _row('数量', [
                for (final e in entries) _textCell('x${e.item.quantity}')
              ]),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// 首行：商品图 + 标题（行首标签列留空对齐）
  Widget _goodsRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: _labelW),
          for (final e in entries)
            SizedBox(
              width: _colW,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: AppImage(
                          url: e.item.imageUrl,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 6),
                    Text(e.item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, List<Widget> cells) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: _labelW,
              alignment: Alignment.center,
              color: const Color(0xFFFAFAFA),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF999999))),
            ),
            for (final c in cells)
              Container(
                width: _colW,
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                      left: BorderSide(
                          color: Color(0xFFF0F0F0), width: 0.5)),
                ),
                child: c,
              ),
          ],
        ),
      ),
    );
  }

  Widget _textCell(String text) => Text(text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12, color: Color(0xFF333333)));

  Widget _priceCell(double price, {bool best = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: best
          ? BoxDecoration(
              color: const Color(0xFFE8F8EE),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF12A150), width: 0.6),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('¥${price.toStringAsFixed(2)}',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: best ? const Color(0xFF12A150) : AppColors.price)),
          if (best)
            const Text('最低价',
                style: TextStyle(fontSize: 9, color: Color(0xFF12A150))),
        ],
      ),
    );
  }

  Widget _serviceCell(CompareEntry e) {
    final item = _asItem(e);
    final tags = <String>[
      if (MockData.isFreeShip(item)) '包邮',
      if (MockData.hasFreightInsurance(item)) '运费险',
    ];
    if (tags.isEmpty) {
      return const Text('—',
          style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB)));
    }
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      alignment: WrapAlignment.center,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
            child:
                Text(t, style: const TextStyle(fontSize: 9, color: AppColors.primary)),
          ),
      ],
    );
  }
}
