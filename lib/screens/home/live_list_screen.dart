import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_image.dart';
import 'live_room_screen.dart';

/// 直播间数据（列表页与房间页共用）
class LiveRoom {
  final String title; // 直播标题
  final String anchor; // 主播名
  final String cover; // 封面 asset
  final int viewers; // 观看人数
  final String goodsTitle; // 讲解中商品
  final double goodsPrice; // 商品价格

  const LiveRoom({
    required this.title,
    required this.anchor,
    required this.cover,
    required this.viewers,
    required this.goodsTitle,
    required this.goodsPrice,
  });

  /// 观看人数文案：1.2万 / 3568
  String get viewersText => viewers >= 10000
      ? '${(viewers / 10000).toStringAsFixed(1)}万'
      : '$viewers';
}

/// 生成 10 个直播间（稳定数据）
List<LiveRoom> buildLiveRooms() {
  const anchors = [
    '桃子酱', '橙子姐', '阿宝优选', '小鹿来了', '元气少女',
    '胖胖测评', '美美搭', '老王说货', '暖暖家', '好物君',
  ];
  const titles = [
    '秋冬新款穿搭专场', '零食狂欢节 全场9.9起', '美妆好物开箱测评',
    '家电焕新季直播中', '母婴好物推荐专场', '运动装备大放价',
    '数码新品首发直播', '家居收纳好物分享', '水果产地直发', '图书文具开学季',
  ];
  const goods = [
    ('慵懒风针织毛衣', 89.0), ('混合坚果大礼包', 29.9), ('保湿修护面膜30片', 49.0),
    ('迷你电饭煲1.2L', 129.0), ('婴儿柔湿巾80抽*6', 39.9), ('缓震跑步鞋', 199.0),
    ('蓝牙降噪耳机', 159.0), ('真空压缩收纳袋', 19.9), ('当季红富士5斤', 25.8),
    ('中性笔套装20支', 15.9),
  ];
  return [
    for (var i = 0; i < 10; i++)
      LiveRoom(
        title: titles[i],
        anchor: anchors[i],
        cover: 'assets/images/remote/r${(38 + i).toString().padLeft(4, '0')}.jpg',
        viewers: 2000 + (i * 13777) % 48000,
        goodsTitle: goods[i].$1,
        goodsPrice: goods[i].$2,
      ),
  ];
}

/// 淘宝直播列表页（首页「淘宝直播/直播有好价」入口）
/// 双列直播卡片：封面 + 直播中角标 + 观看人数 + 主播 + 带货价签
class LiveListScreen extends StatelessWidget {
  const LiveListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rooms = buildLiveRooms();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('淘宝直播',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('${rooms.length} 个直播进行中',
                  style: AppTextStyles.min
                      .copyWith(color: AppColors.subText)),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.68,
        ),
        itemCount: rooms.length,
        itemBuilder: (ctx, i) => _LiveCard(room: rooms[i]),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  final LiveRoom room;
  const _LiveCard({required this.room});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveRoomScreen(room: room)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面 + 角标
            Stack(
              children: [
                AppImage(
                    url: room.cover,
                    width: double.infinity,
                    height: 150),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2D55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow,
                            color: Colors.white, size: 10),
                        Text('直播中',
                            style: TextStyle(
                                color: Colors.white, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text('${room.viewersText}人观看',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.smallBold
                          .copyWith(height: 1.3)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 8,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        child: Text(room.anchor[0],
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 9)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(room.anchor,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.min.copyWith(
                                color: AppColors.subText)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 带货价签
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1EC),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      '讲解中 ¥${room.goodsPrice}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
