import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'channel_orders.dart';

/// 闪购/飞猪频道订单的交互弹层（配送进度/发表评价/行程单/订单详情）
/// 时间为按订单 id 确定性生成，每次打开一致

int _hashOf(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

String _fmt(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String _fmtFull(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
    '${_fmt(t)}:${t.second.toString().padLeft(2, '0')}';

// ============ 闪购：配送进度 ============
void showDeliveryProgressSheet(BuildContext context, ChannelOrder order) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _DeliveryProgressSheet(order: order),
  );
}

class _DeliveryProgressSheet extends StatelessWidget {
  final ChannelOrder order;
  const _DeliveryProgressSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final h = _hashOf(order.id);
    final now = DateTime.now();
    final placed = now.subtract(Duration(minutes: 28 + h % 15));
    final steps = <(String, String, bool)>[
      ('订单已提交', _fmt(placed), true),
      ('支付成功', _fmt(placed.add(const Duration(minutes: 1))), true),
      ('商家已接单', _fmt(placed.add(Duration(minutes: 4 + h % 3))), true),
      ('骑手已取餐', _fmt(placed.add(Duration(minutes: 14 + h % 5))), true),
      ('配送中', '骑手距您约 ${1 + (h % 20) / 10}km', true),
      ('已送达', '预计 ${_fmt(now.add(Duration(minutes: 10 + h % 12)))}', false),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFdddddd),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('配送进度',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${order.shopName} · ${order.itemTitle}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF999999))),
            const SizedBox(height: 16),
            for (var i = 0; i < steps.length; i++)
              _timelineRow(
                steps[i].$1,
                steps[i].$2,
                done: steps[i].$3,
                current: i == steps.length - 2,
                last: i == steps.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _timelineRow(String label, String time,
      {required bool done, required bool current, required bool last}) {
    final color = current
        ? AppColors.primary
        : done
            ? const Color(0xFF333333)
            : const Color(0xFFbbbbbb);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: current
                      ? AppColors.primary
                      : done
                          ? AppColors.primary.withValues(alpha: 0.45)
                          : const Color(0xFFdddddd),
                  shape: BoxShape.circle,
                  border: current
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: done
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : const Color(0xFFeeeeee),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                          fontSize: 14,
                          color: color,
                          fontWeight: current
                              ? FontWeight.bold
                              : FontWeight.normal,
                        )),
                  ),
                  Text(time,
                      style: TextStyle(
                          fontSize: 12,
                          color: current
                              ? AppColors.primary
                              : const Color(0xFF999999))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 闪购：发表评价 ============
void showChannelRateSheet(BuildContext context, ChannelOrder order,
    {VoidCallback? onRated}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ChannelRateSheet(order: order, onRated: onRated),
  );
}

class _ChannelRateSheet extends StatefulWidget {
  final ChannelOrder order;
  final VoidCallback? onRated;
  const _ChannelRateSheet({required this.order, this.onRated});

  @override
  State<_ChannelRateSheet> createState() => _ChannelRateSheetState();
}

class _ChannelRateSheetState extends State<_ChannelRateSheet> {
  int _stars = 5;
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFdddddd),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('评价商品',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(widget.order.itemTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF999999))),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setState(() => _stars = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      i <= _stars ? Icons.star : Icons.star_border,
                      size: 34,
                      color: const Color(0xFFffb300),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _text,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: '说说味道、分量、配送怎么样…',
              hintStyle: const TextStyle(
                  fontSize: 13, color: Color(0xFFbbbbbb)),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRated?.call();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('评价成功，感谢反馈'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(21)),
              ),
              child: const Text('提交评价'),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 飞猪：行程单 ============
void showTripSheet(BuildContext context, ChannelOrder order) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _TripSheet(order: order),
  );
}

class _TripSheet extends StatelessWidget {
  final ChannelOrder order;
  const _TripSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final h = _hashOf(order.id);
    final tripDate = DateTime.now().add(Duration(days: 6 + h % 20));
    final dateText =
        '${tripDate.year}-${tripDate.month.toString().padLeft(2, '0')}-${tripDate.day.toString().padLeft(2, '0')}';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFdddddd),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('行程单',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.itemTitle,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 10),
                  _row('出行日期', dateText),
                  _row('出行人', '成人 ×1'),
                  _row('订单状态', order.status),
                  _row('商家', order.shopName),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text('请携带有效证件出行，商家将在出行前 1 天短信提醒。',
                style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF999999))),
          ),
          Expanded(
            child: Text(v,
                style:
                    const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

// ============ 飞猪/闪购：订单详情 ============
void showChannelOrderDetailSheet(BuildContext context, ChannelOrder order) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ChannelOrderDetailSheet(order: order),
  );
}

class _ChannelOrderDetailSheet extends StatelessWidget {
  final ChannelOrder order;
  const _ChannelOrderDetailSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    final h = _hashOf(order.id);
    final created =
        DateTime.now().subtract(Duration(days: 2 + h % 25, hours: h % 24));
    final orderNo =
        '5127${(100000000000000 + h * 7919 % 899999999999999).toString().padLeft(15, '0')}';
    final priceText = order.price == order.price.roundToDouble() &&
            order.price >= 1
        ? order.price.toStringAsFixed(0)
        : order.price.toString();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFdddddd),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('订单详情',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _row('店铺', order.shopName),
            _row('商品', order.itemTitle),
            _row('实付款', '¥$priceText'),
            _row('订单状态', order.status),
            _row('订单编号', orderNo),
            _row('创建时间', _fmtFull(created)),
            if (order.status == '交易成功')
              _row('支付时间', _fmtFull(created.add(const Duration(minutes: 3)))),
            if (order.status == '交易关闭')
              _row('关闭原因', '超时未支付，订单自动关闭'),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(k,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF999999))),
          ),
          Expanded(
            child: Text(v,
                style:
                    const TextStyle(fontSize: 13, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
