import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../providers/footprints_provider.dart';
import '../../widgets/app_image.dart';
import '../product/product_detail_screen.dart';

/// 淘宝式我的足迹页：真实浏览历史按日期分组（三列网格）
/// 进商品详情页即记录（FootprintsProvider 持久化），可一键清空
class FootprintsScreen extends StatefulWidget {
  const FootprintsScreen({super.key});

  @override
  State<FootprintsScreen> createState() => _FootprintsScreenState();
}

class _FootprintsScreenState extends State<FootprintsScreen> {
  /// 把记录按 今天/昨天/更早 分组（保持时间倒序）
  Map<String, List<SearchResultItem>> _group(List<Footprint> records) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final groups = <String, List<SearchResultItem>>{
      '今天': [],
      '昨天': [],
      '更早': [],
    };
    for (final r in records) {
      final t = DateTime.fromMillisecondsSinceEpoch(r.ts);
      if (!t.isBefore(todayStart)) {
        groups['今天']!.add(r.item);
      } else if (!t.isBefore(yesterdayStart)) {
        groups['昨天']!.add(r.item);
      } else {
        groups['更早']!.add(r.item);
      }
    }
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FootprintsProvider>();
    final groups = _group(provider.records);
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
        actions: [
          if (provider.records.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('清空足迹？',
                        style: TextStyle(fontSize: 16)),
                    content: const Text('将删除全部浏览记录，不可恢复'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('取消')),
                      TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('清空',
                              style:
                                  TextStyle(color: Color(0xFFA32D2D)))),
                    ],
                  ),
                );
                if (ok == true) provider.clear();
              },
              child: const Text('清空',
                  style: TextStyle(color: Color(0xFF999999), fontSize: 13)),
            ),
        ],
      ),
      body: groups.isEmpty
          ? const Center(
              child: Text('还没有浏览记录\n去首页逛逛吧',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final e in groups.entries)
                  _dateSection(e.key, e.value),
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
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(item: g)),
      ),
      child: Container(
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
      ),
    );
  }
}
