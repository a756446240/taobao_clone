import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../providers/search_provider.dart';
import 'search_result_screen.dart';

/// 搜索页（搜索历史 + 热搜 + 实时建议）
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 搜索页默认不预填任何关键词，保持搜索框为空白
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String keyword) {
    if (keyword.trim().isEmpty) return;
    context.read<SearchProvider>().add(keyword);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchResultScreen(keyword: keyword)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SearchProvider>().history;
    final suggestions = _controller.text.isNotEmpty
        ? MockData.searchHints
            .where((e) => e.contains(_controller.text))
            .toList()
        : <String>[];

    return Scaffold(
      backgroundColor: Colors.white,
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
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _search,
                  style: AppTextStyles.small,
                  decoration: const InputDecoration(
                    hintText: '搜索你想要的宝贝',
                    hintStyle: TextStyle(
                        color: AppColors.searchBarText, fontSize: 14),
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _search(_controller.text),
            child: const Text('搜索',
                style: TextStyle(color: AppColors.primary, fontSize: 15)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 搜索历史
          if (history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('历史搜索', style: AppTextStyles.middleBold),
                IconButton(
                  icon: const Icon(AppIcons.deleteLight,
                      color: AppColors.subText, size: 20),
                  onPressed: () => context.read<SearchProvider>().clear(),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history.map((e) {
                return GestureDetector(
                  onTap: () => _search(e),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(e, style: AppTextStyles.small),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // 热搜推荐
          Text('热搜推荐', style: AppTextStyles.middleBold),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MockData.searchHints.map((e) {
              return GestureDetector(
                onTap: () => _search(e),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(e, style: AppTextStyles.small),
                ),
              );
            }).toList(),
          ),

          // 实时建议
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...suggestions.map((e) => ListTile(
                  dense: true,
                  leading: const Icon(AppIcons.search,
                      color: AppColors.subText, size: 18),
                  title: Text(e, style: AppTextStyles.small),
                  onTap: () => _search(e),
                )),
          ],
        ],
      ),
    );
  }
}
