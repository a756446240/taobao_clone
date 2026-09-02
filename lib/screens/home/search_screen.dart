import 'dart:math';

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

  /// 热搜榜：从大词库随机抽 10 个，每次进搜索页都不一样
  late List<String> _hotWords =
      ([...MockData.searchHints]..shuffle(Random())).take(10).toList();

  /// 换一批热搜词
  void _reshuffleHot() {
    setState(() {
      _hotWords =
          ([...MockData.searchHints]..shuffle(Random())).take(10).toList();
    });
  }

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

          // 热搜榜（淘宝式双列排行：1-3 名橙序号 + 热/新/爆角标）
          Row(
            children: [
              Text('热搜榜', style: AppTextStyles.middleBold),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EC),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text('实时热点，每分钟更新',
                    style:
                        TextStyle(color: AppColors.primary, fontSize: 10)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _reshuffleHot,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 14, color: Color(0xFF999999)),
                      SizedBox(width: 2),
                      Text('换一换',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF999999))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildHotRank(),

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

  /// 双列热搜排行：左列 1/3/5/7…，右列 2/4/6/8…
  Widget _buildHotRank() {
    final hints = _hotWords;
    const tags = ['热', '新', '爆', '', '热', '', '新', '', '热', ''];
    final half = (hints.length + 1) ~/ 2;
    Widget rankItem(int i) {
      if (i >= hints.length) return const SizedBox.shrink();
      final top3 = i < 3;
      final tag = i < tags.length ? tags[i] : '';
      return GestureDetector(
        onTap: () => _search(hints[i]),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: top3
                            ? AppColors.primary
                            : const Color(0xFF999999))),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(hints[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.small),
              ),
              if (tag.isNotEmpty)
                Text(tag,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: tag == '热'
                            ? const Color(0xFFFF2E4D)
                            : tag == '爆'
                                ? AppColors.primary
                                : const Color(0xFF2B6DEF))),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              for (var i = 0; i < half; i++) rankItem(i),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              for (var i = half; i < hints.length; i++) rankItem(i),
            ],
          ),
        ),
      ],
    );
  }
}
