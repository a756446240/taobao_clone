import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 收藏夹「降价提醒」全局管理（Provider + 本地持久化）
///
/// 收藏条目上的「降价提醒」按钮写这里，收藏夹读这里：
/// 一处开启全局生效，重启 App 不丢。按商品标题作 key。
///
/// 降价本身是确定性演示规则（与收藏夹「有降价」筛选同一口径）：
/// 标题哈希 % 3 == 0 的宝贝视为已降价，降幅 5%~25% 由哈希决定。
class PriceAlertProvider extends ChangeNotifier {
  static const _key = 'price_alert_titles_v1';

  /// 已开启提醒的商品标题集合
  final Set<String> _titles = {};
  bool _loaded = false;

  bool get loaded => _loaded;

  bool isOn(String title) => _titles.contains(title);

  /// 已开启提醒的宝贝数
  int get count => _titles.length;

  static int _hashOf(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  /// 该宝贝是否已降价（确定性，与收藏夹「有降价」筛选同一口径）
  static bool hasDrop(String title) => _hashOf(title) % 3 == 0;

  /// 降幅百分比（5~25），未降价返回 0
  static int dropPercent(String title) {
    if (!hasDrop(title)) return 0;
    return 5 + _hashOf(title) % 21;
  }

  /// 降价后的现价
  static double droppedPrice(double origin, String title) {
    final pct = dropPercent(title);
    if (pct <= 0) return origin;
    return origin * (100 - pct) / 100;
  }

  /// 已开启提醒且当前已降价的宝贝数（用于收藏夹顶部横幅）
  int droppedAlertCount(Iterable<String> allTitles) =>
      _titles.where((t) => allTitles.contains(t) && hasDrop(t)).length;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList(_key);
      if (list != null) {
        _titles
          ..clear()
          ..addAll(list);
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_key, _titles.toList());
    } catch (_) {}
  }

  /// 切换提醒开关，返回切换后的状态（true=已开启）
  bool toggle(String title) {
    final now = !_titles.contains(title);
    if (now) {
      _titles.add(title);
    } else {
      _titles.remove(title);
    }
    notifyListeners();
    _save();
    return now;
  }
}
