import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// v1.9.164 全局锁定开关（设置页「锁定」）：
/// 开启后禁用所有"修改类"入口（双击编辑、编辑菜单、修改按钮等），防止误触；
/// 查看类功能（订单列表/详情/物流/搜索等）不受影响。
///
/// 用法：修改类入口函数第一行加 `if (AppLock.blocked(context)) return;`，
/// 锁定时会弹提示并返回 true；未锁定返回 false 直接放行。
class AppLock {
  AppLock._();

  static const _kKey = 'app_lock_enabled_v1';

  /// 当前是否锁定（main.dart 启动时 load()，设置页切换时 set()）
  static bool enabled = false;

  /// 启动时从持久化读取
  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    enabled = p.getBool(_kKey) ?? false;
  }

  /// 切换并持久化
  static Future<void> set(bool v) async {
    enabled = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kKey, v);
  }

  /// 锁定中 → 弹提示并返回 true（调用方 return 即可）；未锁定返回 false
  static bool blocked(BuildContext context) {
    if (!enabled) return false;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('已锁定，请到「我的淘宝 - 设置」关闭锁定后再修改'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
    return true;
  }
}
