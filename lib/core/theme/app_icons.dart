import 'package:flutter/material.dart';

/// 自定义图标字体（复用淘宝 iconfont）
class AppIcons {
  AppIcons._();

  static const String fontFamily = 'TaobaoIconFont';
  static const String weixinFontFamily = 'WeixinIconFont';

  // 底部导航
  static const IconData home = IconData(0xe6b8, fontFamily: fontFamily);
  static const IconData homeActive = IconData(0xe652, fontFamily: fontFamily);
  static const IconData weTao = IconData(0xe6f5, fontFamily: fontFamily);
  static const IconData weTaoFill = IconData(0xe6f4, fontFamily: fontFamily);
  static const IconData message = IconData(0xe6bc, fontFamily: fontFamily);
  static const IconData messageFill = IconData(0xe779, fontFamily: fontFamily);
  static const IconData cart = IconData(0xe6af, fontFamily: fontFamily);
  static const IconData cartFill = IconData(0xe6b9, fontFamily: fontFamily);
  static const IconData my = IconData(0xe78b, fontFamily: fontFamily);
  static const IconData myFill = IconData(0xe78c, fontFamily: fontFamily);

  // 顶部搜索栏
  static const IconData scan = IconData(0xe672, fontFamily: fontFamily);
  static const IconData search = IconData(0xe7da, fontFamily: fontFamily);
  static const IconData camera = IconData(0xe665, fontFamily: fontFamily);
  static const IconData qrCode = IconData(0xe6b0, fontFamily: fontFamily);
  static const IconData deleteLight = IconData(0xe7ed, fontFamily: fontFamily);
  static const IconData backLight = IconData(0xe7e0, fontFamily: fontFamily);

  // 消息相关
  static const IconData notification = IconData(0xe66b, fontFamily: fontFamily);
  static const IconData notificationFill =
      IconData(0xe66a, fontFamily: fontFamily);
  static const IconData emoji = IconData(0xe64a, fontFamily: fontFamily);
  static const IconData emojiLight = IconData(0xe7a1, fontFamily: fontFamily);
  static const IconData roundAdd = IconData(0xe6d9, fontFamily: fontFamily);
  static const IconData roundAddLight = IconData(0xe7a7, fontFamily: fontFamily);
  static const IconData sound = IconData(0xe77b, fontFamily: fontFamily);
  static const IconData soundLight = IconData(0xe7a8, fontFamily: fontFamily);
  static const IconData friendSettings =
      IconData(0xe7fe, fontFamily: fontFamily);

  // 店铺 / 其他
  static const IconData shop = IconData(0xe676, fontFamily: fontFamily);
  static const IconData shopFill = IconData(0xe697, fontFamily: fontFamily);
  static const IconData shopLight = IconData(0xe7b8, fontFamily: fontFamily);
  static const IconData tmall = IconData(0xe65a, fontFamily: fontFamily);

  // 关注 / 点赞
  static const IconData attentionLight =
      IconData(0xe7f4, fontFamily: fontFamily);
  static const IconData attentionForbid =
      IconData(0xe7b2, fontFamily: fontFamily);
  static const IconData appreciateLight =
      IconData(0xe7e1, fontFamily: fontFamily);
  static const IconData appreciateFillLight =
      IconData(0xe7e2, fontFamily: fontFamily);
  static const IconData commentLight =
      IconData(0xe7e3, fontFamily: fontFamily);
  static const IconData commentFillLight =
      IconData(0xe7e4, fontFamily: fontFamily);
  static const IconData peopleList = IconData(0xe7db, fontFamily: fontFamily);

  // 工具
  static const IconData video = IconData(0xe7c8, fontFamily: fontFamily);
  static const IconData cascades = IconData(0xe67c, fontFamily: fontFamily);
  static const IconData list = IconData(0xe682, fontFamily: fontFamily);
  static const IconData filter = IconData(0xe69c, fontFamily: fontFamily);
  static const IconData jump = IconData(0xe670, fontFamily: fontFamily);
  static const IconData time = IconData(0xe65f, fontFamily: fontFamily);
  static const IconData timeFill = IconData(0xe65e, fontFamily: fontFamily);
  static const IconData addLight = IconData(0xe7dc, fontFamily: fontFamily);
  static const IconData clear = IconData(0xe601, fontFamily: fontFamily);
  static const IconData deliverFill = IconData(0xe7f6, fontFamily: fontFamily);
}
