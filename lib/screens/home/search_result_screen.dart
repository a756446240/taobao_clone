import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/product_card.dart';

/// 搜索结果页（列表/网格切换 + 真实排序 + 筛选抽屉）
class SearchResultScreen extends StatefulWidget {
  final String keyword;

  const SearchResultScreen({super.key, required this.keyword});

  @override
  State<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends State<SearchResultScreen> {
  bool _isGrid = true;
  // 排序：0 综合 / 1 销量 / 2 价格；价格含升降序
  int _sortIndex = 0;
  bool _priceAsc = true;

  // 筛选条件
  int _priceRange = 0; // 0全部 1:0-50 2:50-200 3:200-500 4:500+
  bool _onlyTmall = false;
  bool _onlyFreeShip = false;
  bool _onlyInsurance = false;
  String _shipFrom = ''; // '' = 全部发货地

  /// 从 commentCount 文本估算销量（"已售1万+"→10000，"20万人付款"→200000）
  int _soldOf(SearchResultItem e) {
    final m = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(e.commentCount);
    if (m == null) return 0;
    var n = double.tryParse(m.group(1)!) ?? 0;
    if (e.commentCount.contains('万')) n *= 10000;
    return n.toInt();
  }

  List<SearchResultItem> get _results {
    // 关键词相关结果：真实池匹配优先 + 关键词确定性生成补足（替换原固定商品池）
    var list = MockData.searchGoods(widget.keyword);
    // 筛选：价格区间
    bool inRange(SearchResultItem e) {
      final p = double.tryParse(e.price) ?? 0;
      switch (_priceRange) {
        case 1:
          return p < 50;
        case 2:
          return p >= 50 && p < 200;
        case 3:
          return p >= 200 && p < 500;
        case 4:
          return p >= 500;
        default:
          return true;
      }
    }

    list = list.where(inRange).toList();
    if (_onlyTmall) {
      list = list.where((e) => e.shopName.contains('旗舰')).toList();
    }
    if (_onlyFreeShip) {
      list = list.where(_freeShipOf).toList();
    }
    if (_onlyInsurance) {
      list = list.where(_insuranceOf).toList();
    }
    if (_shipFrom.isNotEmpty) {
      list =
          list.where((e) => MockData.shipFromOf(e) == _shipFrom).toList();
    }
    // 排序
    switch (_sortIndex) {
      case 1:
        list.sort((a, b) => _soldOf(b).compareTo(_soldOf(a)));
        break;
      case 2:
        int cmp(SearchResultItem a, SearchResultItem b) =>
            (double.tryParse(a.price) ?? 0)
                .compareTo(double.tryParse(b.price) ?? 0);
        list.sort((a, b) => _priceAsc ? cmp(a, b) : cmp(b, a));
        break;
    }
    return list;
  }

  /// 标题哈希（项目惯例：确定性假数据，同标题跨页面口径一致）
  static int _hashOf(String s) =>
      s.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);

  /// 是否包邮：约 3/4 商品包邮（确定性）
  static bool _freeShipOf(SearchResultItem e) => _hashOf(e.title) % 4 != 0;

  /// 是否赠退货运费险：约 2/3 商品有（确定性）
  static bool _insuranceOf(SearchResultItem e) => _hashOf(e.title) % 3 != 0;

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
            child: _results.isEmpty
                ? _buildEmpty()
                : (_isGrid ? _buildGrid() : _buildList()),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 56, color: Color(0xFFDDDDDD)),
          const SizedBox(height: 8),
          Text('没有符合筛选条件的宝贝',
              style: AppTextStyles.middleSub),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() {
              _priceRange = 0;
              _onlyTmall = false;
              _onlyFreeShip = false;
              _onlyInsurance = false;
              _shipFrom = '';
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('清除筛选条件',
                  style:
                      TextStyle(color: AppColors.primary, fontSize: 13)),
            ),
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
              children: [
                _sortTab('综合', 0),
                _sortTab('销量', 1),
                _sortTab('价格', 2, arrows: true),
                _filterTab(),
              ],
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

  Widget _sortTab(String label, int index, {bool arrows = false}) {
    final active = _sortIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        if (arrows && _sortIndex == 2) {
          _priceAsc = !_priceAsc; // 已在价格档：切换升降序
        } else {
          _sortIndex = index;
          if (arrows) _priceAsc = true;
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: active ? AppColors.primary : Colors.black87,
                fontWeight:
                    active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (arrows)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_drop_up,
                      size: 14,
                      color: active && _priceAsc
                          ? AppColors.primary
                          : const Color(0xFFBBBBBB)),
                  Icon(Icons.arrow_drop_down,
                      size: 14,
                      color: active && !_priceAsc
                          ? AppColors.primary
                          : const Color(0xFFBBBBBB)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterTab() {
    final hasFilter = _priceRange != 0 ||
        _onlyTmall ||
        _onlyFreeShip ||
        _onlyInsurance ||
        _shipFrom.isNotEmpty;
    return GestureDetector(
      onTap: _openFilterSheet,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(
              '筛选',
              style: TextStyle(
                fontSize: 14,
                color: hasFilter ? AppColors.primary : Colors.black87,
                fontWeight:
                    hasFilter ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            Icon(Icons.filter_list,
                size: 15,
                color: hasFilter
                    ? AppColors.primary
                    : const Color(0xFF999999)),
          ],
        ),
      ),
    );
  }

  // ============ 筛选底部抽屉 ============
  void _openFilterSheet() {
    var range = _priceRange;
    var tmall = _onlyTmall;
    var freeShip = _onlyFreeShip;
    var insurance = _onlyInsurance;
    var shipFrom = _shipFrom;
    const ranges = ['全部', '0-50元', '50-200元', '200-500元', '500元以上'];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Widget chip(String label, bool selected, VoidCallback onTap) {
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFFF1EC)
                        : const Color(0xFFF5F5F5),
                    border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          color: selected
                              ? AppColors.primary
                              : Colors.black87)),
                ),
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text('筛选',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                    const Text('价格区间',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      children: [
                        for (var i = 0; i < ranges.length; i++)
                          chip(ranges[i], range == i,
                              () => setSheet(() => range = i)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('服务与保障',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      children: [
                        chip('天猫旗舰店', tmall,
                            () => setSheet(() => tmall = !tmall)),
                        chip('包邮', freeShip,
                            () => setSheet(() => freeShip = !freeShip)),
                        chip(
                            '退货运费险',
                            insurance,
                            () => setSheet(
                                () => insurance = !insurance)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('发货地',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      children: [
                        chip('全部', shipFrom.isEmpty,
                            () => setSheet(() => shipFrom = '')),
                        for (final city in MockData.shipFromPool)
                          chip(city, shipFrom == city,
                              () => setSheet(() => shipFrom = city)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _priceRange = 0;
                                _onlyTmall = false;
                                _onlyFreeShip = false;
                                _onlyInsurance = false;
                                _shipFrom = '';
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('重置'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary),
                            onPressed: () {
                              setState(() {
                                _priceRange = range;
                                _onlyTmall = tmall;
                                _onlyFreeShip = freeShip;
                                _onlyInsurance = insurance;
                                _shipFrom = shipFrom;
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('完成'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
