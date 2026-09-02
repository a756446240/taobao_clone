import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 店铺关注状态全局管理（Provider + 本地持久化）
///
/// 统一之前各自为政的关注状态：店铺主页关注按钮、关注店铺列表页、
/// 直播间关注按钮都读写这里，一处关注全局生效，重启 App 不丢。
class FollowShopsProvider extends ChangeNotifier {
  static const _key = 'followed_shops_v1';

  /// 首次启动的默认关注店铺（与关注列表页内置目录一致）
  static const defaultFollowed = [
    'Lily 官方旗舰店',
    '完美日记官方',
    '小米官方旗舰店',
    '良品铺子官方',
    '林氏木业官方',
    '巴拉巴拉官方',
    '华为官方旗舰店',
    '花西子官方',
    '三只松鼠旗舰店',
    '顾家家居官方',
  ];

  Set<String> _followed = {...defaultFollowed};
  bool _loaded = false;

  bool get loaded => _loaded;

  /// 已关注店铺名集合（只读视图）
  Set<String> get followed => Set.unmodifiable(_followed);

  bool isFollowed(String shopName) => _followed.contains(shopName);

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final saved = sp.getStringList(_key);
      if (saved != null) {
        _followed = saved.toSet();
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_key, _followed.toList());
    } catch (_) {}
  }

  void follow(String shopName) {
    if (_followed.add(shopName)) {
      notifyListeners();
      _save();
    }
  }

  void unfollow(String shopName) {
    if (_followed.remove(shopName)) {
      notifyListeners();
      _save();
    }
  }

  /// 切换关注，返回切换后的关注状态
  bool toggle(String shopName) {
    final now = !_followed.contains(shopName);
    if (now) {
      _followed.add(shopName);
    } else {
      _followed.remove(shopName);
    }
    notifyListeners();
    _save();
    return now;
  }
}
