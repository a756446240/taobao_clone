import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../widgets/app_image.dart';

/// 物流跟踪节点
class _TraceNode {
  final String text;
  final String time;
  const _TraceNode(this.text, this.time);
}

/// 淘宝式物流详情页：状态横幅 + 运单卡 + 收货地址 + 物流跟踪时间线
class LogisticsScreen extends StatelessWidget {
  /// 可选：从订单卡片进入时带上商品信息
  final OrderItem? item;

  const LogisticsScreen({super.key, this.item});

  static const List<_TraceNode> _demoTraces = [
    _TraceNode('【杭州市】快件已到达 杭州转运中心，下一站 上海转运中心', '今天 08:24'),
    _TraceNode('【金华市】快件已发车，发往 杭州转运中心', '今天 02:10'),
    _TraceNode('【金华市】快件已到达 金华集散点', '昨天 21:47'),
    _TraceNode('【金华市】顺丰速运 已收取快件，揽件员：王师傅 138****6621', '昨天 18:05'),
    _TraceNode('商家已发货，包裹等待揽收', '昨天 16:32'),
    _TraceNode('包裹已出库，正在通知快递揽收', '昨天 15:20'),
  ];

  static DateTime? _parseT(String s) =>
      s.isEmpty ? null : DateTime.tryParse(s.replaceAll(' ', 'T'));

  static String _fmtT(DateTime t) =>
      '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 从收货地址里提取城市名（默认杭州）
  static String _cityOf(String address) {
    final m = RegExp(r'([一-龥]{2,4})市').firstMatch(address);
    return m?.group(1) ?? '杭州';
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

  /// 顶部横幅状态文案
  String get _bannerStatus => const ['等待付款', '等待发货', '运输中', '已签收'][_stage];

  /// 根据订单时间线动态生成物流跟踪（每单不同，且与订单状态一致）
  List<_TraceNode> _buildTraces() {
    final it = item;
    if (it == null) return _demoTraces;
    final city = _cityOf(it.address);
    final create = _parseT(it.createTime) ?? DateTime.now();
    final pay = _parseT(it.payTime);
    final ship = _parseT(it.shipTime) ??
        (pay ?? create).add(const Duration(hours: 8));
    final traces = <_TraceNode>[];
    if (_stage >= 3) {
      traces.add(_TraceNode('【$city市】快件已签收，签收人：本人。感谢使用顺丰速运，期待再次为您服务',
          _fmtT(ship.add(const Duration(hours: 52)))));
      traces.add(_TraceNode('【$city市】快件正在派送中，快递员：李师傅 139****8877，请保持电话畅通',
          _fmtT(ship.add(const Duration(hours: 46)))));
    }
    if (_stage >= 2) {
      traces.addAll([
        _TraceNode('【$city市】快件已到达 $city转运中心，下一站 上海转运中心',
            _fmtT(ship.add(const Duration(hours: 26)))),
        _TraceNode('【金华市】快件已发车，发往 $city转运中心',
            _fmtT(ship.add(const Duration(hours: 14)))),
        _TraceNode(
            '【金华市】快件已到达 金华集散点', _fmtT(ship.add(const Duration(hours: 5)))),
        _TraceNode('【金华市】顺丰速运 已收取快件，揽件员：王师傅 138****6621',
            _fmtT(ship.add(const Duration(hours: 2)))),
        _TraceNode('商家已发货，包裹等待揽收', _fmtT(ship)),
        _TraceNode('包裹已出库，正在通知快递揽收',
            _fmtT(ship.subtract(const Duration(hours: 1)))),
      ]);
    } else if (_stage == 1) {
      traces.add(_TraceNode(
          '订单已付款，商家正在备货，将在 48 小时内发出', _fmtT(pay ?? create)));
    }
    if (_stage <= 1) {
      traces.add(_TraceNode('订单已创建，等待买家付款', _fmtT(create)));
    }
    return traces;
  }

  /// 由订单号派生的确定性运单号
  String get _waybillNo {
    final it = item;
    if (it == null) return 'SF3102886642157';
    final digits = it.orderNo.replaceAll(RegExp(r'\D'), '');
    return 'SF${digits.padLeft(13, '0').substring(0, 13)}';
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

  @override
  Widget build(BuildContext context) {
    final latest = item?.logistics.isNotEmpty == true
        ? item!.logistics
        : '已揽件 · 预计后天送达';
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
          _buildStatusBanner(latest),
          const SizedBox(height: 8),
          _buildExpressCard(context),
          const SizedBox(height: 8),
          _buildAddressCard(receiver, address),
          const SizedBox(height: 8),
          _buildTraceCard(),
        ],
      ),
    );
  }

  /// 顶部橙色状态横幅：最新物流状态 + 商品缩略图
  Widget _buildStatusBanner(String latest) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
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
                const Text('运输中',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(latest,
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

  /// 快递公司 + 运单号卡
  Widget _buildExpressCard(BuildContext context) {
    final waybillNo = _waybillNo;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1E8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.local_shipping,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('顺丰速运',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('运单号 $waybillNo',
                    style:
                        const TextStyle(color: Color(0xFF999999), fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _copy(context, waybillNo, '运单号'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDDDDDD)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('复制', style: TextStyle(fontSize: 12)),
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

  /// 物流跟踪时间线
  Widget _buildTraceCard() {
    final traces = _buildTraces();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('物流跟踪',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          for (var i = 0; i < traces.length; i++)
            _traceRow(traces[i], isFirst: i == 0, isLast: i == traces.length - 1),
        ],
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
                  Text(node.time,
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
}
