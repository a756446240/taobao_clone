import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_image_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/image_picker_helper.dart';

/// 退款详情页（照 3.4 APK：大标题 + 副标题/倒计时 + 三步进度 + 金额卡 + 协商历史）
class RefundDetailScreen extends StatefulWidget {
  final ShoppingCartShop shop;
  final OrderItem item;

  const RefundDetailScreen({
    super.key,
    required this.shop,
    required this.item,
  });

  @override
  State<RefundDetailScreen> createState() => _RefundDetailScreenState();
}

class _RefundDetailScreenState extends State<RefundDetailScreen> {
  late OrderItem _item;
  late ShoppingCartShop _shop;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _shop = widget.shop;
    _ensureDefaults();
    _startTimerIfPending();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 补齐退款字段默认值（不落盘，仅展示用推导）
  void _ensureDefaults() {
    // 状态：优先读持久化字段；根据订单状态标题推导
    if (_item.refundStatus.isEmpty) {
      _item.refundStatus =
          _item.statusTitle.contains('待商家退款') ? '待商家退款' : '退款成功';
    }
    if (_item.refundTitle.isEmpty) _item.refundTitle = _item.refundStatus;
    if (_item.refundMethod.isEmpty) {
      _item.refundMethod =
          _item.paymentMethod.contains('微信') ? '微信支付' : '支付宝';
    }
    if (_item.refundAmount <= 0) {
      _item.refundAmount =
          double.parse((_item.price * _item.quantity).toStringAsFixed(2));
    }
    if (_item.refundApplyTime.isEmpty) {
      _item.refundApplyTime =
          _item.payTime.isNotEmpty ? _item.payTime : _item.createTime;
    }
    if (_item.refundDoneTime.isEmpty) {
      _item.refundDoneTime =
          _item.shipTime.isNotEmpty ? _item.shipTime : _item.createTime;
    }
  }

  bool get _isPending =>
      _item.refundStatus == '待商家退款' || _item.refundStatus == '退款中';
  bool get _isDone => !_isPending;

  void _startTimerIfPending() {
    _timer?.cancel();
    if (_isPending) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// 商家处理倒计时（申请时间 + 3 天）
  (int, int, int) _merchantCountdown() {
    try {
      final t = DateTime.parse(_item.refundApplyTime.replaceFirst(' ', 'T'));
      final end = t.add(const Duration(days: 3));
      final diff = end.difference(DateTime.now());
      if (diff.isNegative) return (0, 0, 0);
      return (diff.inDays, diff.inHours % 24, diff.inMinutes % 60);
    } catch (_) {
      return (2, 14, 30);
    }
  }

  String get _subtitle {
    if (_item.refundSubtitle.isNotEmpty) return _item.refundSubtitle;
    if (_isPending) {
      final (d, h, m) = _merchantCountdown();
      return '商家还有${d}天${h}小时${m}分处理，如超时将自动退款';
    }
    return '退款原路退回至${_item.refundMethod}';
  }

  @override
  Widget build(BuildContext context) {
    context.watch<CartProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: [
                    _buildStatusHeader(),
                    _buildAmountCard(),
                    if (_isPending && _item.refundLogistics.isNotEmpty)
                      _buildLogisticsCard(),
                    _buildShopRow(),
                    _buildProductCard(),
                    _buildHistoryCard(),
                    _buildRecommendCard(),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  // ============ 顶部栏 ============
  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back_ios,
                color: Colors.black87, size: 22),
          ),
          const Expanded(
            child: Text('退款详情',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
          ),
          // 编辑入口：双击打开编辑菜单
          GestureDetector(
            onDoubleTap: () => _showEditMenu(),
            child:
                const Icon(Icons.more_horiz, color: Colors.black87, size: 24),
          ),
        ],
      ),
    );
  }

  // ============ 状态头（大标题 + 副标题/倒计时 + 三步进度） ============
  Widget _buildStatusHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Column(
        children: [
          GestureDetector(
            onDoubleTap: _editTitle,
            child: Text(
              _item.refundTitle,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A)),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onDoubleTap: _editSubtitle,
            child: Text(_subtitle,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ),
          const SizedBox(height: 14),
          _stepRow(),
        ],
      ),
    );
  }

  /// 三步进度条：申请退款 → 商家处理 → 退款结束
  Widget _stepRow() {
    Widget node(String label, bool done, bool current) {
      final color = (done || current)
          ? const Color(0xFFFF5000)
          : const Color(0xFFCCCCCC);
      return Column(
        children: [
          Icon(done ? Icons.check_circle : Icons.circle_outlined,
              size: 18, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color)),
        ],
      );
    }

    Widget line(bool done) {
      return Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.only(bottom: 16),
          color: done ? const Color(0xFFFF5000) : const Color(0xFFE5E5E5),
        ),
      );
    }

    final done = _isDone;
    return Row(
      children: [
        node('申请退款', true, false),
        line(true),
        node('商家处理', done, _isPending),
        line(done),
        node('退款结束', done, false),
      ],
    );
  }

  // ============ 退款金额卡 ============
  Widget _buildAmountCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          GestureDetector(
            onDoubleTap: _editRefundAmount,
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Color(0xFFFF5000), size: 20),
                const SizedBox(width: 8),
                Text(_isPending ? '预计退款金额' : '退款金额',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF333333))),
                const Spacer(),
                Text('¥${_item.refundAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 20,
                        color: Color(0xFFFF5000),
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (_isDone) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onDoubleTap: _editRefundMethod,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(4)),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_downward,
                        color: Color(0xFF2A9655), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '退回至${_item.refundMethod}  ¥${_item.refundAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF333333)),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ 退款物流 ============
  Widget _buildLogisticsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(12),
      child: GestureDetector(
        onDoubleTap: _editRefundLogistics,
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined,
                color: Color(0xFFFF5000), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('退款物流',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text(_item.refundLogistics,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ============ 店铺行 ============
  Widget _buildShopRow() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
                color: Color(0xFFFF5000), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('淘',
                style: TextStyle(fontSize: 10, color: Colors.white)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_shop.shopName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87)),
          ),
          const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  // ============ 商品卡 ============
  Widget _buildProductCard() {
    final override =
        context.watch<ProductImageProvider>().imageFor(_item.title);
    final imageUrl = override ?? _item.imageUrl;
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onDoubleTap: () => pickProductImageFromGallery(context, _item.title),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(6)),
              clipBehavior: Clip.antiAlias,
              child: AppImage(url: imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 4),
                Text(_item.configuration,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('实付价 ',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text('¥${_item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFFF5000),
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        size: 14, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ 协商历史 ============
  Widget _buildHistoryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('协商历史',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 10),
          _historyItem(
            '申请退款',
            '退款金额 ¥${_item.refundAmount.toStringAsFixed(2)} · 已提交申请',
            _item.refundApplyTime,
            true,
            onTap: () => _editTime('修改申请时间', _item.refundApplyTime, (v) {
              context
                  .read<CartProvider>()
                  .updateOrderItem(_item, refundApplyTime: v);
              setState(() {});
            }),
          ),
          _historyLine(),
          if (_isPending)
            _historyItem('商家处理', '等待商家处理中', '', false, pending: true)
          else
            _historyItem(
              '退款成功',
              '退款已原路退回至${_item.refundMethod}',
              _item.refundDoneTime,
              true,
              onTap: () => _editTime('修改完成时间', _item.refundDoneTime, (v) {
                context
                    .read<CartProvider>()
                    .updateOrderItem(_item, refundDoneTime: v);
                setState(() {});
              }),
            ),
        ],
      ),
    );
  }

  Widget _historyLine() {
    return Container(
      margin: const EdgeInsets.only(left: 5),
      width: 1,
      height: 16,
      color: const Color(0xFFE5E5E5),
    );
  }

  Widget _historyItem(String title, String desc, String time, bool done,
      {bool pending = false, VoidCallback? onTap}) {
    // 双击触发编辑
    final color = done
        ? const Color(0xFF2A9655)
        : (pending ? const Color(0xFFFF5000) : const Color(0xFF666666));
    return GestureDetector(
      onDoubleTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(pending ? Icons.schedule : (done ? Icons.check_circle : Icons.circle),
              size: 12, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13, color: color, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(desc,
                    style:
                        const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF999999))),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  // ============ 推荐商品 ============
  Widget _buildRecommendCard() {
    final goods = MockData.guessLikeGoods.take(6).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: Color(0xFFFF5000), size: 16),
              SizedBox(width: 4),
              Text('推荐商品',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 170,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: goods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => _recommendItem(goods[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendItem(SearchResultItem g) {
    final override =
        context.watch<ProductImageProvider>().imageFor(g.title);
    final imageUrl = override ?? g.imageUrl;
    return GestureDetector(
      onDoubleTap: () => pickProductImageFromGallery(context, g.title),
      child: SizedBox(
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(6)),
              clipBehavior: Clip.antiAlias,
              child: AppImage(url: imageUrl, fit: BoxFit.cover),
            ),
            const SizedBox(height: 4),
            Text(g.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11)),
            Text('¥${g.price}',
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFFF5000),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ============ 底部栏 ============
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _bottomIcon(Icons.support_agent, '客服'),
              _bottomIcon(Icons.help_outline, '帮助中心'),
              const Spacer(),
              if (_isPending) ...[
                _smallBtn('寄件详情'),
                const SizedBox(width: 8),
                _smallBtn('平台介入'),
                const SizedBox(width: 8),
                _bigBtn('催处理'),
              ] else ...[
                _smallBtn('删除记录', onTap: _confirmDelete),
                const SizedBox(width: 8),
                _bigBtn('再次购买'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomIcon(IconData ic, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 20, color: const Color(0xFF666666)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  const TextStyle(fontSize: 10, color: Color(0xFF666666))),
        ],
      ),
    );
  }

  Widget _smallBtn(String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
      ),
    );
  }

  Widget _bigBtn(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFFF5000), Color(0xFFFF2E00)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, color: Colors.white)),
    );
  }

  // ============ 编辑入口 ============
  /// 修改完成后的统一反馈
  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }

  void _editTitle() {
    DialogHelpers.showTextInput(context,
            title: '修改大标题', initial: _item.refundTitle)
        .then((v) {
      if (v != null && v.isNotEmpty) {
        context.read<CartProvider>().updateOrderItem(_item, refundTitle: v);
        setState(() {});
        _toast('大标题已修改：$v');
      }
    });
  }

  void _editSubtitle() {
    DialogHelpers.showTextInput(context,
            title: '修改副标题（留空=自动生成）', initial: _item.refundSubtitle)
        .then((v) {
      if (v != null) {
        context.read<CartProvider>().updateOrderItem(_item, refundSubtitle: v);
        setState(() {});
        _toast(v.isEmpty ? '副标题已恢复自动生成' : '副标题已修改：$v');
      }
    });
  }

  void _editRefundAmount() {
    DialogHelpers.showTextInput(context,
            title: '修改退款金额',
            initial: _item.refundAmount.toStringAsFixed(2))
        .then((v) {
      final n = double.tryParse(v ?? '');
      if (n != null && n > 0) {
        context
            .read<CartProvider>()
            .updateOrderItem(_item, refundAmount: n);
        setState(() {});
        _toast('退款金额已修改为 ¥${n.toStringAsFixed(2)}');
      }
    });
  }

  void _editRefundMethod() {
    DialogHelpers.showOptionPicker(
      context,
      title: '选择退款方式',
      options: const ['支付宝', '银行卡', '微信支付'],
      currentValue: _item.refundMethod,
    ).then((v) {
      if (v != null) {
        context.read<CartProvider>().updateOrderItem(_item, refundMethod: v);
        setState(() {});
        _toast('退款方式已切换为「$v」');
      }
    });
  }

  void _editRefundLogistics() {
    DialogHelpers.showTextInput(context,
            title: '修改退款物流（留空=不显示）', initial: _item.refundLogistics)
        .then((v) {
      if (v != null) {
        context
            .read<CartProvider>()
            .updateOrderItem(_item, refundLogistics: v);
        setState(() {});
        _toast(v.isEmpty ? '退款物流已隐藏' : '退款物流已修改：$v');
      }
    });
  }

  void _editTime(String title, String initial, ValueChanged<String> onSave) {
    DialogHelpers.showDateTimePicker(context, title: title, initial: initial)
        .then((v) {
      if (v != null && v.isNotEmpty) {
        onSave(v);
        _toast('$title成功：$v');
      }
    });
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('删除此退款记录？', style: TextStyle(fontSize: 16)),
        content: const Text('删除后不可恢复', style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              context.read<CartProvider>().removeItem(_item);
              Navigator.of(context).pop();
            },
            child:
                const Text('删除', style: TextStyle(color: Color(0xFFA32D2D))),
          ),
        ],
      ),
    );
  }

  // ============ 右上角编辑菜单 ============
  void _showEditMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: Color(0xFFf0f0f0))),
              ),
              child: Row(
                children: [
                  const Text('退款编辑',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: const Icon(Icons.close, color: Color(0xFF999999)),
                  ),
                ],
              ),
            ),
            _menuTile(ctx, Icons.flag, '修改退款状态', () {
              DialogHelpers.showOptionPicker(
                context,
                title: '选择退款状态',
                options: const ['待商家退款', '退款成功', '退款结束'],
                currentValue: _item.refundStatus,
              ).then((v) {
                if (v != null) {
                  final provider = context.read<CartProvider>();
                  provider.updateOrderItem(_item, refundStatus: v);
                  // 大标题跟随状态（未手动改过的话）
                  if (_item.refundTitle == '退款成功' ||
                      _item.refundTitle == '待商家退款' ||
                      _item.refundTitle == '退款结束') {
                    provider.updateOrderItem(_item, refundTitle: v);
                  }
                  // 同步订单栏目归类
                  provider.updateOrderStatus(_shop, _item, v);
                  setState(() {});
                  _startTimerIfPending();
                  _toast('退款状态已修改为「$v」');
                }
              });
            }),
            _menuTile(ctx, Icons.account_balance_wallet, '修改退款方式',
                _editRefundMethod),
            _menuTile(ctx, Icons.title, '修改大标题', _editTitle),
            _menuTile(ctx, Icons.notes, '修改副标题', _editSubtitle),
            _menuTile(ctx, Icons.payments, '修改退款金额', _editRefundAmount),
            _menuTile(ctx, Icons.local_shipping, '修改退款物流',
                _editRefundLogistics),
            _menuTile(ctx, Icons.schedule, '修改申请时间（滚动选择）', () {
              _editTime('修改申请时间', _item.refundApplyTime, (v) {
                context
                    .read<CartProvider>()
                    .updateOrderItem(_item, refundApplyTime: v);
                setState(() {});
              });
            }),
            _menuTile(ctx, Icons.event_available, '修改完成时间（滚动选择）', () {
              _editTime('修改完成时间', _item.refundDoneTime, (v) {
                context
                    .read<CartProvider>()
                    .updateOrderItem(_item, refundDoneTime: v);
                setState(() {});
              });
            }),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: Color(0xFFA32D2D)),
              title: const Text('删除',
                  style: TextStyle(color: Color(0xFFA32D2D))),
              onTap: () {
                Navigator.of(ctx).pop();
                _confirmDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
      BuildContext sheetCtx, IconData icon, String label, VoidCallback onTap) {
    // 编辑菜单内的按钮：单击直接修改（入口双击、菜单内单击规则）
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF666666)),
      title: Text(label),
      trailing:
          const Icon(Icons.chevron_right, color: Color(0xFFcccccc)),
      onTap: () {
        Navigator.of(sheetCtx).pop();
        onTap();
      },
    );
  }
}
