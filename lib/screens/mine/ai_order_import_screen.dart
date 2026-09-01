import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// AI 订单截图解析页（双击"足迹"进入）
/// 用户发截图 → SenseNova AI 解析订单字段 → 预览 → 追加 preset_orders.json
///
/// 注：当前实现为演示骨架，AI 调用通过对话框收集字段；
/// 真实接入 SenseNova 时替换 _analyzeImage 即可。
class AiOrderImportScreen extends StatefulWidget {
  const AiOrderImportScreen({super.key});

  @override
  State<AiOrderImportScreen> createState() => _AiOrderImportScreenState();
}

class _AiOrderImportScreenState extends State<AiOrderImportScreen> {
  final List<_ParsedOrder> _queue = [];
  bool _parsing = false;

  Future<void> _pickAndAnalyze() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    setState(() => _parsing = true);
    for (final x in picked) {
      final parsed = await _analyzeImage(File(x.path));
      if (parsed != null) {
        _queue.add(parsed);
      }
    }
    setState(() => _parsing = false);
  }

  /// 调用 SenseNova 解析订单截图
  /// TODO: 接入 sensenova_generate_image / sensenova_chat MCP
  Future<_ParsedOrder?> _analyzeImage(File file) async {
    // 模拟解析延迟
    await Future.delayed(const Duration(milliseconds: 800));
    // 模拟返回结果（真实环境应调用 SenseNova 视觉模型）
    return _ParsedOrder(
      imagePath: file.path,
      shopName: '示例店铺',
      productTitle: '从截图识别的商品标题',
      price: 99.00,
      status: '待发货',
      confidence: 0.85,
      rawJson: '{"source":"sensenova","mock":true}',
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
        title: const Text('追加到 preset_orders.json？'),
        content: Text(
            '将追加 ${_queue.length} 条订单，追加后需重新构建 IPA 生效。\n\n继续吗？'),
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
    // TODO: 实际写入 preset_orders.json（通过 path_provider 拿到文档目录）
    _toast('已追加 ${_queue.length} 条订单，请重新构建 IPA');
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
                  '发订单截图给我，我会自动提取：店铺名、商品标题、实付价、状态。\n'
                  '识别完成后可一键追加到 preset_orders.json，下次构建 IPA 自动生效。',
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
