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
        _migrate();
      } else {
        _seedDefault();
      }
    } catch (_) {
      _seedDefault();
    }
    if (mounted) setState(() => _loaded = true);
  }

  /// v1.9.75 数据修正：
  /// - 清掉旧版内置的假演示地址（张晓/李婷/13812348888 等，用户反馈"乱码"）
  /// - 修正历史数据里的错字「中房房大厦」→「中房大厦」
  void _migrate() {
    const fakePhones = {'13812348888', '13998766666'};
    final before = _list.length;
    _list.removeWhere((a) =>
        fakePhones.contains(a.phone) ||
        (a.region.contains('杭州市') && a.detail.contains('文三路')) ||
        (a.region.contains('浦东新区') && a.detail.contains('世纪大道')) ||
        (a.region.contains('海淀区') && a.detail.contains('中关村')));
    var dirty = _list.length != before;
    for (final a in _list) {
      if (a.detail.contains('中房房大厦')) {
        a.detail = a.detail.replaceAll('中房房大厦', '中房大厦');
        dirty = true;
      }
    }
    if (_list.isEmpty) {
      _seedDefault();
      return;
    }
    if (dirty) _save();
  }

  /// 内置地址：对齐用户真实淘宝地址簿（淄博 中房大厦 等）
  void _seedDefault() {
    _list
      ..clear()
      ..addAll([
        _Address(
            name: '黑山灰',
            phone: '18653385652',
            region: '山东省 淄博市 张店区 科苑街道',
            detail: '中房大厦C座1001',
            isDefault: true),
        _Address(
            name: '王广霞',
            phone: '17669764365',
            region: '山东省 淄博市 张店区 马尚街道',
            detail: '新村西路电业局第四宿舍区放丰巢柜就行'),
        _Address(
            name: '辉',
            phone: '18653385652',
            region: '江西省 九江市 修水县 义宁镇',
            detail: '城北古茗店内'),
        _Address(
            name: '辉',
            phone: '18653385652',
            region: '山东省 淄博市 张店区 公园街道',
            detail: '中央公园(人民西路) 华润中央公园9号楼803'),
        _Address(
            name: '黑山灰',
            phone: '18653385652',
            region: '江苏省 宿迁市 宿城区 埠子镇',
            detail: '蔡桥庄'),
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

  /// 左滑露出「设为默认 / 复制 / 删除」三个操作（对齐真实淘宝）
  /// v1.9.74：弃用 Dismissible（松手立即回弹点不到按钮），
  /// 改为自绘滑动容器——滑开停住、点卡片或再右滑收回
  Widget _buildSwipeCard(_Address a, int index) {
    return _SwipeReveal(
      key: ObjectKey(a),
      actionsWidth: 192, // 3 × 64
      actions: [
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

/// 左滑露出操作区的容器（对齐真实淘宝地址列表）：
/// - 拖动超过一半松手 → 自动停在展开位；不到一半 → 弹回
/// - 展开后点卡片或右滑 → 收回
class _SwipeReveal extends StatefulWidget {
  final Widget child;
  final List<Widget> actions;
  final double actionsWidth;

  const _SwipeReveal({
    super.key,
    required this.child,
    required this.actions,
    required this.actionsWidth,
  });

  @override
  State<_SwipeReveal> createState() => _SwipeRevealState();
}

class _SwipeRevealState extends State<_SwipeReveal>
    with SingleTickerProviderStateMixin {
  double _dx = 0; // 当前位移（0 = 关闭，-actionsWidth = 展开）
  late final AnimationController _ctrl;
  Animation<double>? _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180))
      ..addListener(() {
        if (_anim != null) setState(() => _dx = _anim!.value);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _ctrl.stop();
    _anim = Tween<double>(begin: _dx, end: target)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl
      ..reset()
      ..forward();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    _ctrl.stop();
    setState(() {
      _dx = (_dx + d.delta.dx).clamp(-widget.actionsWidth, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -300) {
      _animateTo(-widget.actionsWidth); // 快速左滑直接展开
    } else if (v > 300) {
      _animateTo(0); // 快速右滑直接收回
    } else {
      _animateTo(_dx < -widget.actionsWidth / 2 ? -widget.actionsWidth : 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _dx < -1;
    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      behavior: HitTestBehavior.opaque,
      child: ClipRect(
        child: Stack(
          children: [
            // 操作区（右侧，露出部分才可点）
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IgnorePointer(
                    ignoring: !open,
                    child: Row(children: widget.actions),
                  ),
                ],
              ),
            ),
            // 卡片本体（随手指平移）
            Transform.translate(
              offset: Offset(_dx, 0),
              child: GestureDetector(
                // 展开状态下点卡片收回；关闭状态下不拦截原有点击
                onTap: open ? () => _animateTo(0) : null,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
