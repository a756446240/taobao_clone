import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'persistence_service.dart';

/// 我的淘宝 资料 Provider（头像/昵称/等级/签名/地址）
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
      _avatar = m['avatar'] ?? _avatar;
      _nickname = m['nickname'] ?? _nickname;
      _level = m['level'] ?? _level;
      _slogan = m['slogan'] ?? _slogan;
      _address = m['address'] ?? _address;
      _headerBg = m['headerBg'] ?? _headerBg;
    }
    _loading = false;
    notifyListeners();
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
      avatar: avatar,
      nickname: nickname,
      level: level,
      slogan: slogan,
      address: address,
      headerBg: headerBg,
    );
  }

  /// 单独更新头像（我的页面直接点击头像换图）
  Future<void> updateAvatar(String avatar) async {
    _avatar = avatar;
    notifyListeners();
    await PersistenceService.saveProfile(
      avatar: avatar,
      nickname: _nickname,
      level: _level,
      slogan: _slogan,
      address: _address,
      headerBg: _headerBg,
    );
  }

  /// 单独更新顶部背景图
  Future<void> updateHeaderBg(String headerBg) async {
    _headerBg = headerBg;
    notifyListeners();
    await PersistenceService.saveProfile(
      avatar: _avatar,
      nickname: _nickname,
      level: _level,
      slogan: _slogan,
      address: _address,
      headerBg: headerBg,
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
