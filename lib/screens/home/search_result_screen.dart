import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/product_card.dart';

/// 搜索结果页（列表/网格切换 + 筛选）
class SearchResultScreen extends StatefulWidget {
  final String keyword;

  const SearchResultScreen({super.key, required this.keyword});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  bool _isGrid = true;
  int _sortIndex = 0;
  final List<String> _sorts = ['综合', '销量', '价格', '筛选'];

  List<SearchResultItem> get _results => MockData.guessLikeGoods;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.searchBarBg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(AppIcons.search,
                  color: AppColors.searchBarText, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.keyword,
                  style: AppTextStyles.small,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消',
                style: TextStyle(color: Colors.black, fontSize: 15)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSortBar(),
          Expanded(
            child: _isGrid ? _buildGrid() : _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_sorts.length, (index) {
                final active = _sortIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _sortIndex = index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _sorts[index],
                      style: TextStyle(
                        fontSize: 14,
                        color: active ? AppColors.primary : Colors.black87,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          // 列表/网格切换
          IconButton(
            icon: Icon(
              _isGrid ? AppIcons.list : AppIcons.cascades,
              color: Colors.black87,
              size: 20,
            ),
            onPressed: () => setState(() => _isGrid = !_isGrid),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.62,
      ),
      itemCount: _results.length,
      itemBuilder: (context, index) => ProductCard(item: _results[index]),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) => ProductRow(item: _results[index]),
    );
  }
}
