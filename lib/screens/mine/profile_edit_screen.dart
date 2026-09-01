import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_text_styles.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';

/// 个人信息编辑（头像 + 背景图 + 昵称 + 等级 + 签名 + 地址）
/// 头像/背景图从手机相册选择，等级用选项式，保存后本地持久化。
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _sloganController;
  late final TextEditingController _addressController;
  late String _avatarUrl;
  late String _headerBgUrl;
  late String _level;

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileProvider>();
    _nicknameController = TextEditingController(text: p.nickname);
    _sloganController = TextEditingController(text: p.slogan);
    _addressController = TextEditingController(text: p.address);
    _avatarUrl = p.avatar;
    _headerBgUrl = p.headerBg;
    _level = p.level;
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _sloganController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<String?> _pickImageToLocal(String subDir) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/$subDir');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$ext';
      final saved = await File(picked.path).copy('${saveDir.path}/$fileName');
      return saved.path;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('选择图片失败')));
      }
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    final path = await _pickImageToLocal('profile_avatars');
    if (path != null) setState(() => _avatarUrl = path);
  }

  Future<void> _pickHeaderBg() async {
    final path = await _pickImageToLocal('profile_headers');
    if (path != null) setState(() => _headerBgUrl = path);
  }

  Future<void> _pickLevel() async {
    final v = await DialogHelpers.showOptionPicker(
      context,
      title: '会员等级',
      options: ProfileProvider.levelOptions,
      currentValue: _level,
    );
    if (v != null) setState(() => _level = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf5f5f5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Icon(Icons.arrow_back_ios, color: Colors.black87),
        ),
        title: const Text('编辑个人信息',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存',
                style: TextStyle(
                    color: Color(0xFFff5000),
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildAvatarCard(),
          const SizedBox(height: 12),
          _buildHeaderBgCard(),
          const SizedBox(height: 12),
          _buildFieldCard('昵称', _nicknameController),
          const SizedBox(height: 12),
          _buildOptionCard('会员等级', _level, _pickLevel),
          const SizedBox(height: 12),
          _buildFieldCard('个性签名', _sloganController),
          const SizedBox(height: 12),
          _buildFieldCard('收货地址', _addressController),
        ],
      ),
    );
  }

  Widget _buildAvatarCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipOval(
                  child: Container(
                    width: 80,
                    height: 80,
                    color: const Color(0xFFffd180),
                    child: _avatarUrl.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 40)
                        : AppImage(url: _avatarUrl, width: 80, height: 80),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFff5000),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text('点击头像从相册选择',
              style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
        ],
      ),
    );
  }

  /// 顶部背景图编辑（从相册选择）
  Widget _buildHeaderBgCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我的淘宝顶部背景图',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickHeaderBg,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                height: 100,
                color: const Color(0xFFFFE0CC),
                child: _headerBgUrl.isEmpty
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.photo_library,
                              color: Color(0xFFff5000), size: 30),
                          SizedBox(height: 6),
                          Text('点击从相册选择背景图',
                              style: TextStyle(
                                  color: Color(0xFF999999), fontSize: 12)),
                        ],
                      )
                    : Image.file(File(_headerBgUrl),
                        width: double.infinity, height: 100, fit: BoxFit.cover),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCard(String label, TextEditingController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.small),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '请输入$label',
                border: InputBorder.none,
                hintStyle:
                    const TextStyle(color: Color(0xFFcccccc), fontSize: 14),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// 选项式条目（如会员等级，点击弹出选项而不是手输）
  Widget _buildOptionCard(
      String label, String value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.small),
            const SizedBox(width: 16),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 14, color: Colors.black87)),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Color(0xFFcccccc)),
          ],
        ),
      ),
    );
  }

  void _save() async {
    final p = context.read<ProfileProvider>();
    await p.save(
      avatar: _avatarUrl,
      nickname: _nicknameController.text.trim().isEmpty
          ? p.nickname
          : _nicknameController.text.trim(),
      level: _level,
      slogan: _sloganController.text.trim(),
      address: _addressController.text.trim(),
      headerBg: _headerBgUrl,
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已保存')));
      Navigator.of(context).pop();
    }
  }
}
