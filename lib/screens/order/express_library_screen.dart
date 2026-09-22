import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import 'logistics_screen.dart';

/// 物流页（v1.9.149 重做：独立物流单库）
/// 抓快递物流脚本导入 JSON 后，所有带运单号的物流单——不论对应订单
/// 存不存在于本地订单列表——都会单独列在这里；点一条进该单物流详情。
/// 入口：我的淘宝「快递」图标、订单列表 ⋯ 面板「我的快递」。
/// 数据源：CartProvider.expressRecords（SharedPreferences 独立存储），
/// 与订单列表完全解耦，删订单/清空订单不影响物流单。
class ExpressLibraryScreen extends StatefulWidget {
  const ExpressLibraryScreen({super.key});

  @override
  State<ExpressLibraryScreen> createState() => _ExpressLibraryScreenState();
}

class _ExpressLibraryScreenState extends State<ExpressLibraryScreen> {
  String _query = '';

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  /// 最新一条轨迹文案（tag + text）
  static (String, String) _latestOf(ExpressRecord r) {
    if (r.tracesJson.isNotEmpty) {
      try {
        final list = jsonDecode(r.tracesJson) as List;
        for (final e in list) {
          if (e is! Map) continue;
          final text = (e['text'] ?? '').toString();
          if (text.isEmpty) continue;
          return ((e['tag'] ?? '').toString(), text);
        }
      } catch (_) {}
    }
    return ('', r.logistics);
  }

  void _confirmDelete(ExpressRecord r) {
    showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除这条物流单？', style: TextStyle(fontSize: 16)),
        content: Text(
          '${r.shipCompany.isNotEmpty ? r.shipCompany : '快递'} ${r.waybillNo}\n\n'
          '只从物流页删除，不影响订单列表里的任何订单；'
          '下次抓包导入同一单号会重新出现。',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
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
      if (ok == true) {
        context.read<CartProvider>().deleteExpressRecord(r.waybillNo);
        _toast('已删除');
      }
    });
  }

  void _confirmClearAll(int count) {
    showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空全部物流单？', style: TextStyle(fontSize: 16)),
        content: Text(
          '将删除物流页全部 $count 条物流单（订单列表不受影响）。\n\n'
          '下次抓包导入会重新把抓到的物流单填进来。',
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
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
    ).then((ok) async {
      if (ok == true) {
        await context.read<CartProvider>().clearExpressRecords();
        _toast('已清空');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CartProvider>();
    final all = provider.expressRecords;
    final q = _query.trim().toLowerCase();
    final records = q.isEmpty
        ? all
        : all.where((r) {
            return r.waybillNo.toLowerCase().contains(q) ||
                r.shipCompany.toLowerCase().contains(q) ||
                r.title.toLowerCase().contains(q) ||
                r.shopName.toLowerCase().contains(q) ||
                r.orderNo.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text('物流（${all.length}）',
            style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        actions: [
          if (all.isNotEmpty)
            IconButton(
              tooltip: '清空',
              icon: const Icon(Icons.delete_sweep_outlined,
                  size: 22, color: Color(0xFF666666)),
              onPressed: () => _confirmClearAll(all.length),
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索：单号/公司/商品/店铺/订单号
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: '搜运单号 / 快递公司 / 商品 / 店铺 / 订单号',
                hintStyle: const TextStyle(
                    fontSize: 12, color: Color(0xFFBBBBBB)),
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: Color(0xFF999999)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        q.isEmpty
                            ? '暂无物流单\n\n'
                                '在电脑上运行「抓快递物流」脚本（可抓全部订单），\n'
                                '把生成的 JSON 通过「同步订单」导入后，\n'
                                '所有抓到的物流单都会出现在这里\n'
                                '（订单在不在本地都算，不会新增订单卡片）'
                            : '没有匹配「$_query」的物流单',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF999999),
                            height: 1.7),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = records[i];
                      final (tag, latest) = _latestOf(r);
                      final linked = provider.orderNoExists(r.orderNo);
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LogisticsScreen(
                                  express: r, shopName: r.shopName),
                            ),
                          ),
                          onLongPress: () => _confirmDelete(r),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 公司 logo（抓包官方 logo 或色块首字）
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: r.shipLogo.isNotEmpty
                                      ? Image.network(r.shipLogo,
                                          width: 36,
                                          height: 36,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _logoFallback(r))
                                      : _logoFallback(r),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${r.shipCompany.isNotEmpty ? r.shipCompany : '快递'}'
                                              '  ${r.waybillNo}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1A1A1A)),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          // 已关联订单 / 独立单 角标
                                          Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: linked
                                                  ? const Color(0xFFE8F6E8)
                                                  : const Color(0xFFFFF3E8),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              linked ? '已关联订单' : '独立单',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: linked
                                                    ? const Color(0xFF2E7D32)
                                                    : const Color(0xFFFF6A00),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        latest.isEmpty
                                            ? '暂无轨迹'
                                            : (tag.isNotEmpty
                                                ? '$tag · $latest'
                                                : latest),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF999999)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        r.title.isNotEmpty
                                            ? '${r.shopName.isNotEmpty ? '${r.shopName} · ' : ''}${r.title}'
                                            : (r.shopName.isNotEmpty
                                                ? r.shopName
                                                : '来源：抓包导入'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFFBBBBBB)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => _confirmDelete(r),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.close,
                                        size: 16, color: Color(0xFFCCCCCC)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logoFallback(ExpressRecord r) {
    return Container(
      width: 36,
      height: 36,
      color: const Color(0xFF7B5AA6),
      alignment: Alignment.center,
      child: Text(
        r.shipCompany.isNotEmpty ? r.shipCompany.characters.first : '递',
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
    );
  }
}
