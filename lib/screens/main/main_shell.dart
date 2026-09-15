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
      // v1.9.130：矢量手绘路线被否（用户要「拉高清不是换了」）——原抠图 PNG
      // 走清洗流水线（去噪点/黑边 + 4x 超采样高斯平滑 + 纯色重填 #373737/#FA5D00），
      // 保真淘宝原始造型，恢复 Image.asset 贴图
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
                _tab(0, 'tab_home', '首页'),
                _tab(1, 'tab_video', '视频'),
                _tab(2, 'tab_msg', '消息', badge: 72),
                _tab(3, 'tab_cart', '购物车'),
                _tab(4, 'tab_mine', '我的淘宝'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 单个 Tab：25px 贴图图标（384px 清洗版）+ 10px 标签（激活橙色）
  Widget _tab(int index, String iconName, String label, {int badge = 0}) {
    final active = _currentIndex == index;
    final asset = active
        ? 'assets/images/tabbar/${iconName}_active.png'
        : 'assets/images/tabbar/$iconName.png';
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
                Image.asset(
                  asset,
                  height: 25,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.circle_outlined,
                    size: 24,
                    color: active
                        ? const Color(0xFFFF5000)
                        : Colors.black87,
                  ),
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
