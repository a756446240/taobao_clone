import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/product_image_provider.dart';

/// 公共工具：点击商品图片 → 从手机相册选择替换
/// 以商品标题为 key 持久化（重启后依然生效）。
Future<void> pickProductImageFromGallery(
  BuildContext context,
  String title,
) async {
  final provider = context.read<ProductImageProvider>();
  final alreadyReplaced = provider.imageFor(title) != null;

  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading:
                const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            title: const Text('从相册选择图片替换'),
            onTap: () => Navigator.pop(context, 'pick'),
          ),
          if (alreadyReplaced)
            ListTile(
              leading: const Icon(Icons.restore, color: AppColors.subText),
              title: const Text('恢复默认图片'),
              onTap: () => Navigator.pop(context, 'reset'),
            ),
          ListTile(
            leading: const Icon(Icons.close, color: AppColors.subText),
            title: const Text('取消'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );

  if (action == 'reset') {
    await provider.removeOverride(title);
    return;
  }
  if (action != 'pick') return;

  try {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    // 复制到应用私有目录，避免缓存被系统清理
    final dir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${dir.path}/product_images');
    if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
    final fileName =
        'img_${DateTime.now().millisecondsSinceEpoch}${picked.path.contains('.') ? picked.path.substring(picked.path.lastIndexOf('.')) : '.jpg'}';
    final saved = await File(picked.path).copy('${saveDir.path}/$fileName');
    await provider.setOverride(title, saved.path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品图已替换'), duration: Duration(seconds: 1)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片替换失败，请重试')),
      );
    }
  }
}
