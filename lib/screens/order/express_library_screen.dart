import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import 'logistics_screen.dart';

/// 快递库（v1.9.136）：汇总所有订单里抓包/联网拿到的真实快递
/// （抓包物流 JSON 导入后自动出现在这里），点一条进该单物流详情。
/// 入口：我的淘宝「快递」图标、订单列表 ⋯ 面板「我的快递」、
/// 物流页双击「包裹」的选择列表同源。
class ExpressLibraryScreen extends StatelessWidget {
  const ExpressLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CartProvider>();
    // 收集所有有真实单号或抓包时间线的商品行（新订单在前）
    final entries = <(ShoppingCartShop, OrderItem)>[];
    for (final shop in provider.shops) {
      for (final e in shop.items) {
        if (e.waybillNo.isNotEmpty || e.logisticsTraces.isNotEmpty) {
          entries.add((shop, e));
        }
      }
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text('快递库（${entries.length}）',
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '暂无快递记录\n\n用抓包脚本（抓快递物流）抓取后，\n在「我的 → 长按足迹 → 同步订单」导入 JSON，\n抓到的快递会自动出现在这里',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final (shop, e) = entries[i];
                String latest = '';
                try {
                  final list = jsonDecode(e.logisticsTraces) as List;
                  if (list.isNotEmpty) {
                    latest = (list.first['text'] ?? '').toString();
                  }
                } catch (_) {}
                if (latest.isEmpty) latest = e.logistics;
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LogisticsScreen(
                            item: e, shopName: shop.shopName),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // 公司 logo（抓包带回的官方 logo 或色块首字）
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: e.shipLogo.isNotEmpty
                                ? Image.network(e.shipLogo,
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _logoFallback(e))
                                : _logoFallback(e),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.shipCompany.isNotEmpty ? e.shipCompany : '快递'}'
                                  '  ${e.waybillNo}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  latest.isEmpty ? '暂无轨迹' : latest,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF999999)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  shop.shopName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFBBBBBB)),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 18, color: Color(0xFFCCCCCC)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _logoFallback(OrderItem e) {
    return Container(
      width: 36,
      height: 36,
      color: const Color(0xFF7B5AA6),
      alignment: Alignment.center,
      child: Text(
        e.shipCompany.isNotEmpty ? e.shipCompany.characters.first : '递',
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
    );
  }
}
