import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/banner_pool_provider.dart';
import '../../widgets/app_image.dart';

/// 首页 banner 素材库管理页（双击首页 banner 进入）：
/// 与商品素材库独立，素材全部由用户从相册导入，有多少素材首页就轮播多少张。
class BannerPoolScreen extends StatelessWidget {
  const BannerPoolScreen({super.key});

  Future<void> _import(BuildContext context) async {
    final pool = context.read<BannerPoolProvider>();
    final n = await pool.importFromGallery();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(n > 0 ? '已导入 $n 张 banner 素材' : '未选择图片'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = context.watch<BannerPoolProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFf5f5f5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('banner 素材库',
            style: TextStyle(color: Colors.black87, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => _import(context),
            child: const Text('导入',
                style: TextStyle(color: AppColors.primary, fontSize: 14)),
          ),
        ],
      ),
      body: pool.entries.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.image_outlined,
                      size: 72, color: Color(0xFFc4c4c4)),
                  const SizedBox(height: 12),
                  const Text('还没有 banner 素材',
                      style:
                          TextStyle(fontSize: 14, color: Color(0xFF666666))),
                  const SizedBox(height: 6),
                  const Text('点右上角「导入」从相册添加，首页按素材数量轮播',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _import(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('从相册导入'),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: pool.entries.length,
              itemBuilder: (_, i) {
                final path = pool.entries[i];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppImage(url: path, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: GestureDetector(
                        onTap: () => pool.remove(path),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
