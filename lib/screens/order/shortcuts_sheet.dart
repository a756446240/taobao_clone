import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../screens/main/main_shell.dart';
import '../message/chat_screen.dart';
import '../mine/favorites_screen.dart';
import '../mine/footprints_screen.dart';
import '../mine/settings_detail_screens.dart';
import 'order_list_screen.dart';

/// v1.9.164 快捷入口面板（对齐真实淘宝截图）：
/// 第一行固定 5 项（消息/回到首页/我的淘宝/购物车/我的订单），
/// 第二行横向滑动（足迹/收藏/专属客服/意见反馈/举报/订单回收站/小调研）。
/// 纯浏览面板——订单列表 ⋯ 直接打开；锁定模式下订单/退款详情 ⋯
/// 也打开此面板（替代编辑菜单，防止误触修改）。
class ShortcutsSheet extends StatelessWidget {
  const ShortcutsSheet({super.key});

  static const _row1 = <(IconData, String, String?)>[
    (Icons.chat_bubble_outline, '消息', '93'),
    (Icons.home_outlined, '回到首页', null),
    (Icons.sentiment_satisfied_alt, '我的淘宝', null),
    (Icons.shopping_cart_outlined, '购物车', null),
    (Icons.receipt_long, '我的订单', null),
  ];

  static const _row2 = <(IconData, String, String?)>[
    (Icons.directions_walk_outlined, '我的足迹', null),
    (Icons.star_border, '我的收藏', '低库存'),
    (Icons.headset_mic_outlined, '专属客服', '88VIP'),
    (Icons.edit_outlined, '意见反馈', null),
    (Icons.report_gmailerrorred_outlined, '举报', null),
    (Icons.delete_outline, '订单回收站', null),
    (Icons.article_outlined, '小调研', null),
  ];

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ));
  }

  /// 关面板 → 回到主界面根 → 切到指定底部 Tab
  void _gotoTab(BuildContext context, int tab) {
    Navigator.of(context).pop();
    MainShell.tabNotifier.value = tab;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// 关面板 → 压新页面
  void _push(BuildContext context, Widget page) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _onTap(BuildContext context, int row, int i) {
    if (row == 1) {
      switch (i) {
        case 0:
          _gotoTab(context, 2); // 消息
          break;
        case 1:
          _gotoTab(context, 0); // 回到首页
          break;
        case 2:
          _gotoTab(context, 4); // 我的淘宝
          break;
        case 3:
          _gotoTab(context, 3); // 购物车
          break;
        default:
          _push(context, const OrderListScreen(type: '全部')); // 我的订单
      }
      return;
    }
    switch (i) {
      case 0:
        _push(context, const FootprintsScreen()); // 我的足迹
        break;
      case 1:
        _push(context, const FavoritesScreen()); // 我的收藏
        break;
      case 2:
        // 专属客服 → 官方客服会话
        _push(
            context,
            ChatScreen(
              conversation: Conversation(
                avatar: '',
                title: '淘宝官方客服',
                description: '专属客服在线',
                createAt: '',
              ),
              accentColor: const Color(0xFFFF5000),
            ));
        break;
      case 3:
        _push(context, const FeedbackScreen()); // 意见反馈
        break;
      default:
        Navigator.of(context).pop();
        _toast(context, _row2[i].$2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上半部分白底图标区：第一行固定 + 第二行横向滑动
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              padding: const EdgeInsets.fromLTRB(8, 22, 8, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildRow(context, _row1, 1),
                  const SizedBox(height: 22),
                  SizedBox(
                    height: 84,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          for (var i = 0; i < _row2.length; i++)
                            _item(context, _row2[i], 2, i),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 取消按钮（灰底胶囊）
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text('取消',
                    style: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
      BuildContext context, List<(IconData, String, String?)> items, int row) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        for (var i = 0; i < items.length; i++) _item(context, items[i], row, i),
      ],
    );
  }

  Widget _item(
      BuildContext context, (IconData, String, String?) it, int row, int i) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(context, row, i),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(it.$1, color: Colors.black87, size: 28),
                if (it.$3 != null)
                  Positioned(
                    right: -14,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5000),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(it.$3!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 9)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(it.$2,
                style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}
