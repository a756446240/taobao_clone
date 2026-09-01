import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/cart_provider.dart';

/// AI 数据校验页（双击"关注店铺"进入）
/// 扫描所有订单，核对"总价 - 优惠 + 运费 = 实付"，列出不一致订单
class AiOrderAuditScreen extends StatefulWidget {
  const AiOrderAuditScreen({super.key});

  @override
  State<AiOrderAuditScreen> createState() => _AiOrderAuditScreenState();
}

class _AiOrderAuditScreenState extends State<AiOrderAuditScreen> {
  bool _scanning = false;
  List<_AuditResult> _results = [];
  int _totalScanned = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAudit());
  }

  Future<void> _runAudit() async {
    setState(() {
      _scanning = true;
      _results = [];
      _totalScanned = 0;
    });

    final cart = context.read<CartProvider>();
    final all = <_AuditResult>[];

    // 遍历所有店铺的所有订单
    for (final shop in cart.shops) {
      for (final item in shop.items) {
        _totalScanned++;
        final r = _auditItem(shop, item);
        if (r != null) all.add(r);
      }
    }

    // 模拟 AI 分析延迟（真实场景会调用 SenseNova）
    await Future.delayed(const Duration(milliseconds: 600));

    setState(() {
      _results = all;
      _scanning = false;
    });
  }

  /// 核对单条订单：总价 - 优惠 + 运费 = 实付
  _AuditResult? _auditItem(ShoppingCartShop shop, OrderItem item) {
    final issues = <String>[];

    // 公式：productTotal - shopDiscount - platformCoupon - coDiscount + shippingFee = price
    final expected = item.productTotal -
        item.shopDiscount -
        item.platformCoupon -
        item.coDiscount +
        item.shippingFee;
    final actual = item.price;
    final diff = (expected - actual).abs();

    // 允许 0.01 的浮点误差
    if (diff > 0.01) {
      issues.add(
          '实付不一致：预期 ¥${expected.toStringAsFixed(2)}，实际 ¥${actual.toStringAsFixed(2)}（差 ¥${diff.toStringAsFixed(2)}）');
    }

    // 退款订单额外校验：退款金额不应大于实付
    final isRefund = item.refundStatus.isNotEmpty &&
        item.refundStatus != '退款结束';
    if (isRefund && item.refundAmount > 0) {
      if (item.refundAmount > actual + 0.01) {
        issues.add(
            '退款金额异常：¥${item.refundAmount.toStringAsFixed(2)} 超过实付 ¥${actual.toStringAsFixed(2)}');
      }
    }

    // 字段缺失校验
    if (item.productTotal == 0 && item.price > 0) {
      issues.add('缺少 productTotal（商品总价）字段');
    }
    if (item.createTime.isEmpty) {
      issues.add('缺少 createTime（下单时间）字段');
    }

    if (issues.isEmpty) return null;
    return _AuditResult(shop: shop, item: item, issues: issues);
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
        title: const Text('AI 数据校验',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _scanning ? null : _runAudit,
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部说明
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFB8DCFF)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: Color(0xFF1890FF)),
                    SizedBox(width: 6),
                    Text('AI 自动核对',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1890FF))),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  '校验规则：总价 - 店铺优惠 - 平台券 - 组合优惠 + 运费 = 实付价\n'
                  '同时检查：退款金额 ≤ 实付价、必填字段完整',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF1890FF), height: 1.5),
                ),
              ],
            ),
          ),
          // 扫描状态
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(
                  _scanning
                      ? '扫描中...'
                      : '已扫描 $_totalScanned 条订单，发现 ${_results.length} 条异常',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF666666)),
                ),
                const Spacer(),
                if (_results.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1E8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${_results.length} 异常',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFFF5000))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 结果列表
          Expanded(
            child: _scanning
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF5000)))
                : _results.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle,
                                size: 60, color: Color(0xFF2A9655)),
                            SizedBox(height: 12),
                            Text('所有订单数据一致，无异常',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2A9655))),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _buildResultCard(_results[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(_AuditResult r) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD1B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber,
                  size: 16, color: Color(0xFFFF5000)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(r.shop.shopName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              Text(r.item.statusTitle,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF999999))),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xFF333333))),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 8),
          ...r.issues.map((issue) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFFF5000))),
                    Expanded(
                      child: Text(issue,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _AuditResult {
  final ShoppingCartShop shop;
  final OrderItem item;
  final List<String> issues;

  _AuditResult({
    required this.shop,
    required this.item,
    required this.issues,
  });
}
