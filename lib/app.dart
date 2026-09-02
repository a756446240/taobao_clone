import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'screens/main/main_shell.dart';

/// 应用根组件（主题 + 路由）
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '淘宝',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: AppColors.primarySwatch,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFfafafa),
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Color(0xFF585858),
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const MainShell(),
    );
  }
}
