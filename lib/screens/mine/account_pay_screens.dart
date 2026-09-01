import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 账号与安全 / 支付设置（设置页入口）

// ============ 账号与安全 ============
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  String _phone = '13812348888';

  /// 手机号脱敏
  String get _maskedPhone => _phone.length == 11
      ? '${_phone.substring(0, 3)}****${_phone.substring(7)}'
      : _phone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _appBar('账号与安全'),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _group([
            _infoRow('会员名', '淘友小筑'),
            _arrowRow('手机号', trailing: _maskedPhone,
                onTap: _changePhone),
            _arrowRow('登录密码', trailing: '已设置',
                onTap: () => _toast('修改登录密码（演示）')),
            _arrowRow('支付密码', trailing: '已设置',
                onTap: () => _toast('修改支付密码（演示）')),
          ]),
          _group([
            _arrowRow('实名认证',
                trailingWidget: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text('已认证',
                      style: TextStyle(
                          color: Color(0xFF2E7D32), fontSize: 11)),
                ),
                onTap: () => _toast('已完成实名认证')),
            _arrowRow('人脸认证', trailing: '未认证',
                onTap: () => _toast('人脸认证（演示）')),
            _arrowRow('登录设备管理', trailing: '2 台设备',
                onTap: () => _toast('登录设备管理（演示）')),
          ]),
          _group([
            _arrowRow('账号注销',
                titleColor: Colors.red,
                onTap: _confirmDeleteAccount),
          ]),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('为了保障账号安全，修改手机号、密码等敏感操作需要进行身份验证。',
                style: TextStyle(
                    color: Color(0xFF999999), fontSize: 11, height: 1.5)),
          ),
        ],
      ),
    );
  }

  /// 修改手机号：输入新号码 + 校验
  void _changePhone() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('修改绑定手机号',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('当前绑定：$_maskedPhone',
                  style: const TextStyle(
                      color: Color(0xFF999999), fontSize: 12)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.phone,
              maxLength: 11,
              decoration: const InputDecoration(
                  labelText: '新手机号', counterText: ''),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary),
                onPressed: () {
                  final v = ctrl.text.trim();
                  if (!RegExp(r'^1\d{10}$').hasMatch(v)) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(const SnackBar(
                          content: Text('请输入正确的 11 位手机号'),
                          duration: Duration(seconds: 1)));
                    return;
                  }
                  setState(() => _phone = v);
                  Navigator.pop(ctx);
                  _toast('手机号已换绑');
                },
                child: const Text('确认换绑'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text(
            '注销后账号数据将无法恢复，包括订单记录、收藏、购物车等。确定要继续吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('再想想')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认注销',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      _toast('注销申请已提交，7 天内生效（演示）');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 1)));
  }
}

// ============ 支付设置 ============
class PaySettingsScreen extends StatefulWidget {
  const PaySettingsScreen({super.key});

  @override
  State<PaySettingsScreen> createState() => _PaySettingsScreenState();
}

class _PaySettingsScreenState extends State<PaySettingsScreen> {
  bool _freePay = true; // 小额免密
  bool _fingerprint = true;
  bool _face = false;

  /// 扣款顺序（可在抽屉里调整）
  final List<String> _payOrder = ['余额', '余额宝', '储蓄卡(尾号8888)', '花呗'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _appBar('支付设置'),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _group([
            _switchRow('小额免密支付', '单笔 200 元以下无需输入密码', _freePay,
                (v) => setState(() => _freePay = v)),
            _switchRow('指纹支付', '使用指纹快速完成付款', _fingerprint,
                (v) => setState(() => _fingerprint = v)),
            _switchRow('面容支付', '使用面容 ID 快速完成付款', _face,
                (v) => setState(() => _face = v)),
          ]),
          _group([
            _arrowRow('扣款顺序',
                trailing: _payOrder.first,
                onTap: _openPayOrderSheet),
            _arrowRow('支付密码', trailing: '已设置',
                onTap: () => _toast('修改支付密码（演示）')),
            _arrowRow('自动续费管理', trailing: '1 项',
                onTap: () => _toast('88VIP 自动续费管理中（演示）')),
          ]),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('扣款顺序从上到下依次尝试，可将常用方式排在前面。',
                style: TextStyle(
                    color: Color(0xFF999999), fontSize: 11, height: 1.5)),
          ),
        ],
      ),
    );
  }

  /// 扣款顺序抽屉：上移调整 + 置顶
  void _openPayOrderSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              const Text('自定义扣款顺序',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('点击右侧按钮上移，排第一的优先扣款',
                  style: TextStyle(
                      color: Color(0xFF999999), fontSize: 11)),
              const SizedBox(height: 10),
              const Divider(height: 1),
              for (var i = 0; i < _payOrder.length; i++)
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: i == 0
                        ? AppColors.primary
                        : const Color(0xFFE0E0E0),
                    child: Text('${i + 1}',
                        style: TextStyle(
                            color: i == 0
                                ? Colors.white
                                : Colors.black54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  title: Text(_payOrder[i],
                      style: const TextStyle(fontSize: 14)),
                  trailing: i == 0
                      ? const Text('优先扣款',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11))
                      : TextButton(
                          onPressed: () {
                            setSheet(() {
                              final item = _payOrder.removeAt(i);
                              _payOrder.insert(i - 1, item);
                            });
                            setState(() {});
                          },
                          child: const Text('上移',
                              style: TextStyle(fontSize: 12)),
                        ),
                ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
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

// ============ 共用小组件 ============
PreferredSizeWidget _appBar(String title) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0.5,
    centerTitle: true,
    iconTheme: const IconThemeData(color: Colors.black87),
    title: Text(title,
        style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600)),
  );
}

Widget _group(List<Widget> rows) {
  return Container(
    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            const Divider(
                height: 0.5,
                thickness: 0.5,
                indent: 14,
                color: Color(0xFFF0F0F0)),
          rows[i],
        ],
      ],
    ),
  );
}

Widget _arrowRow(String title,
    {String? trailing,
    Widget? trailingWidget,
    Color? titleColor,
    VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: TextStyle(
                    fontSize: 14, color: titleColor ?? Colors.black87)),
          ),
          if (trailingWidget != null)
            Padding(
                padding: const EdgeInsets.only(right: 4),
                child: trailingWidget)
          else if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(trailing,
                  style: const TextStyle(
                      color: Color(0xFF999999), fontSize: 12)),
            ),
          const Icon(Icons.chevron_right,
              color: Color(0xFFCCCCCC), size: 18),
        ],
      ),
    ),
  );
}

Widget _infoRow(String title, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    child: Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
        Text(value,
            style:
                const TextStyle(color: Color(0xFF999999), fontSize: 12)),
      ],
    ),
  );
}

Widget _switchRow(
    String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: Color(0xFF999999), fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}
