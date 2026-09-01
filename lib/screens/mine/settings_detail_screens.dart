import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// 设置页二级页：隐私设置 / 通用设置 / 意见反馈

// ============ 隐私设置 ============
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _location = true;
  bool _camera = true;
  bool _album = true;
  bool _mic = false;
  bool _contacts = false;
  bool _adRecommend = true;
  bool _contentRecommend = true;
  bool _findByPhone = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _appBar('隐私设置'),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _sectionTitle('权限管理'),
          _group([
            _switchRow('位置信息', '用于收货地址定位、附近好店推荐', _location,
                (v) => setState(() => _location = v)),
            _switchRow('相机', '用于扫一扫、拍照购物、晒图评价', _camera,
                (v) => setState(() => _camera = v)),
            _switchRow('相册', '用于更换头像、评价晒图、保存图片', _album,
                (v) => setState(() => _album = v)),
            _switchRow('麦克风', '用于语音搜索、直播连麦', _mic,
                (v) => setState(() => _mic = v)),
            _switchRow('通讯录', '用于找到通讯录里的淘友', _contacts,
                (v) => setState(() => _contacts = v)),
          ]),
          _sectionTitle('隐私保护'),
          _group([
            _switchRow('个性化广告推荐', '关闭后广告数量不变，相关性降低',
                _adRecommend, (v) => setState(() => _adRecommend = v)),
            _switchRow('个性化内容推荐', '根据浏览偏好推荐商品和内容',
                _contentRecommend,
                (v) => setState(() => _contentRecommend = v)),
            _switchRow('允许通过手机号找到我', '其他淘友可通过手机号搜索到你',
                _findByPhone, (v) => setState(() => _findByPhone = v)),
          ]),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text('权限变更仅对本机生效。我们承诺严格按照《隐私政策》保护你的个人信息安全。',
                style: TextStyle(
                    color: Color(0xFF999999), fontSize: 11, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

// ============ 通用设置 ============
class GeneralScreen extends StatefulWidget {
  const GeneralScreen({super.key});

  @override
  State<GeneralScreen> createState() => _GeneralScreenState();
}

class _GeneralScreenState extends State<GeneralScreen> {
  double _fontScale = 1.0; // 0.85 小 / 1.0 标准 / 1.15 大
  int _darkMode = 0; // 0 跟随系统 / 1 开启 / 2 关闭
  bool _elderMode = false;
  bool _floatPlay = false;

  String get _fontLabel => _fontScale < 0.95
      ? '小'
      : _fontScale > 1.05
          ? '大'
          : '标准';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _appBar('通用'),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _sectionTitle('显示'),
          _group([
            // 深色模式三选一
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('深色模式', style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _darkMode = i),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                      vertical: 8),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _darkMode == i
                                    ? const Color(0xFFFFF1EC)
                                    : const Color(0xFFF5F5F5),
                                border: Border.all(
                                    color: _darkMode == i
                                        ? AppColors.primary
                                        : Colors.transparent),
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                              child: Text(
                                  const ['跟随系统', '开启', '关闭'][i],
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: _darkMode == i
                                          ? AppColors.primary
                                          : Colors.black87)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 字体大小
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('字体大小',
                          style: TextStyle(fontSize: 14)),
                      const Spacer(),
                      Text(_fontLabel,
                          style: const TextStyle(
                              color: Color(0xFF999999),
                              fontSize: 12)),
                    ],
                  ),
                  Slider(
                    value: _fontScale,
                    min: 0.85,
                    max: 1.15,
                    divisions: 2,
                    activeColor: AppColors.primary,
                    onChanged: (v) =>
                        setState(() => _fontScale = v),
                  ),
                ],
              ),
            ),
          ]),
          _sectionTitle('体验'),
          _group([
            _switchRow('长辈模式', '更大字体、更简洁的页面布局', _elderMode,
                (v) {
              setState(() {
                _elderMode = v;
                if (v) _fontScale = 1.15;
              });
            }),
            _switchRow('悬浮窗播放', '退出直播间后小窗继续播放', _floatPlay,
                (v) => setState(() => _floatPlay = v)),
          ]),
        ],
      ),
    );
  }
}

// ============ 意见反馈 ============
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _types = ['功能异常', '体验问题', '商品咨询', '物流问题', '其他'];
  String _type = '功能异常';
  final _descCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();

  @override
  void dispose() {
    _descCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _appBar('意见反馈'),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('问题类型',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _types.map((t) {
                    final active = t == _type;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFFFF1EC)
                              : const Color(0xFFF5F5F5),
                          border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : Colors.transparent),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 12,
                                color: active
                                    ? AppColors.primary
                                    : Colors.black87)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('问题描述',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 5,
                  maxLength: 300,
                  decoration: InputDecoration(
                    hintText: '请描述你遇到的问题或建议（必填）',
                    hintStyle: const TextStyle(
                        color: Color(0xFFBBBBBB), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _contactCtrl,
                  decoration: InputDecoration(
                    hintText: '联系方式（选填，方便我们回访）',
                    hintStyle: const TextStyle(
                        color: Color(0xFFBBBBBB), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF8F8F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _submit,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF5000), Color(0xFFFF2E4D)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text('提交反馈',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('请先填写问题描述'),
            duration: Duration(seconds: 1)));
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Icon(Icons.check_circle,
                color: Color(0xFF22C55E), size: 48),
            const SizedBox(height: 12),
            const Text('反馈已提交',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('感谢你的建议，我们会尽快处理「$_type」相关问题',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF999999), fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('完成',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
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

Widget _sectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
    child: Text(title,
        style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
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
