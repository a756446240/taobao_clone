import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'persistence_service.dart';

/// 我的淘宝 资料 Provider（头像/昵称/等级/签名/地址）
/// 头像/背景图在 SharedPreferences 里只存**相对路径**（profile_avatars/xx.jpg），
/// 加载时拼接当前 Documents 目录解析成绝对路径——自签重装后 App 容器路径会变，
/// 旧版本存绝对路径会导致更新后头像"被重置"。
class ProfileProvider extends ChangeNotifier {
  String _avatar = '';
  String _nickname = '松本品';
  String _level = '青铜会员';
  String _slogan = '看到喜欢的就带回家';
  String _address = '';
  String _headerBg = '';
  bool _loading = true;

  String get avatar => _avatar;
  String get nickname => _nickname;
  String get level => _level;
  String get slogan => _slogan;
  String get address => _address;
  String get headerBg => _headerBg;
  bool get loading => _loading;

  ProfileProvider() {
    _load();
  }

  Future<void> _load() async {
    final m = await PersistenceService.loadProfile();
    if (m != null) {
      _avatar = await _resolveImg(m['avatar'] ?? _avatar);
      _nickname = m['nickname'] ?? _nickname;
      _level = m['level'] ?? _level;
      _slogan = m['slogan'] ?? _slogan;
      _address = m['address'] ?? _address;
      _headerBg = await _resolveImg(m['headerBg'] ?? _headerBg);
    }
    _loading = false;
    notifyListeners();
  }

  /// 把存储值解析成可用的绝对路径：
  /// - 空 / 网络图 / assets 原样返回
  /// - 相对路径（profile_avatars/xx.jpg）→ 拼当前 Documents
  /// - 旧版绝对路径 → 提取 profile_xxx 之后的相对部分再拼接（文件还在就能找回）
  static Future<String> _resolveImg(String v) async {
    if (v.isEmpty || v.startsWith('http') || v.startsWith('assets/')) return v;
    String rel = v.replaceAll('\\', '/');
    for (final marker in ['/profile_avatars/', '/profile_headers/']) {
      final i = rel.indexOf(marker);
      if (i >= 0) {
        rel = rel.substring(i + 1);
        break;
      }
    }
    if (rel.startsWith('/')) return v; // 无法识别的绝对路径，原样
    try {
      final doc = await getApplicationDocumentsDirectory();
      final abs = '${doc.path}/$rel';
      if (File(abs).existsSync()) return abs;
      // 文件真的没了（数据被清）才回退空，避免显示破图
      return '';
    } catch (_) {
      return v;
    }
  }

  /// 保存前把绝对路径压成相对路径（profile_xxx/文件名），其余原样
  static Future<String> _relativizeImg(String v) async {
    if (v.isEmpty || v.startsWith('http') || v.startsWith('assets/')) return v;
    var s = v.replaceAll('\\', '/');
    for (final marker in ['/profile_avatars/', '/profile_headers/']) {
      final i = s.indexOf(marker);
      if (i >= 0) return s.substring(i + 1);
    }
    return v;
  }

  Future<void> save({
    required String avatar,
    required String nickname,
    required String level,
    required String slogan,
    required String address,
    String headerBg = '',
  }) async {
    _avatar = avatar;
    _nickname = nickname;
    _level = level;
    _slogan = slogan;
    _address = address;
    _headerBg = headerBg;
    notifyListeners();
    await PersistenceService.saveProfile(
      avatar: await _relativizeImg(avatar),
      nickname: nickname,
      level: level,
      slogan: slogan,
      address: address,
      headerBg: await _relativizeImg(headerBg),
    );
  }

  /// 单独更新头像（我的页面直接点击头像换图）
  Future<void> updateAvatar(String avatar) async {
    _avatar = avatar;
    notifyListeners();
    await PersistenceService.saveProfile(
      avatar: await _relativizeImg(avatar),
      nickname: _nickname,
      level: _level,
      slogan: _slogan,
      address: _address,
      headerBg: await _relativizeImg(_headerBg),
    );
  }

  /// 单独更新顶部背景图
  Future<void> updateHeaderBg(String headerBg) async {
    _headerBg = headerBg;
    notifyListeners();
    await PersistenceService.saveProfile(
      avatar: await _relativizeImg(_avatar),
      nickname: _nickname,
      level: _level,
      slogan: _slogan,
      address: _address,
      headerBg: await _relativizeImg(headerBg),
    );
  }

  /// 默认等级选项
  static const List<String> levelOptions = [
    '青铜会员',
    '白银会员',
    '黄金会员',
    '铂金会员',
    '钻石会员',
    '天猫会员',
    '88VIP',
  ];
}
