import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/doubao_service.dart';
import '../../providers/cart_provider.dart';

/// AI 订单截图解析页（双击"足迹"进入）
/// 用户发截图 → 豆包视觉模型解析订单字段 → 预览 → 追加 preset_orders.json
class AiOrderImportScreen extends StatefulWidget {
  const AiOrderImportScreen({super.key});

  @override
  State<AiOrderImportScreen> createState() => _AiOrderImportScreenState();
}

class _AiOrderImportScreenState extends State<AiOrderImportScreen> {
  // 豆包（火山引擎·方舟）视觉解析，API Key 在素材库页配置（替代原 SenseNova）

  final List<_ParsedOrder> _queue = [];
  bool _parsing = false;

  Future<void> _pickAndAnalyze() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    setState(() => _parsing = true);
    for (final x in picked) {
      try {
        final parsed = await _analyzeImage(File(x.path));
        if (parsed != null) {
          _queue.add(parsed);
        }
      } catch (e) {
        // 缺 API Key：页内直接弹配置框，保存后自动重试当前这张
        if ('$e'.contains('配置豆包 API Key')) {
          setState(() => _parsing = false);
          final ok = await _configKeyDialog();
          if (ok) {
            setState(() => _parsing = true);
            try {
              final parsed = await _analyzeImage(File(x.path));
              if (parsed != null) _queue.add(parsed);
              continue;
            } catch (e2) {
              _toast('第 ${_queue.length + 1} 张识别失败：$e2');
              continue;
            }
          }
          setState(() => _parsing = true);
        }
        _toast('第 ${_queue.length + 1} 张识别失败：$e');
      }
    }
    setState(() => _parsing = false);
  }

  /// 页内配置豆包 API Key（不用跳转素材库页），返回是否已保存
  Future<bool> _configKeyDialog() async {
    final keyCtl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('配置豆包 API Key', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '首次使用需要配置一次 Key（保存后永久生效）：\n'
              '火山引擎方舟 console.volcengine.com/ark → API Key 管理',
              style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtl,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: '形如 xxxxxxxx-xxxx-xxxx...',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('保存并识别',
                  style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    );
    if (saved == true && keyCtl.text.trim().isNotEmpty) {
      await DoubaoService.saveApiKey(keyCtl.text);
      _toast('Key 已保存，继续识别');
      return true;
    }
    return false;
  }

  /// 调用豆包视觉模型解析订单截图，返回结构化字段
  Future<_ParsedOrder?> _analyzeImage(File file) async {
    final parsed = await DoubaoService.analyzeOrderScreenshot(file.path);
    return _ParsedOrder(
      imagePath: file.path,
      shopName: (parsed['shopName'] ?? '未知店铺').toString(),
      productTitle: (parsed['productTitle'] ?? '未识别标题').toString(),
      price: (parsed['price'] is num)
          ? (parsed['price'] as num).toDouble()
          : double.tryParse('${parsed['price']}') ?? 0,
      status: (parsed['status'] ?? '待发货').toString(),
      confidence: (parsed['confidence'] is num)
          ? (parsed['confidence'] as num).toDouble()
          : 0.6,
      rawJson: jsonEncode(parsed),
    );
  }

  Future<void> _appendToPresetOrders() async {
    if (_queue.isEmpty) {
      _toast('队列是空的');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('追加到订单列表？'),
        content: Text(
            '将追加 ${_queue.length} 条订单到"我的订单"，立即生效并自动保存。\n\n继续吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('追加',
                  style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    );
    if (confirmed != true) return;
    final provider = context.read<CartProvider>();
    for (final o in _queue) {
      provider.importAiParsedOrder(
        shopName: o.shopName,
        productTitle: o.productTitle,
        price: o.price,
        status: o.status,
      );
    }
    _toast('已追加 ${_queue.length} 条订单，去"我的订单"查看');
    setState(() => _queue.clear());
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
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
        title: const Text('AI 订单截图解析',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 顶部说明
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFE0B8)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        size: 16, color: Color(0xFFFF5000)),
                    SizedBox(width: 6),
                    Text('AI 自动识别',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B4513))),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '发订单截图给我，豆包视觉模型自动提取：店铺名、商品标题、实付价、状态。\n'
                  '识别完成后一键追加到订单列表，立即生效并自动保存。',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8B4513), height: 1.5),
                ),
              ],
            ),
          ),
          // 添加按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _parsing ? null : _pickAndAnalyze,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(_parsing ? '识别中...' : '选择截图（可多选）'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 解析队列
          Expanded(
            child: _queue.isEmpty
                ? const Center(
                    child: Text('还没有解析任何订单\n点击下方按钮添加截图',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: Color(0xFF999999))),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _queue.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildQueueItem(_queue[i], i),
                  ),
          ),
          // 底部追加按钮
          if (_queue.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                    top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _appendToPresetOrders,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5000),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                    ),
                    child: Text('一键追加 ${_queue.length} 条订单'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQueueItem(_ParsedOrder o, int idx) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 截图缩略图
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.file(File(o.imagePath), fit: BoxFit.cover),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.productTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('店铺：${o.shopName}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF666666))),
                Text('实付：¥${o.price.toStringAsFixed(2)}  状态：${o.status}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF666666))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: o.confidence >= 0.8
                            ? const Color(0xFFE6F7E6)
                            : const Color(0xFFFFF4E8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '置信度 ${(o.confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: o.confidence >= 0.8
                              ? const Color(0xFF2A9655)
                              : const Color(0xFFFF8C00),
                        ),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _queue.removeAt(idx)),
                      child: const Icon(Icons.delete_outline,
                          size: 16, color: Color(0xFFA32D2D)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParsedOrder {
  final String imagePath;
  final String shopName;
  final String productTitle;
  final double price;
  final String status;
  final double confidence;
  final String rawJson;

  _ParsedOrder({
    required this.imagePath,
    required this.shopName,
    required this.productTitle,
    required this.price,
    required this.status,
    required this.confidence,
    required this.rawJson,
  });
}
