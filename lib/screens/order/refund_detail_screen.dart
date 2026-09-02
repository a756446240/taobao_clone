import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_image_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/image_picker_helper.dart';
import 'refund_reason_picker.dart';
import '../message/chat_screen.dart';

/// 退款详情页 v3.5 整改版
/// 新增：未发货秒退横幅、运费保障、可折叠协商历史、寄件详情、
/// "您是否遇到以下问题？"反馈区、AI 随机商品推荐、4 开头 17 位退款编号、可选退款原因
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CartProvider>().updateOrderItem(_item);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 补齐退款字段默认值
  void _ensureDefaults() {
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
      _item.refundAmount = double.parse(_item.price.toStringAsFixed(2));
    }
    if (_item.refundApplyTime.isEmpty) {
      _item.refundApplyTime =
          _item.payTime.isNotEmpty ? _item.payTime : _item.createTime;
    }
    if (_item.refundDoneTime.isEmpty) {
      _item.refundDoneTime =
          _item.shipTime.isNotEmpty ? _item.shipTime : _item.createTime;
    }
    // 退款编号：4 开头 17 位随机生成
    if (_item.refundNumber.isEmpty) {
      _item.refundNumber = _genRefundNumber();
    }
    // 未发货秒退：状态是退款成功 && 没有发货时间 && 申请时间跟完成时间接近
    if (_item.shipTime.isEmpty && !_isPending) {
      _item.isInstantRefund = true;
    }
  }

  /// 生成 4 开头 17 位退款编号
  String _genRefundNumber() {
    final rand = Random();
    final sb = StringBuffer('4');
    for (var i = 0; i < 16; i++) {
      sb.write(rand.nextInt(10));
    }
    return sb.toString();
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
                    // 未发货秒退横幅（可关）
                    if (_item.isInstantRefund &&
                        _item.showInstantRefundBanner &&
                        _isDone)
                      _buildInstantRefundBanner(),
                    _buildAmountCard(),
                    if (_isPending && _item.refundLogistics.isNotEmpty)
                      _buildLogisticsCard(),
                    _buildShopRow(),
                    _buildProductCard(),
                    _buildRefundInfoCard(),
                    _buildRecommendCard(),
                    // "您是否遇到以下问题？"反馈区（可关）
                    if (_item.showHelpSection) _buildHelpSection(),
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

  // ============ 未发货秒退横幅 ============
  Widget _buildInstantRefundBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4E8), Color(0xFFFFE8D1)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5000),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('未发货秒退',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('未发货订单享受秒退款',
                style: TextStyle(fontSize: 12, color: Color(0xFF8B4513))),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _item.showInstantRefundBanner = false;
              });
              context.read<CartProvider>().updateOrderItem(_item);
            },
            child: const Icon(Icons.close, size: 16, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  // ============ 退款金额卡（含运费保障） ============
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
            // 退款明细列表（参考图 6：退回花呗/返还优惠/退回淘金币/运费保障）
            _buildRefundDetailRow(
              icon: Icons.account_balance,
              label: '退回${_item.refundMethod}',
              value: '¥${_item.refundAmount.toStringAsFixed(2)}',
              iconColor: const Color(0xFF1890FF),
              onDoubleTap: _editRefundMethod,
            ),
            if (_item.refundDiscount > 0 && _item.showRefundDiscount)
              _buildRefundDetailRow(
                icon: Icons.card_giftcard,
                label: '返还优惠',
                value: '¥${_item.refundDiscount.toStringAsFixed(2)}',
                iconColor: const Color(0xFFFF8C00),
              ),
            if (_item.returnedCoins > 0)
              _buildRefundDetailRow(
                icon: Icons.monetization_on,
                label: '退回淘金币',
                value: '${_item.returnedCoins}个',
                iconColor: const Color(0xFFFFB300),
              ),
            // 运费保障（参考图 6 红框）
            if (_item.hasFreightInsurance)
              _buildRefundDetailRow(
                icon: Icons.shield_outlined,
                label: '运费保障',
                value: '',
                iconColor: const Color(0xFFFF5000),
                sublabel: '您已享受全额保障${_item.freightInsuranceAmount.toStringAsFixed(2)}元',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildRefundDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    String? sublabel,
    VoidCallback? onDoubleTap,
  }) {
    return GestureDetector(
      onDoubleTap: onDoubleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF333333))),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF999999))),
                  ],
                ],
              ),
            ),
            if (value.isNotEmpty)
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.w600)),
          ],
        ),
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

  // ============ 协商历史 + 退款信息（可折叠） ============
  Widget _buildRefundInfoCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('协商历史',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A))),
              const Spacer(),
              GestureDetector(
                onTap: _showNegotiationSheet,
                child: const Text('查看',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF999999))),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 退款完结行
          _historyItem(
            _isPending ? '商家处理' : '退款完结',
            _isPending ? '等待商家处理中' : '退款已原路退回至${_item.refundMethod}',
            _isPending ? '' : _item.refundDoneTime,
            _isDone,
            pending: _isPending,
          ),
          const SizedBox(height: 12),
          // 可折叠的"查看全部售后信息"
          GestureDetector(
            onTap: () {
              setState(() {
                _item.refundInfoCollapsed = !_item.refundInfoCollapsed;
              });
              context.read<CartProvider>().updateOrderItem(_item);
            },
            child: Row(
              children: [
                Text(
                  _item.refundInfoCollapsed ? '查看全部售后信息' : '收起售后信息',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF666666)),
                ),
                Icon(
                  _item.refundInfoCollapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  size: 16,
                  color: const Color(0xFF999999),
                ),
              ],
            ),
          ),
          // 展开的售后信息（参考图 8）
          if (!_item.refundInfoCollapsed) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 10),
            _infoRow('退款原因',
                _item.refundReason.isEmpty ? '点击选择' : _item.refundReason,
                onTap: _pickRefundReason, isLink: _item.refundReason.isEmpty),
            _infoRow('申请金额',
                '共${_item.refundAmount.toStringAsFixed(2)}元'),
            _infoRow('退款完结', _item.refundDoneTime),
            _infoRow('申请时间', _item.refundApplyTime),
            _infoRowWithCopy('退款编号', _item.refundNumber),
          ],
        ],
      ),
    );
  }

  /// 完整协商历史弹层（基于真实退款字段构建时间线）
  void _showNegotiationSheet() {
    final steps = <(String, String, String, int)>[
      // (标题, 描述, 时间, 状态) 状态: 0=已发生 1=当前 2=未发生
      (
        '买家申请退款',
        '退款原因：${_item.refundReason.isEmpty ? '未填写' : _item.refundReason} · 申请金额 ¥${_item.refundAmount.toStringAsFixed(2)}',
        _item.refundApplyTime,
        0,
      ),
      if (_isPending)
        ('商家处理中', '等待商家处理，逾期未处理将自动同意', '', 1)
      else ...[
        ('商家同意退款', '商家同意了本次退款申请', '', 0),
        ('退款完结', '退款已原路退回至${_item.refundMethod}', _item.refundDoneTime, 1),
      ],
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('协商历史',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < steps.length; i++) ...[
                _negoStep(steps[i], isFirst: i == steps.length - 1),
                if (i != steps.length - 1)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    width: 2,
                    height: 26,
                    color: const Color(0xFFE5E5E5),
                  ),
              ],
              const SizedBox(height: 10),
              Text('退款编号：${_item.refundNumber}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF999999))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _negoStep((String, String, String, int) s, {bool isFirst = false}) {
    final color = s.$4 == 1
        ? const Color(0xFFFF5000)
        : const Color(0xFF2A9655);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          s.$4 == 1 ? Icons.schedule : Icons.check_circle,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.$1,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isFirst ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF1A1A1A))),
              if (s.$2.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(s.$2,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF999999))),
              ],
              if (s.$3.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(s.$3,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFBBBBBB))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _historyItem(String title, String desc, String time, bool done,
      {bool pending = false}) {
    final color = done
        ? const Color(0xFF2A9655)
        : (pending ? const Color(0xFFFF5000) : const Color(0xFF666666));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
            pending
                ? Icons.schedule
                : (done ? Icons.check_circle : Icons.circle),
            size: 14,
            color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 13, color: color, fontWeight: FontWeight.w500)),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF666666))),
              ],
              if (time.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(time,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF999999))),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value,
      {VoidCallback? onTap, bool isLink = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFF999999))),
          const Spacer(),
          GestureDetector(
            onTap: onTap,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isLink ? const Color(0xFFFF5000) : const Color(0xFF1A1A1A),
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithCopy(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: Color(0xFF999999))),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1A1A1A))),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              _toast('已复制：$value');
            },
            child: const Text('复制',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ),
        ],
      ),
    );
  }

  // ============ 推荐商品（AI 随机） ============
  Widget _buildRecommendCard() {
    // AI 随机：每次 build 都从 MockData 随机抽 6 个（实际产品可加缓存避免每次滚动都换）
    final allGoods = MockData.guessLikeGoods.toList();
    allGoods.shuffle(Random());
    final goods = allGoods.take(6).toList();
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFFF5000), size: 16),
              const SizedBox(width: 4),
              const Text('推荐商品',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {}), // 换一换
                child: const Row(
                  children: [
                    Text('换一换',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF999999))),
                    Icon(Icons.refresh, size: 14, color: Color(0xFF999999)),
                  ],
                ),
              ),
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

  // ============ "您是否遇到以下问题？"反馈区 ============
  Widget _buildHelpSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline,
                  size: 16, color: Color(0xFF999999)),
              const SizedBox(width: 4),
              const Text('您是否遇到以下问题？',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A))),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _item.showHelpSection = false;
                  });
                  context.read<CartProvider>().updateOrderItem(_item);
                },
                child: const Icon(Icons.close,
                    size: 16, color: Color(0xFF999999)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _helpChip('没有退款入口'),
              _helpChip('商品有问题'),
              _helpChip('运费谁承担'),
              _helpChip('催促商家处理'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _helpChip(String label) {
    return GestureDetector(
      onTap: () => _toast('已记录：$label'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 12, color: Color(0xFF333333))),
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
              _bottomIcon(Icons.support_agent, '客服',
                  onTap: _gotoServiceChat),
              _bottomIcon(Icons.help_outline, '帮助中心',
                  onTap: _showHelpSheet),
              const Spacer(),
              if (_isPending) ...[
                _smallBtn('寄件详情', onTap: _showShipDetailSheet),
                const SizedBox(width: 8),
                _smallBtn('平台介入', onTap: _showInterveneSheet),
                const SizedBox(width: 8),
                _bigBtn('催处理',
                    onTap: () => _toast('已提醒商家尽快处理，请耐心等待')),
              ] else ...[
                // 寄件详情（参考图 9 红框）
                if (_item.showShipDetailBtn) ...[
                  _smallBtn('寄件详情', onTap: _showShipDetailSheet),
                  const SizedBox(width: 8),
                ],
                _smallBtn('删除记录', onTap: _confirmDelete),
                const SizedBox(width: 8),
                _bigBtn('钱款去向', onTap: _showMoneyFlowSheet),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomIcon(IconData ic, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ic, size: 20, color: const Color(0xFF666666)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF666666))),
          ],
        ),
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

  Widget _bigBtn(String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF5000), Color(0xFFFF2E00)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.white)),
      ),
    );
  }

  /// 底部「客服」→ 真实进入店铺客服会话
  void _gotoServiceChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: Conversation(
            avatar: '',
            title: _shop.shopName,
            description: '退款售后咨询',
            createAt: '',
          ),
          accentColor: const Color(0xFFFF5000),
        ),
      ),
    );
  }

  /// 寄件详情弹层
  void _showShipDetailSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('寄件详情',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              _shipRow('物流信息', _item.refundLogistics),
              _shipRow('寄件人', '张* 138****8888'),
              _shipRow('寄件地址', '江苏省南京市江宁区诚信大道 88 号'),
              _shipRow('收件人', '${_shop.shopName}（退货仓）'),
              _shipRow('申请时间', _item.refundApplyTime),
              const SizedBox(height: 6),
              const Text('退货请在商家同意后 7 天内寄出，逾期退款通道将关闭。',
                  style: TextStyle(
                      color: Color(0xFF999999), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shipRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(k,
                style: const TextStyle(
                    color: Color(0xFF999999), fontSize: 13)),
          ),
          Expanded(
              child: Text(v, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  /// 平台介入弹层：说明 + 真实提交
  void _showInterveneSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('申请平台介入',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text(
                  '商家超过处理时效或您与商家协商不一致时，可申请淘宝客服介入。介入后平台将在 48 小时内根据双方凭证做出判定。',
                  style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                      height: 1.6)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5000)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _toast('平台介入申请已提交，客服将在 48 小时内处理');
                  },
                  child: const Text('提交申请'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 钱款去向弹层
  void _showMoneyFlowSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('钱款去向',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              _shipRow('退款金额',
                  '¥${_item.refundAmount.toStringAsFixed(2)}'),
              _shipRow('退回方式', _item.refundMethod),
              _shipRow('到账时间', _item.refundDoneTime),
              _shipRow('退款编号', _item.refundNumber),
              const SizedBox(height: 6),
              const Text('退款已原路退回，银行处理可能存在 1-3 个工作日延迟。',
                  style: TextStyle(
                      color: Color(0xFF999999), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  /// 帮助中心弹层：常见问题
  void _showHelpSheet() {
    const faqs = <(String, String)>[
      ('退款多久到账？', '商家同意退款后，款项原路退回，余额实时到账，银行卡 1-3 个工作日。'),
      ('运费险怎么赔？', '退货完成后 72 小时内自动赔付至您的账户，上门取件可直接抵扣。'),
      ('商家拒绝退款怎么办？', '您可以在退款详情页申请平台介入，客服将依据双方凭证判定。'),
      ('如何修改退款金额？', '退款未完结前，可与商家协商后撤销申请，重新发起退款。'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: SizedBox(
          height: 420,
          child: Column(
            children: [
              const SizedBox(height: 14),
              const Text('帮助中心',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: faqs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemBuilder: (_, i) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(faqs[i].$1,
                        style: const TextStyle(fontSize: 13)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(faqs[i].$2,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF666666),
                                height: 1.6)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ 编辑入口 ============
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
      options: const ['支付宝', '银行卡', '微信支付', '花呗'],
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

  /// 选择退款原因（完整版弹窗：Tab 切换 + 12 个原因）
  void _pickRefundReason() {
    showRefundReasonPicker(context, currentReason: _item.refundReason)
        .then((v) {
      if (v != null) {
        setState(() {
          _item.refundReason = v;
        });
        context.read<CartProvider>().updateOrderItem(_item);
        _toast('退款原因已选择：$v');
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
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
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
                      child:
                          const Icon(Icons.close, color: Color(0xFF999999)),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _menuTile(ctx, Icons.flag, '修改退款状态', _pickRefundStatus),
                    _menuTile(ctx, Icons.account_balance_wallet, '修改退款方式',
                        _editRefundMethod),
                    _menuTile(ctx, Icons.title, '修改大标题', _editTitle),
                    _menuTile(ctx, Icons.notes, '修改副标题', _editSubtitle),
                    _menuTile(
                        ctx, Icons.payments, '修改退款金额', _editRefundAmount),
                    _menuTile(ctx, Icons.local_shipping, '修改退款物流',
                        _editRefundLogistics),
                    _menuTile(ctx, Icons.format_list_bulleted, '选择退款原因',
                        _pickRefundReason),
                    _menuTile(ctx, Icons.confirmation_number, '修改退款编号',
                        _editRefundNumber),
                    _menuTile(ctx, Icons.flash_on, '切换"未发货秒退"横幅', () {
                      setState(() {
                        _item.showInstantRefundBanner =
                            !_item.showInstantRefundBanner;
                      });
                      context.read<CartProvider>().updateOrderItem(_item);
                      _toast(_item.showInstantRefundBanner
                          ? '秒退横幅已显示'
                          : '秒退横幅已隐藏');
                    }),
                    _menuTile(ctx, Icons.shield, '切换"运费保障"', () {
                      setState(() {
                        _item.hasFreightInsurance = !_item.hasFreightInsurance;
                      });
                      context.read<CartProvider>().updateOrderItem(_item);
                      _toast(_item.hasFreightInsurance
                          ? '运费保障已显示'
                          : '运费保障已隐藏');
                    }),
                    _menuTile(ctx, Icons.help, '切换"您是否遇到问题"区', () {
                      setState(() {
                        _item.showHelpSection = !_item.showHelpSection;
                      });
                      context.read<CartProvider>().updateOrderItem(_item);
                      _toast(_item.showHelpSection
                          ? '帮助区已显示'
                          : '帮助区已隐藏');
                    }),
                    _menuTile(ctx, Icons.local_post_office, '切换"寄件详情"按钮', () {
                      setState(() {
                        _item.showShipDetailBtn = !_item.showShipDetailBtn;
                      });
                      context.read<CartProvider>().updateOrderItem(_item);
                      _toast(_item.showShipDetailBtn
                          ? '寄件详情已显示'
                          : '寄件详情已隐藏');
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
            ],
          ),
        ),
      ),
    );
  }

  void _editRefundNumber() {
    DialogHelpers.showTextInput(context,
            title: '修改退款编号（留空=重新生成）', initial: _item.refundNumber)
        .then((v) {
      if (v != null) {
        setState(() {
          _item.refundNumber = v.isEmpty ? _genRefundNumber() : v;
        });
        context.read<CartProvider>().updateOrderItem(_item);
        _toast('退款编号已修改：${_item.refundNumber}');
      }
    });
  }

  void _pickRefundStatus() {
    DialogHelpers.showOptionPicker(
      context,
      title: '修改退款状态（可改回待发货等状态）',
      options: CartProvider.orderStatusOptions,
      currentValue: _item.statusTitle.isNotEmpty
          ? _item.statusTitle
          : _item.refundStatus,
    ).then((v) {
      if (v == null) return;
      final provider = context.read<CartProvider>();
      provider.updateOrderStatus(_shop, _item, v);
      final isRefund = CartProvider.statusCategory(v) == '退款/售后';
      if (!mounted) return;
      if (isRefund) {
        setState(() {});
        _startTimerIfPending();
        _toast('退款状态已修改为「$v」');
      } else {
        _toast('已改回「$v」，可在订单列表对应栏目查看');
        Navigator.of(context).pop();
      }
    });
  }

  Widget _menuTile(
      BuildContext sheetCtx, IconData icon, String label, VoidCallback onTap) {
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
