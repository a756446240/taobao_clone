import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 搜索历史状态管理（Provider + 本地持久化）
class SearchProvider extends ChangeNotifier {
  static const _key = 'search_history';
  List<String> _history = [];

  List<String> get history => _history;

  Future<void> load() async {
    try {
      final sp = await SharedPreferences.getInstance();
      _history = sp.getStringList(_key) ?? [];
    } catch (_) {
      _history = [];
    }
    notifyListeners();
  }

  Future<void> add(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return;
    _history.remove(kw);
    _history.insert(0, kw);
    if (_history.length > 20) {
      _history = _history.sublist(0, 20);
    }
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_key, _history);
    } catch (_) {}
  }

  Future<void> clear() async {
    _history = [];
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_key);
    } catch (_) {}
  }
}
