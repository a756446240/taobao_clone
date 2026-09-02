import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'account_pay_screens.dart';
import 'address_screen.dart';
import 'settings_detail_screens.dart';

/// 淘宝式设置页：分组列表 + 开关 + 清除缓存 + 退出登录
class SettingsScreen extends StatefulWidget {
  /// 当前版本号（关于行展示）
  final String version;

  const SettingsScreen({super.key, this.version = ''});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _msgNotify = true;
  bool _soundVibrate = true;
  bool _wifiVideo = false;
  String _cacheSize = '128.6MB';

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _clearCache() {
    if (_cacheSize == '0MB') return;
    setState(() => _cacheSize = '0MB');
    _toast('缓存已清除');
  }

  /// 退出登录：确认弹窗 → 返回首页
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后接收不到消息提醒，确定要退出登录吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('退出登录',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      _toast('已退出登录');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('设置',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _group([
            _arrowRow('账号与安全',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            const AccountSecurityScreen()))),
            _arrowRow('支付设置',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PaySettingsScreen()))),
            _arrowRow('收货地址管理',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AddressScreen()))),
          ]),
          _group([
            _switchRow('消息通知', '接收订单/物流/优惠推送', _msgNotify,
                (v) => setState(() => _msgNotify = v)),
            _switchRow('声音与震动', '新消息提示音和震动', _soundVibrate,
                (v) => setState(() => _soundVibrate = v)),
            _switchRow('WiFi 下自动播放视频', '微淘/详情页视频自动播放', _wifiVideo,
                (v) => setState(() => _wifiVideo = v)),
          ]),
          _group([
            _arrowRow('清除缓存',
                trailing: _cacheSize, onTap: _clearCache),
            _arrowRow('隐私',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const PrivacyScreen()))),
            _arrowRow('通用',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const GeneralScreen()))),
          ]),
          _group([
            _arrowRow('关于淘宝',
                trailing: widget.version.isNotEmpty
                    ? 'v${widget.version}'
                    : null,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            AboutScreen(version: widget.version)))),
            _arrowRow('意见反馈',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const FeedbackScreen()))),
          ]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GestureDetector(
              onTap: _confirmLogout,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('退出登录',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 分组白卡（组内 0.5px 分隔线）
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

  Widget _arrowRow(String title, {String? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
                child: Text(title, style: const TextStyle(fontSize: 14))),
            if (trailing != null)
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
}
