import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/persistence_service.dart';

/// 淘宝订单同步导入页（我的 → 工具卡片「同步订单」进入）
/// 电脑端脚本抓取真实淘宝订单生成 JSON → 微信传到手机 → 这里导入。
/// 规则：按订单号去重，只增不改——已在列表里的订单（含手动编辑过的）绝不覆盖。
class TaobaoSyncImportScreen extends StatefulWidget {
  const TaobaoSyncImportScreen({super.key});

  @override
  State<TaobaoSyncImportScreen> createState() => _TaobaoSyncImportScreenState();
}

class _TaobaoSyncImportScreenState extends State<TaobaoSyncImportScreen> {
  bool _busy = false;

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// 从 JSON 文本解析店铺订单列表（支持 {"version":n,"orders":[...]} 与纯数组两种格式）
  List<ShoppingCartShop> _parse(String raw) {
    final decoded = jsonDecode(raw);
    List<dynamic> list;
    if (decoded is Map<String, dynamic>) {
      final orders = decoded['orders'];
      if (orders is! List) throw const FormatException('JSON 里找不到 orders 数组');
      list = orders;
    } else if (decoded is List) {
      list = decoded;
    } else {
      throw const FormatException('JSON 格式不对');
    }
    final shops = list
        .map((e) => PersistenceService.shopFromJson(e as Map<String, dynamic>))
        .where((s) => s.items.isNotEmpty)
        .toList();
    if (shops.isEmpty) throw const FormatException('没有解析到有效订单');
    return shops;
  }

  /// 预览 → 确认 → 导入
  Future<void> _previewAndImport(String raw, String sourceDesc) async {
    List<ShoppingCartShop> shops;
    try {
      shops = _parse(raw);
    } catch (e) {
      _toast('解析失败：$e');
      return;
    }
    final provider = context.read<CartProvider>();
    final existingNos = <String>{
      for (final s in provider.shops)
        for (final it in s.items) it.orderNo,
    };
    var total = 0;
    var dup = 0;
    for (final s in shops) {
      for (final it in s.items) {
        total++;
        if (it.orderNo.isNotEmpty && existingNos.contains(it.orderNo)) dup++;
      }
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('确认导入？', style: TextStyle(fontSize: 16)),
        content: Text(
          '来源：$sourceDesc\n'
          '解析到 ${shops.length} 家店铺 / $total 条订单\n\n'
          '✅ 新增导入：${total - dup} 条\n'
          '⏭ 已存在跳过：$dup 条\n\n'
          '已有订单（含你修改过的）不会被覆盖。',
          style: const TextStyle(fontSize: 13, height: 1.6),
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
    if (confirmed != true) return;
    final result = provider.importSyncedShops(shops);
    final tail = result.blocked > 0 ? '，拦截已删除 ${result.blocked} 条' : '';
    if (result.added > 0) {
      _toast('已导入 ${result.added} 条新订单（跳过重复 ${result.skipped} 条$tail）');
      if (mounted) Navigator.of(context).pop();
    } else {
      _toast('没有新订单，${result.skipped} 条已存在$tail');
    }
  }

  /// 选择 JSON 文件导入
  Future<void> _pickFile() async {
    setState(() => _busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
      );
      if (res == null || res.files.isEmpty) return;
      final path = res.files.single.path;
      if (path == null) {
        _toast('读不到文件路径');
        return;
      }
      final raw = await File(path).readAsString();
      await _previewAndImport(raw, res.files.single.name);
    } catch (e) {
      _toast('读取文件失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 粘贴 JSON 文本导入
  Future<void> _pasteText() async {
    final ctl = TextEditingController();
    final clip = await Clipboard.getData(Clipboard.kTextPlain);
    if (clip?.text != null && clip!.text!.trim().isNotEmpty) {
      ctl.text = clip.text!;
    }
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('粘贴订单 JSON', style: TextStyle(fontSize: 16)),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: ctl,
            maxLines: 8,
            style: const TextStyle(fontSize: 11),
            decoration: const InputDecoration(
              hintText: '把电脑脚本生成的 JSON 内容粘贴到这里',
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
              child: const Text('解析',
                  style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) {
      await _previewAndImport(ctl.text.trim(), '粘贴的文本');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('同步淘宝订单',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // 使用说明
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FD),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB8DCFF)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sync, size: 16, color: Color(0xFF1976D2)),
                    SizedBox(width: 6),
                    Text('怎么同步',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1))),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '1. 在电脑上运行抓单脚本（扫码登录淘宝一次）\n'
                  '2. 把生成的 JSON 文件用微信发到手机\n'
                  '3. 回到这里点「选择文件导入」\n\n'
                  '只会新增订单：列表里已有的订单（包括你改过的）原样保留，重复单号自动跳过。',
                  style:
                      TextStyle(fontSize: 12, color: Color(0xFF0D47A1), height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.file_open),
              label: Text(_busy ? '读取中...' : '选择 JSON 文件导入'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5000),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pasteText,
              icon: const Icon(Icons.content_paste),
              label: const Text('粘贴 JSON 文本导入'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5000),
                side: const BorderSide(color: Color(0xFFFF5000)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(23)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildClearAllCard(),
          const SizedBox(height: 10),
          _buildBlacklistCard(),
        ],
      ),
    );
  }

  /// 一键清空全部商品订单（仅淘宝商品订单，不影响闪购/飞猪；
  /// 不写入已删黑名单，清空后可立即重新导入抓包 JSON）
  Widget _buildClearAllCard() {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        final count = provider.shops.length;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.cleaning_services_outlined,
                  size: 18, color: Color(0xFF999999)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count > 0 ? '当前商品订单 $count 单' : '当前没有商品订单',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
              if (count > 0)
                TextButton(
                  onPressed: () => _confirmClearAll(provider, count),
                  child: const Text('一键清空',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFFF5000))),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearAll(CartProvider provider, int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空全部商品订单？', style: TextStyle(fontSize: 16)),
        content: Text(
          '将删除当前 $count 单商品订单（不含闪购/飞猪）。\n\n'
          '清空后这些订单不会进已删黑名单，可立即重新导入抓包 JSON 全量恢复。',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('清空',
                  style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    );
    if (ok == true) {
      final n = provider.clearAllShops();
      _toast('已清空 $n 单商品订单');
    }
  }

  /// 已删除订单黑名单卡片：用户删掉的订单不会再被同步导入复活
  Widget _buildBlacklistCard() {
    return Consumer<CartProvider>(
      builder: (context, provider, _) {
        final count = provider.deletedTradeNosCount;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFF999999)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count > 0
                      ? '已删除订单 $count 条（导入时永久跳过）'
                      : '已删除订单黑名单为空',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
              if (count > 0)
                TextButton(
                  onPressed: () => _confirmClearBlacklist(provider),
                  child: const Text('清空',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFFF5000))),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmClearBlacklist(CartProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空已删除黑名单？', style: TextStyle(fontSize: 16)),
        content: const Text(
          '清空后，下次同步导入会把你在淘宝里仍存在、但之前在本 App 删除过的订单重新导进来。',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('清空',
                  style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    );
    if (ok == true) {
      await provider.clearDeletedTradeNos();
      _toast('黑名单已清空');
    }
  }
}
