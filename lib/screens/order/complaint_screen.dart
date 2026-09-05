import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/models.dart';

/// 投诉商家页（v1.9.80 新增，照搬真实淘宝「投诉商家」UI）：
/// 投诉原因单选列表 → 投诉说明 → 上传凭证占位 → 提交申请
class ComplaintScreen extends StatefulWidget {
  final ShoppingCartShop shop;
  final OrderItem item;

  const ComplaintScreen({super.key, required this.shop, required this.item});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  static const _reasons = [
    ('发货问题', '未按约定时间发货'),
    ('发货问题', '缺货 / 无法发货'),
    ('物流问题', '虚假发货 / 物流长时间无更新'),
    ('退款问题', '商家拒绝退款'),
    ('商品问题', '商品与描述不符'),
    ('商品问题', '疑似假货'),
    ('服务问题', '商家骚扰 / 辱骂'),
    ('其他问题', '其他违规行为'),
  ];

  int _selected = 0;
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('提交成功', style: TextStyle(fontSize: 16)),
        content: const Text(
          '您的投诉已提交，淘宝客服将在 48 小时内核实处理，处理结果将通过消息通知您。',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('投诉商家',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          // 投诉对象卡
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF5000),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    widget.shop.shopName.isNotEmpty
                        ? widget.shop.shopName[0]
                        : '店',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.shop.shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('订单号 ${widget.item.orderNo}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF999999))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 投诉原因
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 8, 14, 4),
                  child: Text('投诉原因',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                for (var i = 0; i < _reasons.length; i++)
                  InkWell(
                    onTap: () => setState(() => _selected = i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_reasons[i].$1,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(height: 2),
                                Text(_reasons[i].$2,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF999999))),
                              ],
                            ),
                          ),
                          Icon(
                            _selected == i
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: _selected == i
                                ? AppColors.primary
                                : const Color(0xFFCCCCCC),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 投诉说明
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('投诉说明',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: '请描述您遇到的问题，以便客服更快核实（选填）',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: Color(0xFFBBBBBB)),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 上传凭证
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('上传凭证',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined,
                          size: 22, color: Color(0xFFBBBBBB)),
                      SizedBox(height: 4),
                      Text('添加图片',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFFBBBBBB))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: GestureDetector(
            onTap: _submit,
            child: Container(
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFF5000), Color(0xFFFF2E4D)]),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text('提交申请',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
