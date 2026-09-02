import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../providers/follow_shops_provider.dart';
import '../product/shop_home_screen.dart';

/// 关注店铺列表页（我的页「关注店铺」单击进入，双击仍是 AI 数据校验）
/// 店铺动态流（上新/直播/优惠券/降价）+ 进店 + 关注/取关，数据按店名哈希稳定
class FollowedShopsScreen extends StatefulWidget {
  const FollowedShopsScreen({super.key});

  @override
  State<FollowedShopsScreen> createState() => _FollowedShopsScreenState();
}

class _FollowedShopsScreenState extends State<FollowedShopsScreen> {
  static const _palette = [
    Color(0xFFef5350), Color(0xFFffa726), Color(0xFF66bb6a), Color(0xFF42a5f5),
    Color(0xFFab47bc), Color(0xFF8d6e63), Color(0xFF26c6da), Color(0xFFec407a),
  ];

  static const _shops = [
    ('Lily 官方旗舰店', '时尚女装'),
    ('完美日记官方', '美妆护肤'),
    ('小米官方旗舰店', '数码家电'),
    ('良品铺子官方', '食品保健'),
    ('林氏木业官方', '家居生活'),
    ('巴拉巴拉官方', '母婴亲子'),
    ('华为官方旗舰店', '数码家电'),
    ('花西子官方', '美妆护肤'),
    ('三只松鼠旗舰店', '食品保健'),
    ('顾家家居官方', '家居生活'),
  ];

  static const _updates = [
    '今日上新 12 件，秋冬新品首发',
    '正在直播：爆款专场 5 折起',
    '发放 3 张店铺优惠券，进店可领',
    '5 件商品降价，最高直降 ¥40',
    '会员日预告：周五全场 8.8 折',
  ];

  static const _times = ['10分钟前', '1小时前', '2小时前', '5小时前', '昨天'];

  static int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 全局关注状态：店铺主页关注/取关会实时反映到这里，重启不丢
    final followedNames = context.watch<FollowShopsProvider>().followed;
    final catalog = {for (final s in _shops) s.$1: s.$2};
    final followed = followedNames
        .map((n) => (n, catalog[n] ?? '精选好店'))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    final list = _query.isEmpty
        ? followed
        : followed.where((s) => s.$1.contains(_query)).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title:
            const Text('关注的店铺', style: AppTextStyles.appBarTitleBlack),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(followed.length),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('没有找到相关店铺',
                        style: AppTextStyles.middleSub))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _buildShopCard(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // ============ 搜索栏 ============
  Widget _buildSearchBar(int count) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: '搜索已关注的店铺',
                hintStyle: AppTextStyles.smallSubLight,
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: AppColors.subLightText),
                filled: true,
                fillColor: AppColors.searchBarBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('共$count家', style: AppTextStyles.minSub),
        ],
      ),
    );
  }

  // ============ 店铺卡 ============
  Widget _buildShopCard((String, String) shop) {
    final h = _hash(shop.$1);
    final fans = 1 + h % 900; // 万
    final update = _updates[h % _updates.length];
    final time = _times[h % _times.length];
    final isLive = update.contains('直播');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _palette[h % _palette.length],
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(shop.$1.substring(0, 1),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(shop.$1,
                              style: AppTextStyles.smallBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(shop.$2,
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('$fans万粉丝', style: AppTextStyles.minSub),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _toggleFollow(shop.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.cartDisable),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('已关注',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.subText)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopHomeScreen(
                      shopName: shop.$1,
                      shopType: h % 2 == 0
                          ? ShopType.tianMao
                          : ShopType.taoBao,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('进店',
                      style:
                          TextStyle(fontSize: 11, color: Colors.white)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 店铺最新动态
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                if (isLive)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('LIVE',
                        style: TextStyle(
                            color: Colors.white, fontSize: 9)),
                  ),
                Expanded(
                  child: Text(update,
                      style: AppTextStyles.smallSub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Text(time, style: AppTextStyles.min),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFollow(String name) {
    final provider = context.read<FollowShopsProvider>();
    provider.unfollow(name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已取消关注「$name」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => provider.follow(name),
        ),
      ),
    );
  }
}
