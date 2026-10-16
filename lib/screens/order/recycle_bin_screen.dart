import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/cart_provider.dart';

/// v1.9.166：订单回收站——删除的订单存整单快照，可一键恢复。
/// 入口：订单列表 ⋯ 面板「回收站」。
class RecycleBinScreen extends StatelessWidget {
  const RecycleBinScreen({super.key});

  static String _fmtMoney(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    var s = v.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('订单回收站',
            style: TextStyle(fontSize: 16, color: Colors.black87)),
        centerTitle: true,
        actions: [
          Consumer<CartProvider>(
            builder: (context, provider, _) {
              if (provider.recycleBinCount == 0) {
                return const SizedBox.shrink();
              }
              return TextButton(
                onPressed: () => _confirmClear(context, provider),
                child: const Text('清空',
                    style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
              );
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, provider, _) {
          final bin = provider.recycleBin;
          if (bin.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_outline,
                      size: 52, color: Color(0xFFCCCCCC)),
                  SizedBox(height: 12),
                  Text('回收站是空的',
                      style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                  SizedBox(height: 6),
                  Text('删除的订单会先进这里，可随时恢复',
                      style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: bin.length,
            itemBuilder: (context, i) {
              final shop = bin[i];
              final orderNo =
                  shop.items.isNotEmpty ? shop.items.first.orderNo : '';
              return _buildCard(context, provider, shop, orderNo);
            },
          );
        },
      ),
    );
  }

  Widget _buildCard(BuildContext context, CartProvider provider,
      ShoppingCartShop shop, String orderNo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shop.shopName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                ),
              ),
              Text(
                shop.orderStatus,
                style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final it in shop.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '${it.title} ×${it.quantity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '实付 ¥${_fmtMoney(shop.actualTotal)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  orderNo.isEmpty ? '' : '单号 $orderNo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFEEEEEE)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () =>
                    _confirmPermanentDelete(context, provider, shop, orderNo),
                child: const Text('彻底删除',
                    style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
              ),
              const SizedBox(width: 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5000),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () => _doRestore(context, provider, orderNo),
                child: const Text('恢复',
                    style: TextStyle(fontSize: 13, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _doRestore(BuildContext context, CartProvider provider, String orderNo) {
    final ok = provider.restoreFromRecycleBin(orderNo);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok ? '已恢复该订单' : '恢复失败，订单已不在回收站'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _confirmPermanentDelete(BuildContext context, CartProvider provider,
      ShoppingCartShop shop, String orderNo) {
    showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('彻底删除？', style: TextStyle(fontSize: 16)),
        content: const Text('彻底删除后无法恢复，确定删除吗？', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child:
                  const Text('删除', style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    ).then((ok) {
      if (ok != true) return;
      provider.permanentlyDeleteFromRecycleBin(orderNo);
    });
  }

  void _confirmClear(BuildContext context, CartProvider provider) {
    showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空回收站？', style: TextStyle(fontSize: 16)),
        content:
            const Text('清空后这些订单无法恢复，确定清空吗？', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child:
                  const Text('清空', style: TextStyle(color: Color(0xFFFF5000)))),
        ],
      ),
    ).then((ok) {
      if (ok == true) provider.clearRecycleBin();
    });
  }
}
