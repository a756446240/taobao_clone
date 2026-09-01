import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/app_image.dart';

/// 淘宝式店铺主页：头部信息卡 + 关注切换 + 精选/上新/热销 Tab + 商品网格
class ShopHomeScreen extends StatefulWidget {
  final String shopName;
  final ShopType shopType;

  const ShopHomeScreen({
    super.key,
    required this.shopName,
    this.shopType = ShopType.tianMao,
  });

  @override
  State<ShopHomeScreen> createState() => _ShopHomeScreenState();
}

class _ShopHomeScreenState extends State<ShopHomeScreen> {
  static const _tabs = ['精选', '上新', '热销'];
  int _tab = 0;
  bool _following = false;

  List<SearchResultItem> get _goods {
    final all = MockData.guessLikeGoods;
    switch (_tab) {
      case 1: // 上新：后段
        return all.skip(all.length > 8 ? all.length - 8 : 0).toList();
      case 2: // 热销：按销量文案粗略排序
        final list = all.toList();
        list.sort((a, b) => b.commentCount.compareTo(a.commentCount));
        return list.take(8).toList();
      default: // 精选：前 8
        return all.take(8).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(widget.shopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildShopHeader(),
          _buildTabs(),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.68,
              ),
              itemCount: _goods.length,
              itemBuilder: (_, i) => _goodsCard(_goods[i]),
            ),
          ),
        ],
      ),
    );
  }

  /// 店铺信息卡：头像 + 店名 + 数据 + 关注按钮
  Widget _buildShopHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E8),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.shopName.isNotEmpty
                  ? widget.shopName.substring(0, 1)
                  : '店',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(widget.shopName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (widget.shopType == ShopType.tianMao) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('天猫',
                            style:
                                TextStyle(color: Colors.white, fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                const Text('12.6万粉丝 · 好评率 98% · 4.9 高分',
                    style:
                        TextStyle(color: Color(0xFF999999), fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _following = !_following),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _following
                    ? const Color(0xFFF5F5F5)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _following ? '已关注' : '+ 关注',
                style: TextStyle(
                    color: _following ? Colors.black54 : Colors.white,
                    fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Row(
        children: [
          for (var i = 0; i < _tabs.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _tabCapsule(_tabs[i], i),
          ],
        ],
      ),
    );
  }

  Widget _tabCapsule(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _goodsCard(SearchResultItem g) {
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
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  g.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('¥${g.price}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(g.commentCount,
                          style: const TextStyle(
                              color: Color(0xFF999999), fontSize: 10),
                          overflow: TextOverflow.ellipsis),
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
}
