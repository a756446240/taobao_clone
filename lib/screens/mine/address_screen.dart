import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 收货地址管理页（我的淘宝顶部"地址"单击进入）
/// 对齐真实淘宝：卡片列表 + 左滑「设为默认/复制/删除」+ 底部新增按钮。
/// 地址持久化到 SharedPreferences（address_list_v1），重启/更新不丢。
class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _Address {
  String name;
  String phone;
  String region; // 省市区
  String detail; // 详细地址
  bool isDefault;

  _Address({
    required this.name,
    required this.phone,
    required this.region,
    required this.detail,
    this.isDefault = false,
  });

  /// 手机号脱敏：138****8888
  String get maskedPhone => phone.length == 11
      ? '${phone.substring(0, 3)}****${phone.substring(7)}'
      : phone;

  String get fullText => '$region$detail $name $phone';

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'region': region,
        'detail': detail,
        'isDefault': isDefault,
      };

  static _Address fromJson(Map<String, dynamic> j) => _Address(
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        region: j['region'] ?? '',
        detail: j['detail'] ?? '',
        isDefault: j['isDefault'] ?? false,
      );
}

class _AddressScreenState extends State<AddressScreen> {
  static const _prefsKey = 'address_list_v1';

  final List<_Address> _list = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((e) => _Address.fromJson(e as Map<String, dynamic>))
            .toList();
        _list
          ..clear()
          ..addAll(list);
      } else {
        _seedDefault();
      }
    } catch (_) {
      _seedDefault();
    }
    if (mounted) setState(() => _loaded = true);
  }

  void _seedDefault() {
    _list
      ..clear()
      ..addAll([
        _Address(
            name: '张晓',
            phone: '13812348888',
            region: '浙江省 杭州市 西湖区',
            detail: '文三路 100 号 3 幢 2 单元 501 室',
            isDefault: true),
        _Address(
            name: '李婷',
            phone: '13998766666',
            region: '上海市 上海市 浦东新区',
            detail: '世纪大道 200 号 写字楼 15 层'),
        _Address(
            name: '张晓',
            phone: '13812348888',
            region: '北京市 北京市 海淀区',
            detail: '中关村大街 1 号 院 8 号楼'),
      ]);
    _save();
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _prefsKey, jsonEncode(_list.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void _setDefault(_Address a) {
    setState(() {
      for (final e in _list) {
        e.isDefault = false;
      }
      a.isDefault = true;
    });
    _save();
    _toast('已设为默认地址');
  }

  void _copyAddress(_Address a) {
    Clipboard.setData(ClipboardData(text: a.fullText));
    _toast('地址已复制');
  }

  void _deleteAt(int index) {
    final removed = _list[index];
    setState(() {
      _list.removeAt(index);
      if (removed.isDefault && _list.isNotEmpty) {
        _list.first.isDefault = true;
      }
    });
    _save();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('地址已删除'),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            setState(() {
              final i = index > _list.length ? _list.length : index;
              _list.insert(i, removed);
              if (removed.isDefault) {
                for (final e in _list) {
                  e.isDefault = false;
                }
                removed.isDefault = true;
              }
            });
            _save();
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('收货地址',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _list.isEmpty
              ? const Center(
                  child: Text('还没有收货地址，点击下方按钮添加',
                      style: AppTextStyles.middleSub))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount: _list.length,
                  itemBuilder: (ctx, i) => _buildSwipeCard(_list[i], i),
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: GestureDetector(
            onTap: () => _openEditor(),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF5000), Color(0xFFFF2E4D)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text('新增收货地址',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }

  /// 左滑露出「设为默认 / 复制 / 删除」三个操作（对齐真实淘宝），松手回弹
  Widget _buildSwipeCard(_Address a, int index) {
    return Dismissible(
      key: ObjectKey(a),
      direction: DismissDirection.endToStart,
      // 不真正滑走，只露出操作区，松手回弹
      confirmDismiss: (_) async => false,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _swipeAction(
              label: '设为默认',
              icon: Icons.check_circle_outline,
              color: const Color(0xFFFF8C00),
              onTap: () => _setDefault(a),
            ),
            _swipeAction(
              label: '复制',
              icon: Icons.copy_outlined,
              color: const Color(0xFF3B82F6),
              onTap: () => _copyAddress(a),
            ),
            _swipeAction(
              label: '删除',
              icon: Icons.delete_outline,
              color: const Color(0xFFFF3B30),
              onTap: () => _deleteAt(index),
              radius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ],
        ),
      ),
      child: _buildCard(a),
    );
  }

  Widget _swipeAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    BorderRadius? radius,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        decoration: BoxDecoration(color: color, borderRadius: radius),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(_Address a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.region,
                    style: AppTextStyles.small
                        .copyWith(color: AppColors.subText)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(a.detail,
                          style: AppTextStyles.normalBold
                              .copyWith(height: 1.3)),
                    ),
                    GestureDetector(
                      onTap: () => _openEditor(target: a),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.subText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text('${a.name} ${a.phone}',
                        style: AppTextStyles.small
                            .copyWith(color: AppColors.subText)),
                    if (a.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1EC),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('默认',
                            style: TextStyle(
                                color: AppColors.primary, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 新增 / 编辑底部抽屉
  void _openEditor({_Address? target}) {
    final isEdit = target != null;
    final nameCtrl = TextEditingController(text: target?.name ?? '');
    final phoneCtrl =
        TextEditingController(text: target?.phone ?? '');
    final regionCtrl =
        TextEditingController(text: target?.region ?? '');
    final detailCtrl =
        TextEditingController(text: target?.detail ?? '');
    var makeDefault = target?.isDefault ?? _list.isEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEdit ? '编辑地址' : '新增地址',
                    style: AppTextStyles.normalBold),
                const SizedBox(height: 12),
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: '收货人')),
                TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    decoration: const InputDecoration(
                        labelText: '手机号', counterText: '')),
                TextField(
                    controller: regionCtrl,
                    decoration: const InputDecoration(
                        labelText: '所在地区（省 市 区）')),
                TextField(
                    controller: detailCtrl,
                    decoration: const InputDecoration(
                        labelText: '详细地址')),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('设为默认地址',
                        style: TextStyle(fontSize: 14)),
                    const Spacer(),
                    Switch(
                      value: makeDefault,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) =>
                          setSheet(() => makeDefault = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary),
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final region = regionCtrl.text.trim();
                      final detail = detailCtrl.text.trim();
                      if (name.isEmpty ||
                          region.isEmpty ||
                          detail.isEmpty) {
                        _toast('请填写完整地址信息');
                        return;
                      }
                      if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
                        _toast('请输入正确的 11 位手机号');
                        return;
                      }
                      setState(() {
                        if (makeDefault) {
                          for (final e in _list) {
                            e.isDefault = false;
                          }
                        }
                        if (isEdit) {
                          target.name = name;
                          target.phone = phone;
                          target.region = region;
                          target.detail = detail;
                          target.isDefault = makeDefault;
                        } else {
                          _list.add(_Address(
                              name: name,
                              phone: phone,
                              region: region,
                              detail: detail,
                              isDefault: makeDefault));
                        }
                      });
                      _save();
                      Navigator.pop(ctx);
                      _toast(isEdit ? '地址已保存' : '地址已添加');
                    },
                    child: const Text('保存'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 1)));
  }
}
