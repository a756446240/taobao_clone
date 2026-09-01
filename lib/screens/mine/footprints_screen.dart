import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/app_image.dart';

/// 淘宝式我的足迹页：按日期分组的浏览历史（三列网格）
class FootprintsScreen extends StatefulWidget {
  const FootprintsScreen({super.key});

  @override
  State<FootprintsScreen> createState() => _FootprintsScreenState();
}

class _FootprintsScreenState extends State<FootprintsScreen> {
  /// 演示数据：今天看过的（前 6 条）/ 昨天看过的（后 4 条）
  late final List<SearchResultItem> _today =
      MockData.guessLikeGoods.take(6).toList();
  late final List<SearchResultItem> _yesterday =
      MockData.guessLikeGoods.skip(6).take(4).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('我的足迹',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _dateSection('今天', _today),
          _dateSection('昨天', _yesterday),
        ],
      ),
    );
  }

  Widget _dateSection(String label, List<SearchResultItem> goods) {
    if (goods.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text('${goods.length} 件宝贝',
                  style: const TextStyle(
                      color: Color(0xFF999999), fontSize: 11)),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemCount: goods.length,
          itemBuilder: (_, i) => _goodsCell(goods[i]),
        ),
      ],
    );
  }

  Widget _goodsCell(SearchResultItem g) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: AppImage(url: g.imageUrl, fit: BoxFit.cover),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, height: 1.25),
                ),
                const SizedBox(height: 4),
                Text('¥${g.price}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
