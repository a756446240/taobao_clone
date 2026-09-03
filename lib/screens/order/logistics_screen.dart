import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../widgets/app_image.dart';
import '../message/chat_screen.dart';

/// 物流跟踪节点
class _TraceNode {
  final String text;
  final DateTime dt;
  const _TraceNode(this.text, this.dt);
}

/// 淘宝式物流详情页：仿地图路线区块 + 状态横幅 + 运单卡 + 收货地址 + 物流跟踪时间线
class LogisticsScreen extends StatelessWidget {
  /// 可选：从订单卡片进入时带上商品信息
  final OrderItem? item;

  const LogisticsScreen({super.key, this.item});

  /// 快递公司池：名称 / 运单号前缀 / 官方客服电话
  static const List<List<String>> _courierPool = [
    ['顺丰速运', 'SF', '95338'],
    ['中通快递', 'ZTO', '95311'],
    ['圆通速递', 'YT', '95554'],
    ['韵达快递', 'YD', '95546'],
    ['申通快递', 'STO', '95543'],
  ];

  /// 发货城市池（按订单号确定性派生）
  static const List<String> _originPool = [
    '金华',
    '广州',
    '杭州',
    '深圳',
    '泉州',
    '上海',
  ];

  static DateTime? _parseT(String s) =>
      s.isEmpty ? null : DateTime.tryParse(s.replaceAll(' ', 'T'));

  static String _fmtClock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 时间线日期分组标签：今天 / 昨天 / MM-dd
  static String _dayLabel(DateTime dt, DateTime now) {
    final d = DateTime(dt.year, dt.month, dt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// 从收货地址里提取城市名（默认杭州）
  static String _cityOf(String address) {
    final m = RegExp(r'([一-龥]{2,4})市').firstMatch(address);
    return m?.group(1) ?? '杭州';
  }

  /// 订单号数字哈希（无订单时返回 0）
  int get _orderHash {
    final digits = (item?.orderNo ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 0;
    final tail = digits.length > 6 ? digits.substring(digits.length - 6) : digits;
    return int.tryParse(tail) ?? 0;
  }

  /// 确定性派生的快递公司 [名称, 前缀, 客服电话]
  List<String> get _courier => _courierPool[_orderHash % _courierPool.length];

  /// 确定性派生的发货城市（不与收货城市相同）
  String get _originCity {
    final city = _cityOf(item?.address ?? '');
    var origin = _originPool[(_orderHash ~/ 7) % _originPool.length];
    if (origin == city) {
      origin = _originPool[((_orderHash ~/ 7) + 1) % _originPool.length];
    }
    return origin;
  }

  /// 物流阶段：0=已下单 1=已付款 2=运输中 3=已签收
  int get _stage {
    final it = item;
    if (it == null) return 2;
    final st = it.statusTitle;
    if (st.contains('完成') || st.contains('签收') || st.contains('评价')) {
      return 3;
    }
    if (it.shipTime.isNotEmpty ||
        st.contains('运输') ||
        st.contains('发货') ||
        st.contains('收货')) {
      return 2;
    }
    if (it.payTime.isNotEmpty || st.contains('付款')) return 1;
    return 0;
  }

  /// 顶部横幅状态文案（与物流阶段一致）
  String get _bannerTitle {
    switch (_stage) {
      case 3:
        return '已签收';
      case 2:
        return '运输中';
      default:
        return '待发货';
    }
  }

  /// 根据订单时间线动态生成物流跟踪（每单不同，且与订单状态一致）
  List<_TraceNode> _buildTraces() {
    final it = item;
    final courierName = _courier[0];
    if (it == null) {
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day, 8, 24);
      return [
        _TraceNode('【杭州市】快件已到达 杭州转运中心，下一站 派送网点', base),
        _TraceNode('【金华市】快件已发车，发往 杭州转运中心',
            base.subtract(const Duration(hours: 6))),
        _TraceNode('【金华市】快件已到达 金华集散点',
            base.subtract(const Duration(hours: 10))),
        _TraceNode('【金华市】$courierName 已收取快件，揽件员：王师傅 138****6621',
            base.subtract(const Duration(hours: 14))),
        _TraceNode('商家已发货，包裹等待揽收', base.subtract(const Duration(hours: 16))),
        _TraceNode('包裹已出库，正在通知快递揽收',
            base.subtract(const Duration(hours: 17))),
      ];
    }
    final city = _cityOf(it.address);
    final origin = _originCity;
    final create = _parseT(it.createTime) ?? DateTime.now();
    final pay = _parseT(it.payTime);
    final ship =
        _parseT(it.shipTime) ?? (pay ?? create).add(const Duration(hours: 8));
    final traces = <_TraceNode>[];
    if (_stage >= 3) {
      traces.add(_TraceNode(
          '【$city市】快件已签收，签收人：本人。感谢使用$courierName，期待再次为您服务',
          ship.add(const Duration(hours: 52))));
      traces.add(_TraceNode(
          '【$city市】快件正在派送中，快递员：李师傅 139****8877，请保持电话畅通',
          ship.add(const Duration(hours: 46))));
    }
    if (_stage >= 2) {
      traces.addAll([
        _TraceNode('【$city市】快件已到达 $city转运中心，下一站 派送网点',
            ship.add(const Duration(hours: 26))),
        _TraceNode('【$origin市】快件已发车，发往 $city转运中心',
            ship.add(const Duration(hours: 14))),
        _TraceNode(
            '【$origin市】快件已到达 $origin集散点', ship.add(const Duration(hours: 5))),
        _TraceNode('【$origin市】$courierName 已收取快件，揽件员：王师傅 138****6621',
            ship.add(const Duration(hours: 2))),
        _TraceNode('商家已发货，包裹等待揽收', ship),
        _TraceNode(
            '包裹已出库，正在通知快递揽收', ship.subtract(const Duration(hours: 1))),
      ]);
    } else if (_stage == 1) {
      traces.add(
          _TraceNode('订单已付款，商家正在备货，将在 48 小时内发出', pay ?? create));
    }
    if (_stage <= 1) {
      traces.add(_TraceNode('订单已创建，等待买家付款', create));
    }
    return traces;
  }

  /// 由订单号派生的确定性运单号（前缀随快递公司）
  String get _waybillNo {
    final it = item;
    final prefix = _courier[1];
    if (it == null) return '${prefix}3102886642157';
    final digits = it.orderNo.replaceAll(RegExp(r'\D'), '');
    return '$prefix${digits.padLeft(13, '0').substring(0, 13)}';
  }

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label已复制'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 物流客服会话
  void _openCourierChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: Conversation(
            avatar: '',
            title: _courier[0],
            description: '物流客服 · 运单 $_waybillNo',
            createAt: '',
          ),
          accentColor: const Color(0xFFFF5000),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final traces = _buildTraces();
    final latest = traces.isNotEmpty
        ? traces.first.text
        : (item?.logistics.isNotEmpty == true
            ? item!.logistics
            : '已揽件 · 预计后天送达');
    final receiver = item?.receiver.isNotEmpty == true ? item!.receiver : '淘小宝';
    final address = item?.address.isNotEmpty == true
        ? item!.address
        : '浙江省杭州市西湖区文三路 100 号';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('物流详情',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildMapBlock(),
          _buildStatusBanner(latest),
          const SizedBox(height: 8),
          _buildExpressCard(context),
          const SizedBox(height: 8),
          _buildAddressCard(receiver, address),
          const SizedBox(height: 8),
          _buildTraceCard(traces),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  /// 仿地图路线区块：起终点 + 运输路线 + 快递车位置
  Widget _buildMapBlock() {
    final origin = _originCity;
    final dest = _cityOf(item?.address ?? '');
    final progress = _stage >= 3 ? 1.0 : (_stage == 2 ? 0.55 : 0.12);
    return SizedBox(
      height: 108,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          const start = Offset(36, 80);
          Offset end(double width) => Offset(width - 36, 28);
          final e = end(w);
          final truck = Offset(
            start.dx + (e.dx - start.dx) * progress,
            start.dy + (e.dy - start.dy) * progress - 14,
          );
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _RouteMapPainter(progress: progress)),
              ),
              Positioned(
                left: 12,
                bottom: 8,
                child: _mapTag(Icons.circle, const Color(0xFF999999), '$origin市'),
              ),
              Positioned(
                right: 12,
                top: 8,
                child: _mapTag(Icons.location_on, AppColors.primary, '$dest市'),
              ),
              Positioned(
                left: truck.dx - 13,
                top: truck.dy - 13,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Color(0x33000000), blurRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.local_shipping,
                      color: AppColors.primary, size: 14),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _mapTag(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 3)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 10),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(fontSize: 11, color: Color(0xFF333333))),
        ],
      ),
    );
  }

  /// 顶部橙色状态横幅：最新物流状态 + 商品缩略图
  Widget _buildStatusBanner(String latest) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5000), Color(0xFFFF7A33)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_bannerTitle,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(latest,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12)),
              ],
            ),
          ),
          if (item != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 52,
                height: 52,
                child: AppImage(
                  url: item!.imageUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 快递公司 + 运单号 + 官方客服卡
  Widget _buildExpressCard(BuildContext context) {
    final waybillNo = _waybillNo;
    final courier = _courier;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E8),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(courier[0].substring(0, 1),
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(courier[0],
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text('运单号 $waybillNo',
                        style: const TextStyle(
                            color: Color(0xFF999999), fontSize: 12)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _copy(context, waybillNo, '运单号'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('复制', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          InkWell(
            onTap: () => _copy(context, courier[2], '客服电话'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      color: Color(0xFF999999), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('官方客服 ${courier[2]}',
                        style: const TextStyle(
                            color: Color(0xFF666666), fontSize: 12)),
                  ),
                  const Text('点击复制',
                      style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 收货地址卡
  Widget _buildAddressCard(String receiver, String address) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.location_on_outlined,
                color: Color(0xFF999999), size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('收货人：$receiver', style: AppTextStyles.small),
                const SizedBox(height: 3),
                Text(address,
                    style: const TextStyle(
                        color: Color(0xFF999999), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 物流跟踪时间线（按 今天/昨天/日期 分组）
  Widget _buildTraceCard(List<_TraceNode> traces) {
    final now = DateTime.now();
    final children = <Widget>[
      const Text('物流跟踪',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
    ];
    String? lastLabel;
    for (var i = 0; i < traces.length; i++) {
      final label = _dayLabel(traces[i].dt, now);
      if (label != lastLabel) {
        if (lastLabel != null) children.add(const SizedBox(height: 2));
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(label,
              style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ));
        lastLabel = label;
      }
      children.add(_traceRow(traces[i],
          isFirst: i == 0, isLast: i == traces.length - 1));
    }
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _traceRow(_TraceNode node, {required bool isFirst, required bool isLast}) {
    final color = isFirst ? AppColors.primary : const Color(0xFF999999);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 圆点 + 竖线
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: isFirst ? 12 : 8,
                  height: isFirst ? 12 : 8,
                  margin: EdgeInsets.only(top: isFirst ? 1 : 3),
                  decoration: BoxDecoration(
                    color: isFirst ? AppColors.primary : const Color(0xFFDDDDDD),
                    shape: BoxShape.circle,
                    border: isFirst
                        ? Border.all(color: const Color(0xFFFFD9C2), width: 3)
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: const Color(0xFFEEEEEE),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(node.text,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight:
                              isFirst ? FontWeight.w600 : FontWeight.normal)),
                  const SizedBox(height: 3),
                  Text(_fmtClock(node.dt),
                      style: TextStyle(
                          color: isFirst
                              ? AppColors.primary
                              : const Color(0xFFBBBBBB),
                          fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 底部操作栏：物流客服 + 延长收货/提醒发货
  Widget _buildBottomBar(BuildContext context) {
    final stage = _stage;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      padding: EdgeInsets.fromLTRB(
          14, 8, 14, 8 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          Expanded(
            child: _barBtn(
              label: '物流客服',
              filled: false,
              onTap: () => _openCourierChat(context),
            ),
          ),
          if (stage == 2) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _barBtn(
                label: '延长收货',
                filled: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已为你延长收货时间，确认收货时间顺延 3 天'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
          if (stage <= 1) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _barBtn(
                label: '提醒发货',
                filled: true,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已提醒商家尽快发货'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _barBtn(
      {required String label, required bool filled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
              color: filled ? AppColors.primary : const Color(0xFFDDDDDD)),
        ),
        child: Text(label,
            style: TextStyle(
                color: filled ? Colors.white : const Color(0xFF333333),
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

/// 仿地图背景：浅色底 + 道路网 + 起点到终点的运输路线
class _RouteMapPainter extends CustomPainter {
  final double progress;

  _RouteMapPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // 底色
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEFF3F0),
    );
    // 道路网（浅色横竖线）
    final road = Paint()
      ..color = const Color(0xFFE0E7E2)
      ..strokeWidth = 5;
    canvas.drawLine(
        Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.25), road);
    canvas.drawLine(
        Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.85), road);
    canvas.drawLine(
        Offset(size.width * 0.3, 0), Offset(size.width * 0.38, size.height), road);
    canvas.drawLine(
        Offset(size.width * 0.72, 0), Offset(size.width * 0.66, size.height), road);
    // 绿地色块
    canvas.drawCircle(
        Offset(size.width * 0.85, size.height * 0.7), 26,
        Paint()..color = const Color(0xFFDCE9DC));
    canvas.drawCircle(
        Offset(size.width * 0.12, size.height * 0.15), 18,
        Paint()..color = const Color(0xFFDCE9DC));

    final start = Offset(36, size.height - 28);
    final end = Offset(size.width - 36, 28);

    // 全程路线（灰色虚感底）
    final fullPath = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(size.width * 0.35, size.height * 0.55, size.width * 0.55,
          size.height * 0.75, end.dx, end.dy);
    canvas.drawPath(
      fullPath,
      Paint()
        ..color = const Color(0xFFC9CFD6)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    // 已走路线（橙色，按进度裁剪）
    canvas.save();
    final cut = Offset(start.dx + (end.dx - start.dx) * progress + 20, 0) & size;
    canvas.clipRect(cut);
    canvas.drawPath(
      fullPath,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();

    // 起点圆点
    canvas.drawCircle(start, 5, Paint()..color = const Color(0xFF999999));
    canvas.drawCircle(start, 2.5, Paint()..color = Colors.white);
    // 终点圆点
    canvas.drawCircle(end, 6, Paint()..color = AppColors.primary);
    canvas.drawCircle(end, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RouteMapPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
