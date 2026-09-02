import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/cart_provider.dart';
import '../../providers/follow_shops_provider.dart';
import '../../widgets/app_image.dart';
import 'live_list_screen.dart';

/// 模拟直播间：全屏封面 + 主播卡 + 评论互动 + 讲解中商品卡（可真实加购）
class LiveRoomScreen extends StatefulWidget {
  final LiveRoom room;
  const LiveRoomScreen({super.key, required this.room});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  int _likes = 0;
  final _commentCtrl = TextEditingController();

  /// 初始弹幕/评论（进场欢迎 + 互动问答）
  late final List<String> _comments = [
    '系统：欢迎来到 ${widget.room.anchor} 的直播间',
    '淘友**酱：主播这个有优惠吗',
    '爱**猫：已拍两件，坐等收货',
    '山**风：质量怎么样呀',
    '系统：${widget.room.anchor} 正在讲解「${widget.room.goodsTitle}」',
  ];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    // 关注状态全局化：读写 FollowShopsProvider，与店铺主页/关注列表同步
    final followed =
        context.watch<FollowShopsProvider>().isFollowed(room.anchor);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 全屏封面（模拟视频画面）
          Positioned.fill(
            child: AppImage(url: room.cover, fit: BoxFit.cover),
          ),
          // 上下渐变罩层
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.0, 0.22, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 顶部：主播卡 + 观看 + 关闭
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.primary,
                              child: Text(room.anchor[0],
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(room.anchor,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight:
                                            FontWeight.bold)),
                                Text('${room.viewersText}观看',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.8),
                                        fontSize: 9)),
                              ],
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context
                                  .read<FollowShopsProvider>()
                                  .toggle(room.anchor),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4),
                                decoration: BoxDecoration(
                                  color: followed
                                      ? Colors.white
                                          .withValues(alpha: 0.25)
                                      : AppColors.primary,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Text(
                                    followed ? '已关注' : '+关注',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight:
                                            FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 24),
                        onPressed: () =>
                            Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // 评论区（最近 5 条）
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.72,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in _comments.reversed.take(5).toList().reversed)
                          Container(
                            margin:
                                const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black
                                  .withValues(alpha: 0.35),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: Text(c,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    height: 1.3)),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 讲解中商品卡
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: AppImage(
                              url: room.cover,
                              width: 48,
                              height: 48),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(room.goodsTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.smallBold),
                              const SizedBox(height: 2),
                              Text('直播价 ¥${room.goodsPrice}',
                                  style: AppTextStyles.price
                                      .copyWith(fontSize: 14)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: _buyGoods,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF5000),
                                    Color(0xFFFF2E4D),
                                  ]),
                              borderRadius:
                                  BorderRadius.circular(16),
                            ),
                            child: const Text('去购买',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // 底部输入行：评论 + 点赞
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(18),
                          ),
                          alignment: Alignment.centerLeft,
                          child: TextField(
                            controller: _commentCtrl,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12),
                            decoration: const InputDecoration(
                              hintText: '说点什么...',
                              hintStyle: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                            onSubmitted: _sendComment,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => setState(() => _likes++),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                _likes > 0
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: const Color(0xFFFF2D55),
                                size: 26),
                            if (_likes > 0)
                              Text('$_likes',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendComment(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _comments.add('我：${text.trim()}');
      _commentCtrl.clear();
    });
  }

  void _buyGoods() {
    final room = widget.room;
    context.read<CartProvider>().addToCart(
          shopName: '${room.anchor}的直播间',
          title: room.goodsTitle,
          price: room.goodsPrice,
          imageUrl: room.cover,
          spec: '直播间专享',
          quantity: 1,
        );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('已加入购物车，去购物车结算吧'),
        duration: Duration(seconds: 1),
      ));
  }
}
