import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 收货地址管理页（设置页入口）
/// 列表（默认标/设为默认/编辑/删除）+ 底部新增按钮 + 新增/编辑底部抽屉
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
}

class _AddressScreenState extends State<AddressScreen> {
  final List<_Address> _list = [
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
  ];

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
      body: _list.isEmpty
          ? const Center(
              child: Text('还没有收货地址，点击下方按钮添加',
                  style: AppTextStyles.middleSub))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
              itemCount: _list.length,
              itemBuilder: (ctx, i) => _buildCard(_list[i], i),
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

  Widget _buildCard(_Address a, int index) {
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
                Row(
                  children: [
                    Text(a.name, style: AppTextStyles.normalBold),
                    const SizedBox(width: 10),
                    Text(a.maskedPhone,
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
                                color: AppColors.primary,
                                fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text('${a.region} ${a.detail}',
                    style:
                        AppTextStyles.small.copyWith(height: 1.4)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: [
                // 设为默认
                TextButton.icon(
                  onPressed: a.isDefault
                      ? null
                      : () => setState(() {
                            for (final e in _list) {
                              e.isDefault = false;
                            }
                            a.isDefault = true;
                          }),
                  icon: Icon(
                      a.isDefault
                          ? Icons.check_circle
                          : Icons.radio_button_off,
                      size: 16,
                      color: a.isDefault
                          ? AppColors.primary
                          : AppColors.subText),
                  label: Text('设为默认',
                      style: TextStyle(
                          fontSize: 12,
                          color: a.isDefault
                              ? AppColors.primary
                              : AppColors.subText)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _openEditor(target: a),
                  icon: const Icon(Icons.edit_outlined,
                      size: 15, color: AppColors.subText),
                  label: const Text('编辑',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.subText)),
                ),
                TextButton.icon(
                  onPressed: () => _confirmDelete(index),
                  icon: const Icon(Icons.delete_outline,
                      size: 15, color: AppColors.subText),
                  label: const Text('删除',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.subText)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除地址'),
        content: Text(
            '确定要删除「${_list[index].region}${_list[index].detail}」这条地址吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      final removed = _list.removeAt(index);
      // 删掉默认地址后，自动把第一条设为默认
      if (removed.isDefault && _list.isNotEmpty) {
        _list.first.isDefault = true;
      }
    });
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
