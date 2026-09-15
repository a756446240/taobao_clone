import 'package:flutter/material.dart';

import '../cart/cart_screen.dart';
import '../home/home_screen.dart';
import '../message/message_screen.dart';
import '../mine/mine_screen.dart';
import '../weitao/weitao_screen.dart';

/// 主容器：底部导航 5 大 Tab（全新架构用 IndexedStack 保持页面状态）
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  /// 懒加载：只构建访问过的 tab，避免启动时构建全部页面导致白屏/崩溃
  final List<Widget?> _pages = List.filled(5, null);
  final Set<int> _visited = {0};

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const WeitaoScreen();
      case 2:
        return const MessageScreen();
      case 3:
        return const CartScreen();
      case 4:
        return const MineScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(5, (i) {
          if (_visited.contains(i)) {
            _pages[i] ??= _buildPage(i);
            return _pages[i]!;
          }
          return const SizedBox.shrink();
        }),
      ),
      // v1.9.123：底栏按真实淘宝重做——图标全部换真淘宝截图抠取的高清贴图
      // （132px 透明画布），未激活黑线 / 激活橙色
      // v1.9.128：角标对齐 13:16 真淘宝截图——消息挂 72（硬编码，同 ⋯67 先例），
      // 购物车无角标（真淘宝截图该位置无角标，原 selectedCount 动态角标移除）
      // v1.9.129：图标从截图抠图 PNG 改为 CustomPainter 矢量绘制——抠图放大后
      // 像素感强、有黑边和像素噪点（用户 22:33 截图点名），矢量任何分辨率都锐利
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF0F0F0), width: 0.5),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 50,
            child: Row(
              children: [
                _tab(0, 'home', '首页'),
                _tab(1, 'video', '视频'),
                _tab(2, 'msg', '消息', badge: 72),
                _tab(3, 'cart', '购物车'),
                _tab(4, 'mine', '我的淘宝'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 单个 Tab：25px 矢量图标 + 10px 标签（激活橙色）
  Widget _tab(int index, String iconName, String label, {int badge = 0}) {
    final active = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() {
          _currentIndex = index;
          _visited.add(index);
        }),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CustomPaint(
                  size: const Size(25, 25),
                  painter: _TabIconPainter(iconName, active),
                ),
                if (badge > 0)
                  Positioned(
                    right: -12,
                    top: -5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5000),
                        borderRadius: BorderRadius.circular(9),
                        border:
                            Border.all(color: Colors.white, width: 1),
                      ),
                      constraints: const BoxConstraints(minWidth: 17),
                      child: Text(
                        badge > 99 ? '99+' : '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active
                    ? const Color(0xFFFF5000)
                    : const Color(0xFF1A1A1A),
                fontWeight:
                    active ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// v1.9.129：底栏矢量图标——按真淘宝造型手绘（房子/播放框/气泡三点/
/// 购物车/笑脸），未激活 #1F1F1F 线稿，激活橙 #FF5000（我的淘宝为
/// 橙底白笑脸实心，与真淘宝激活态一致）
class _TabIconPainter extends CustomPainter {
  final String name;
  final bool active;

  _TabIconPainter(this.name, this.active);

  static const _orange = Color(0xFFFF5000);
  static const _dark = Color(0xFF1F1F1F);

  @override
  void paint(Canvas canvas, Size size) {
    final color = active ? _orange : _dark;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    switch (name) {
      case 'home':
        // 屋顶 + 带门洞的房身
        final house = Path()
          ..moveTo(w * 0.5, h * 0.08)
          ..lineTo(w * 0.94, h * 0.46)
          ..lineTo(w * 0.82, h * 0.46)
          ..lineTo(w * 0.82, h * 0.88)
          ..quadraticBezierTo(
              w * 0.82, h * 0.94, w * 0.76, h * 0.94)
          ..lineTo(w * 0.24, h * 0.94)
          ..quadraticBezierTo(
              w * 0.18, h * 0.94, w * 0.18, h * 0.88)
          ..lineTo(w * 0.18, h * 0.46)
          ..lineTo(w * 0.06, h * 0.46)
          ..close();
        if (active) {
          canvas.drawPath(house, fill);
          // 门洞留白
          final door = Paint()..color = Colors.white;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(
                  w * 0.42, h * 0.62, w * 0.58, h * 0.94),
              const Radius.circular(1.5),
            ),
            door,
          );
        } else {
          canvas.drawPath(house, stroke);
          canvas.drawLine(
              Offset(w * 0.42, h * 0.94), Offset(w * 0.42, h * 0.64), stroke);
          canvas.drawLine(
              Offset(w * 0.42, h * 0.64), Offset(w * 0.58, h * 0.64), stroke);
          canvas.drawLine(
              Offset(w * 0.58, h * 0.64), Offset(w * 0.58, h * 0.94), stroke);
        }
        break;
      case 'video':
        // 圆角播放框 + 实心三角
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.10, h * 0.18, w * 0.90, h * 0.82),
          Radius.circular(w * 0.18),
        );
        canvas.drawRRect(rect, stroke);
        final tri = Path()
          ..moveTo(w * 0.43, h * 0.36)
          ..lineTo(w * 0.66, h * 0.50)
          ..lineTo(w * 0.43, h * 0.64)
          ..close();
        canvas.drawPath(tri, fill);
        break;
      case 'msg':
        // 圆角气泡 + 左下小尾巴 + 横向三点
        final bubble = RRect.fromRectAndRadius(
          Rect.fromLTRB(w * 0.10, h * 0.12, w * 0.90, h * 0.68),
          Radius.circular(w * 0.28),
        );
        canvas.drawRRect(bubble, stroke);
        final tail = Path()
          ..moveTo(w * 0.28, h * 0.66)
          ..quadraticBezierTo(
              w * 0.26, h * 0.86, w * 0.16, h * 0.94)
          ..quadraticBezierTo(
              w * 0.32, h * 0.90, w * 0.40, h * 0.70);
        canvas.drawPath(tail, stroke);
        for (final dx in [0.32, 0.50, 0.68]) {
          canvas.drawCircle(
              Offset(w * dx, h * 0.40), w * 0.055, fill);
        }
        break;
      case 'cart':
        // 拉杆 + 篮筐 + 双轮
        final basket = Path()
          ..moveTo(w * 0.06, h * 0.16)
          ..lineTo(w * 0.18, h * 0.16)
          ..lineTo(w * 0.26, h * 0.60)
          ..quadraticBezierTo(
              w * 0.28, h * 0.68, w * 0.36, h * 0.68)
          ..lineTo(w * 0.78, h * 0.68)
          ..quadraticBezierTo(
              w * 0.86, h * 0.68, w * 0.87, h * 0.60)
          ..lineTo(w * 0.94, h * 0.30)
          ..lineTo(w * 0.22, h * 0.30);
        canvas.drawPath(basket, stroke);
        canvas.drawCircle(Offset(w * 0.38, h * 0.84), w * 0.06, fill);
        canvas.drawCircle(Offset(w * 0.72, h * 0.84), w * 0.06, fill);
        break;
      case 'mine':
        // 笑脸：未激活线圈+深色五官；激活橙底白五官
        final center = Offset(w * 0.5, h * 0.5);
        if (active) {
          canvas.drawCircle(center, w * 0.44, fill);
          final white = Paint()..color = Colors.white;
          canvas.drawCircle(
              Offset(w * 0.37, h * 0.40), w * 0.05, white);
          canvas.drawCircle(
              Offset(w * 0.63, h * 0.40), w * 0.05, white);
          final smileStroke = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.7
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
            Rect.fromCenter(
                center: Offset(w * 0.5, h * 0.52),
                width: w * 0.44,
                height: h * 0.40),
            0.25 * 3.14159,
            0.5 * 3.14159,
            false,
            smileStroke,
          );
        } else {
          canvas.drawCircle(center, w * 0.44, stroke);
          canvas.drawCircle(
              Offset(w * 0.37, h * 0.40), w * 0.05, fill);
          canvas.drawCircle(
              Offset(w * 0.63, h * 0.40), w * 0.05, fill);
          canvas.drawArc(
            Rect.fromCenter(
                center: Offset(w * 0.5, h * 0.52),
                width: w * 0.44,
                height: h * 0.40),
            0.25 * 3.14159,
            0.5 * 3.14159,
            false,
            stroke,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_TabIconPainter old) =>
      old.name != name || old.active != active;
}
