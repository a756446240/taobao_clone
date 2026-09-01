import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_icons.dart';
import '../../providers/cart_provider.dart';
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
    final cartCount = context.watch<CartProvider>().selectedCount;

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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF2F2F2), width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() {
            _currentIndex = index;
            _visited.add(index);
          }),
          elevation: 0,
          backgroundColor: Colors.white,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(AppIcons.home),
              activeIcon: const Icon(AppIcons.homeActive),
              label: '首页',
            ),
            const BottomNavigationBarItem(
              icon: Icon(AppIcons.weTao),
              activeIcon: Icon(AppIcons.weTaoFill),
              label: '视频',
            ),
            const BottomNavigationBarItem(
              icon: Icon(AppIcons.message),
              activeIcon: Icon(AppIcons.messageFill),
              label: '消息',
            ),
            BottomNavigationBarItem(
              icon: _CartIcon(count: cartCount, icon: AppIcons.cart),
              activeIcon: _CartIcon(count: cartCount, icon: AppIcons.cartFill),
              label: '购物车',
            ),
            const BottomNavigationBarItem(
              icon: Icon(AppIcons.my),
              activeIcon: Icon(AppIcons.myFill),
              label: '我的淘宝',
            ),
          ],
        ),
      ),
    );
  }
}

class _CartIcon extends StatelessWidget {
  final int count;
  final IconData icon;

  const _CartIcon({required this.count, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -10,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(9),
              ),
              constraints: const BoxConstraints(minWidth: 16),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }
}
