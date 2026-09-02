import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// 聊天记录持久化：按会话（店铺/联系人名）存消息，重启不丢
/// 图片消息约定：content 以 'img:' 开头，后面跟本地文件路径
class ChatHistoryProvider extends ChangeNotifier {
  static const _key = 'chat_history_v1';
  static const _settingsKey = 'chat_settings_v1';
  static const _maxPerConversation = 100;

  final Map<String, List<ChatMessage>> _data = {};

  /// 会话设置：置顶 / 免打扰（按会话名持久化）
  final Set<String> _pinned = {};
  final Set<String> _muted = {};

  bool isPinned(String conversationKey) => _pinned.contains(conversationKey);
  bool isMuted(String conversationKey) => _muted.contains(conversationKey);

  void togglePin(String conversationKey) {
    _pinned.contains(conversationKey)
        ? _pinned.remove(conversationKey)
        : _pinned.add(conversationKey);
    notifyListeners();
    _saveSettings();
  }

  void toggleMute(String conversationKey) {
    _muted.contains(conversationKey)
        ? _muted.remove(conversationKey)
        : _muted.add(conversationKey);
    notifyListeners();
    _saveSettings();
  }

  /// 某会话的历史消息（时间正序）
  List<ChatMessage> historyFor(String conversationKey) =>
      List.unmodifiable(_data[conversationKey] ?? const []);

  /// 追加一条消息（超过上限裁剪最旧的）
  void append(String conversationKey, ChatMessage m) {
    final list = _data.putIfAbsent(conversationKey, () => []);
    list.add(m);
    if (list.length > _maxPerConversation) {
      list.removeRange(0, list.length - _maxPerConversation);
    }
    notifyListeners();
    _save();
  }

  /// 清空某会话
  void clear(String conversationKey) {
    if (!_data.containsKey(conversationKey)) return;
    _data.remove(conversationKey);
    notifyListeners();
    _save();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    // 会话设置（置顶/免打扰）
    try {
      final sraw = p.getString(_settingsKey);
      if (sraw != null && sraw.isNotEmpty) {
        final smap = Map<String, dynamic>.from(jsonDecode(sraw));
        _pinned
          ..clear()
          ..addAll((smap['pinned'] as List? ?? []).map((e) => e.toString()));
        _muted
          ..clear()
          ..addAll((smap['muted'] as List? ?? []).map((e) => e.toString()));
      }
    } catch (_) {}
    final raw = p.getString(_key);
    if (raw == null || raw.isEmpty) {
      notifyListeners();
      return;
    }
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      _data
        ..clear()
        ..addAll(map.map((k, v) => MapEntry(
              k,
              (v as List)
                  .map((e) => ChatMessage(
                        content: e['content'] ?? '',
                        isMe: e['isMe'] ?? false,
                        time: e['time'] ?? '',
                      ))
                  .toList(),
            )));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _settingsKey,
        jsonEncode(
            {'pinned': _pinned.toList(), 'muted': _muted.toList()}));
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    final map = _data.map((k, v) => MapEntry(
        k,
        v
            .map((m) =>
                {'content': m.content, 'isMe': m.isMe, 'time': m.time})
            .toList()));
    await p.setString(_key, jsonEncode(map));
  }
}
