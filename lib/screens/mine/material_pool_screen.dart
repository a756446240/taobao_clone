import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/doubao_service.dart';
import '../../providers/material_pool_provider.dart';
import '../../widgets/app_image.dart';

/// 商品素材管理页（我的淘宝 → "地址"按钮进入）
/// 查看素材池、从相册多选导入、删除已导入素材、豆包AI识别命名。
/// 每次打开 App 时订单商品图从本池随机抽取展示。
class MaterialPoolScreen extends StatefulWidget {
  const MaterialPoolScreen({super.key});

  @override
  State<MaterialPoolScreen> createState() => _MaterialPoolScreenState();
}

class _MaterialPoolScreenState extends State<MaterialPoolScreen> {
  Future<void> _import() async {
    final pool = context.read<MaterialPoolProvider>();
    final count = await pool.importFromGallery();
    if (mounted) {
      _toast(count > 0 ? '已导入 $count 张素材图' : '未选择图片');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
    ));
  }

  /// 配置豆包 API Key / 模型
  Future<void> _configDoubao() async {
    final keyCtl = TextEditingController(text: await DoubaoService.getApiKey());
    final modelCtl =
        TextEditingController(text: await DoubaoService.getModel());
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('豆包 API 配置', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '在火山引擎方舟平台创建 API Key：\nconsole.volcengine.com/ark → API Key 管理\n\n'
              '注意：豆包App套餐不含API额度，API按token计费，'
              '每个模型新用户送50万token免费额度（可识别上万张图）。',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtl,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: '形如 xxxxxxxx-xxxx-xxxx...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: modelCtl,
              decoration: const InputDecoration(
                labelText: '视觉模型 ID（默认即可）',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (saved == true) {
      await DoubaoService.saveApiKey(keyCtl.text);
      await DoubaoService.saveModel(
          modelCtl.text.trim().isEmpty ? DoubaoService.defaultModel : modelCtl.text);
      _toast('已保存豆包配置');
    }
  }

  /// 豆包批量识别命名
  Future<void> _aiName() async {
    if (!await DoubaoService.hasApiKey) {
      _toast('请先配置豆包 API Key');
      await _configDoubao();
      if (!await DoubaoService.hasApiKey) return;
    }
    if (!mounted) return;
    final pool = context.read<MaterialPoolProvider>();
    final (ok, fail, err) = await pool.aiNameUntitled();
    if (!mounted) return;
    _toast(fail == 0
        ? '豆包命名完成：成功 $ok 张'
        : '完成 $ok 张，失败 $fail 张${err.isNotEmpty ? "（$err）" : ""}');
  }

  /// 手动修改某条素材名称
  Future<void> _editTitle(MaterialEntry e) async {
    final pool = context.read<MaterialPoolProvider>();
    final ctl = TextEditingController(text: e.title);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('商品名称', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: ctl,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: '留空则随机展示时沿用原商品名',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (saved == true) {
      await pool.setTitle(e, ctl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final pool = context.watch<MaterialPoolProvider>();
    final entries = pool.entries;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('商品素材库'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '豆包API配置',
            icon: const Icon(Icons.key_outlined),
            onPressed: _configDoubao,
          ),
          IconButton(
            tooltip: '豆包AI命名',
            icon: const Icon(Icons.auto_awesome),
            onPressed: pool.aiProgress == null ? _aiName : null,
          ),
        ],
      ),
      body: entries.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 56, color: Color(0xFFc4c4c4)),
                  const SizedBox(height: 12),
                  const Text('还没有素材图\n点击下方按钮从相册导入',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: Color(0xFF999999), fontSize: 14)),
                  const SizedBox(height: 8),
                  const Text('每次打开 App，商品图会从素材库随机展示',
                      style:
                          TextStyle(color: Color(0xFFbbbbbb), fontSize: 12)),
                ],
              ),
            )
          : Column(
              children: [
                if (pool.aiProgress != null)
                  Container(
                    width: double.infinity,
                    color: AppColors.primary.withOpacity(0.1),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Row(
                      children: [
                        const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        Text(pool.aiProgress!,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      return GestureDetector(
                        onDoubleTap: () => _editTitle(e),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: AppImage(url: e.imagePath),
                            ),
                            if (e.title.isNotEmpty)
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.45),
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            bottom: Radius.circular(8)),
                                  ),
                                  child: Text(e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 10)),
                                ),
                              ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: e.bundled
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.4),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: const Text('内置',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9)),
                                    )
                                  : GestureDetector(
                                      onTap: () => pool.remove(e),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 14),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _import,
        icon: const Icon(Icons.add_photo_alternate_outlined,
            color: Colors.white),
        label: const Text('导入素材', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
