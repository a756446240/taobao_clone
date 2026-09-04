import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  /// 素材搜索关键词（按标题过滤）
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final pool = context.read<MaterialPoolProvider>();
    final count = await pool.importFromGallery();
    if (mounted) {
      _toast(count > 0 ? '已导入 $count 张素材图' : '未选择图片');
    }
  }

  /// 长按标题触发：导入电脑抓包脚本生成的 taobao_materials_*.json
  Future<void> _importJson() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('导入抓包素材', style: TextStyle(fontSize: 16)),
        content: const Text(
          '电脑抓单时同目录会生成 taobao_materials_*.json\n（订单里所有商品的图+名称），微信发到手机后导入。',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, 'cancel'),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'paste'),
              child: const Text('粘贴文本')),
          TextButton(
              onPressed: () => Navigator.pop(c, 'file'),
              child: const Text('选择文件',
                  style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    );
    if (choice == null || choice == 'cancel') return;
    String? raw;
    if (choice == 'file') {
      try {
        final res = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json', 'txt'],
        );
        final path = res?.files.single.path;
        if (path == null) return;
        raw = await File(path).readAsString();
      } catch (e) {
        _toast('读取文件失败：$e');
        return;
      }
    } else {
      final clip = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final ctl = TextEditingController(text: clip?.text ?? '');
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('粘贴素材 JSON', style: TextStyle(fontSize: 16)),
          content: SizedBox(
            width: double.maxFinite,
            child: TextField(
              controller: ctl,
              maxLines: 8,
              style: const TextStyle(fontSize: 11),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('取消')),
            TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('导入',
                    style: TextStyle(color: Color(0xFFFF5000)))),
          ],
        ),
      );
      if (ok != true || ctl.text.trim().isEmpty) return;
      raw = ctl.text.trim();
    }
    // 导入中提示（图片要逐张下载，可能几十秒）
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 14),
            Text('正在下载商品图素材…', style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
    final pool = context.read<MaterialPoolProvider>();
    final (added, skipped, err) = await pool.importFromJson(raw);
    if (!mounted) return;
    Navigator.of(context).pop(); // 关掉进度框
    _toast('素材导入完成：新增 $added 件，跳过 $skipped 件'
        '${added == 0 && err.isNotEmpty ? '（$err）' : ''}');
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

  /// 单条素材重新 AI 命名（仅用户导入的本地图，内置 assets 不可）
  Future<void> _aiNameOne(MaterialEntry e) async {
    if (e.bundled || e.imagePath.startsWith('assets/')) {
      _toast('内置素材不支持 AI 命名');
      return;
    }
    if (!await DoubaoService.hasApiKey) {
      _toast('请先配置豆包 API Key');
      await _configDoubao();
      if (!await DoubaoService.hasApiKey) return;
    }
    _toast('AI 识别中...');
    try {
      final title = await DoubaoService.recognizeProductName(e.imagePath);
      if (!mounted) return;
      await context.read<MaterialPoolProvider>().setTitle(e, title);
      _toast('已命名：$title');
    } catch (err) {
      if (mounted) _toast('识别失败：$err');
    }
  }

  /// 单击素材：大图预览 + 操作（改名/AI命名/删除）
  void _preview(MaterialEntry e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: AppImage(url: e.imagePath, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                e.title.isEmpty ? '未命名素材' : e.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: e.title.isEmpty
                        ? const Color(0xFF999999)
                        : Colors.black87),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _previewAction(Icons.edit_outlined, '修改名称', () {
                    Navigator.pop(sheetCtx);
                    _editTitle(e);
                  }),
                  if (!e.bundled) ...[
                    _previewAction(Icons.auto_awesome, 'AI命名', () {
                      Navigator.pop(sheetCtx);
                      _aiNameOne(e);
                    }),
                    _previewAction(Icons.delete_outline, '删除', () {
                      Navigator.pop(sheetCtx);
                      context.read<MaterialPoolProvider>().remove(e);
                      _toast('已删除素材');
                    }, color: const Color(0xFFA32D2D)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewAction(IconData icon, String label, VoidCallback onTap,
      {Color color = const Color(0xFF333333)}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
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
    final all = pool.entries;
    final entries = _query.isEmpty
        ? all
        : all.where((e) => e.title.contains(_query)).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: GestureDetector(
          // 隐藏入口：长按标题 → 导入电脑抓包生成的素材 JSON
          onLongPress: _importJson,
          child: const Text('商品素材库'),
        ),
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
      body: all.isEmpty
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
                // 搜索框：素材多了按标题快速定位
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search,
                            size: 18, color: Color(0xFF999999)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) =>
                                setState(() => _query = v.trim()),
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: '搜索素材标题',
                              hintStyle: TextStyle(
                                  fontSize: 13, color: Color(0xFFBBBBBB)),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() {
                              _searchCtrl.clear();
                              _query = '';
                            }),
                            child: const Icon(Icons.cancel,
                                size: 16, color: Color(0xFFBBBBBB)),
                          ),
                      ],
                    ),
                  ),
                ),
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
                  child: entries.isEmpty
                      ? const Center(
                          child: Text('没有匹配的素材',
                              style: TextStyle(
                                  color: Color(0xFF999999), fontSize: 13)))
                      : GridView.builder(
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
                        onTap: () => _preview(e),
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
                              )
                            else
                              // 未命名角标：引导去 AI 命名或手动命名
                              Positioned(
                                left: 2,
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xCCFF8C00),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('未命名',
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 9)),
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
