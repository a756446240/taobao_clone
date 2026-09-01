import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'search_result_screen.dart';
import 'search_screen.dart';

/// 分类页（淘宝经典布局：左侧类目轨 + 右侧子类网格）
/// 子类点击进入搜索结果页
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  /// 一级类目 → 二级子类
  static const _categories = <String, List<String>>{
    '热门推荐': ['连衣裙', '手机', '零食', '口红', '运动鞋', '耳机', '洗衣液', '纸巾', '保温杯'],
    '手机数码': ['手机', '耳机', '平板电脑', '智能手表', '充电宝', '数据线', '手机壳', '键盘', '鼠标'],
    '品质女装': ['连衣裙', 'T恤', '衬衫', '牛仔裤', '半身裙', '卫衣', '风衣', '羽绒服', '针织衫'],
    '潮流男装': ['T恤', '衬衫', '夹克', '牛仔裤', '休闲裤', '卫衣', '西装', 'POLO衫', '短裤'],
    '美妆护肤': ['口红', '面膜', '精华液', '粉底液', '防晒霜', '洗面奶', '眼影', '香水', '乳液'],
    '食品生鲜': ['零食', '坚果', '水果', '牛奶', '方便面', '饼干', '巧克力', '茶叶', '咖啡'],
    '家用电器': ['空调', '冰箱', '洗衣机', '电饭煲', '吹风机', '扫地机器人', '加湿器', '电风扇', '微波炉'],
    '运动户外': ['跑步鞋', '瑜伽垫', '哑铃', '帐篷', '自行车', '羽毛球拍', '游泳装备', '健身器材', '运动服'],
    '母婴用品': ['奶粉', '纸尿裤', '婴儿车', '积木玩具', '童装', '奶瓶', '儿童图书', '滑板车', '安抚玩偶'],
    '家居家装': ['四件套', '窗帘', '收纳箱', '台灯', '沙发', '餐桌', '地毯', '衣架', '拖把'],
  };

  /// 子类徽标配色盘（按名称哈希取色，稳定）
  static const _palette = [
    0xFFFF5000, 0xFF2B6DEF, 0xFF22C55E, 0xFFA855F7,
    0xFFF7B500, 0xFFEF4444, 0xFF06B6D4, 0xFFE11D74,
  ];

  int _selected = 0;

  Color _colorOf(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return Color(_palette[h % _palette.length]);
  }

  @override
  Widget build(BuildContext context) {
    final names = _categories.keys.toList();
    final current = names[_selected];
    final subs = _categories[current]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        titleSpacing: 0,
        title: GestureDetector(
          // 单击进入搜索页
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SearchScreen()),
          ),
          child: Container(
            height: 34,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.searchBarBg,
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Row(
              children: [
                SizedBox(width: 12),
                Icon(Icons.search,
                    color: AppColors.searchBarText, size: 18),
                SizedBox(width: 6),
                Text('搜索你想要的宝贝',
                    style: TextStyle(
                        color: AppColors.searchBarText, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧类目轨
          SizedBox(
            width: 88,
            child: ColoredBox(
              color: const Color(0xFFF5F5F5),
              child: ListView.builder(
                itemCount: names.length,
                itemBuilder: (ctx, i) {
                  final active = i == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = i),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : null,
                        border: active
                            ? const Border(
                                left: BorderSide(
                                    color: AppColors.primary, width: 3))
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(names[i],
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: active
                                  ? AppColors.primary
                                  : Colors.black87)),
                    ),
                  );
                },
              ),
            ),
          ),
          // 右侧内容区
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // 类目头
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.primary.withValues(alpha: 0.04),
                    ]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(current,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('共 ${subs.length} 个子类',
                          style: AppTextStyles.min
                              .copyWith(color: AppColors.subText)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text('热门分类',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                // 子类 3 列网格
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.86,
                  children: subs.map(_buildSubItem).toList(),
                ),
                const SizedBox(height: 18),
                const Text('大家都在搜',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                // 热搜 chips（倒序轮换，与网格不重样）
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in subs.reversed.take(6))
                      GestureDetector(
                        onTap: () => _gotoResult(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(s,
                              style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem(String name) {
    final color = _colorOf(name);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _gotoResult(name),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(name[0],
                style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 5),
          Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _gotoResult(String keyword) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => SearchResultScreen(keyword: keyword)),
    );
  }
}
