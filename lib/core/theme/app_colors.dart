import 'package:flutter/material.dart';

/// 全局颜色定义（全新架构，集中管理主题色）
class AppColors {
  AppColors._();

  /// 淘宝主色（标准橘 #FF5000，与应用图标底色一致）
  static const Color primary = Color(0xFFff5000);

  /// 主色 Material 色板
  static const MaterialColor primarySwatch = MaterialColor(
    0xFFff5000,
    <int, Color>{
      50: Color(0xFFff5000),
      100: Color(0xFFff5000),
      200: Color(0xFFff5000),
      300: Color(0xFFff5000),
      400: Color(0xFFff5000),
      500: Color(0xFFff5000),
      600: Color(0xFFff5000),
      700: Color(0xFFff5000),
      800: Color(0xFFff5000),
      900: Color(0xFFff5000),
    },
  );

  /// 页面主背景（浅灰）
  static const Color background = Color(0xFFf1f2f1);

  /// 底部导航默认前景色
  static const Color tabBarDefault = Color(0xFF8e8e8e);

  /// 价格红
  static const Color price = Color(0xFFb60909);

  /// 次要文字
  static const Color subText = Color(0xFF959595);
  static const Color subLightText = Color(0xFFc4c4c4);

  /// 搜索框背景 / 文字
  static const Color searchBarBg = Color(0xFFf0f0f0);
  static const Color searchBarText = Color(0xFFcdcdcd);

  /// 分割线
  static const Color divider = Color(0xFFf5f5f5);

  /// 购物车禁用
  static const Color cartDisable = Color(0xFFdddddd);

  /// 主题色（参考项目中的深棕，用于部分按钮背景）
  static const Color theme = Color(0xFF845f3f);

  /// 白色
  static const Color white = Colors.white;

  /// 主渐变（用于按钮、标签）
  static const Gradient primaryGradient =
      LinearGradient(colors: [Colors.orange, Colors.deepOrange]);
}
