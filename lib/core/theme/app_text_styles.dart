import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 全局字体样式（全新架构，集中管理文本样式）
class AppTextStyles {
  AppTextStyles._();

  static const double _big = 23;
  static const double _normal = 18;
  static const double _middle = 16;
  static const double _small = 14;
  static const double _min = 12;

  // 应用栏标题
  static const TextStyle appBarTitleWhite =
      TextStyle(fontSize: 18, color: Colors.white);
  static const TextStyle appBarTitleBlack =
      TextStyle(fontSize: 16, color: Colors.black);

  static const TextStyle min = TextStyle(
    color: AppColors.subLightText,
    fontSize: _min,
  );

  /// 12 号灰色副文本（订单/退款详情页使用）
  static const TextStyle minSub = TextStyle(
    color: AppColors.subText,
    fontSize: _min,
  );

  static const TextStyle smallWhite = TextStyle(
    color: Colors.white,
    fontSize: _small,
  );

  static const TextStyle small = TextStyle(
    color: Colors.black,
    fontSize: _small,
  );

  static const TextStyle smallBold = TextStyle(
    color: Colors.black,
    fontSize: _small,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle smallSubLight = TextStyle(
    color: AppColors.subLightText,
    fontSize: _small,
  );

  static const TextStyle smallSub = TextStyle(
    color: AppColors.subText,
    fontSize: _small,
  );

  static const TextStyle middle = TextStyle(
    color: Colors.black,
    fontSize: _middle,
  );

  static const TextStyle middleWhite = TextStyle(
    color: Colors.white,
    fontSize: _middle,
  );

  static const TextStyle middleSub = TextStyle(
    color: AppColors.subText,
    fontSize: _middle,
  );

  static const TextStyle middleBold = TextStyle(
    color: Colors.black,
    fontSize: _middle,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle normal = TextStyle(
    color: Colors.black,
    fontSize: _normal,
  );

  static const TextStyle normalBold = TextStyle(
    color: Colors.black,
    fontSize: _normal,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle normalSub = TextStyle(
    color: AppColors.subText,
    fontSize: _normal,
  );

  static const TextStyle normalWhite = TextStyle(
    color: Colors.white,
    fontSize: _normal,
  );

  static const TextStyle large = TextStyle(
    color: Colors.black,
    fontSize: _big,
  );

  static const TextStyle largeBold = TextStyle(
    color: Colors.black,
    fontSize: _big,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle largeWhite = TextStyle(
    color: Colors.white,
    fontSize: _big,
  );

  static const TextStyle largeWhiteBold = TextStyle(
    color: Colors.white,
    fontSize: _big,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle price = TextStyle(
    color: AppColors.price,
    fontSize: _normal,
    fontWeight: FontWeight.bold,
  );
}
