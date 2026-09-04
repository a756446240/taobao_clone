import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../widgets/app_image.dart';

/// 物流跟踪节点（tag = 阶段标签：已签收/派送中/运输中/已揽收，对齐真实淘宝分组）
class _TraceNode {
  final String text;
  final String time;
  final String tag;
  const _TraceNode(this.text, this.time, {this.tag = ''});
}

/// 淘宝式物流详情页：状态横幅 + 运单卡 + 收货地址 + 物流跟踪时间线
/// 时间线三段展开（对齐真实淘宝）：
///   0=只看最新 1 条「查看更多物流明细」
///   1=最近 4 条「展开更多物流明细」
///   2=全部历史「收起更多物流明细」
class LogisticsScreen extends StatefulWidget {
  /// 可选：从订单卡片进入时带上商品信息
  final OrderItem? item;

  const LogisticsScreen({super.key, this.item});

  @override
  State<LogisticsScreen> createState() => _LogisticsScreenState();
}

class _LogisticsScreenState extends State<LogisticsScreen> {
  /// 展开级别：0=最新1条 1=最近4条 2=全部
  int _expandLevel = 0;

  OrderItem? get item => widget.item;

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

  /// 物流阶段：0=已下单 1=已付款 2=运输中 3=派送中 4=已签收（v1.9.75 起补派送中，对齐真实淘宝 3 状态）
  int get _stage {
    // 抓包真实时间线：按最新一条的阶段标签定状态
    final real = _realTraces;
    if (real != null) {
      final tag = real.first.tag;
      if (tag.contains('签收')) return 4;
      if (tag.contains('派送')) return 3;
      return 2;
    }
    final it = item;
    if (it == null) return 2;
    final st = it.statusTitle;
    final lg = it.logistics;
    if (st.contains('完成') || st.contains('签收') || st.contains('评价') ||
        lg.contains('签收')) {
      return 4;
    }
    if (lg.contains('派送')) return 3;
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
  String get _bannerStatus =>
      const ['等待付款', '等待发货', '运输中', '派送中', '已签收'][_stage];

  /// 快递公司：抓包写入的真实公司优先，缺省顺丰
  String get _company =>
      item != null && item!.shipCompany.isNotEmpty ? item!.shipCompany : '顺丰速运';

  /// 运单号：抓包写入的真实单号优先，否则由订单号派生
  String get _waybillNo {
    final it = item;
    if (it == null) return 'SF3102886642157';
    if (it.waybillNo.isNotEmpty) return it.waybillNo;
    final digits = it.orderNo.replaceAll(RegExp(r'\D'), '');
    return 'SF${digits.padLeft(13, '0').substring(0, 13)}';
  }

  /// 抓包真实全量时间线（v1.9.76 起）：logisticsTraces JSON [{"time","tag","text"}]
  /// 最新在前；解析失败/为空返回 null，调用方回退本地生成
  List<_TraceNode>? get _realTraces {
    final raw = item?.logisticsTraces ?? '';
    if (raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      final nodes = <_TraceNode>[];
      for (final e in list) {
        if (e is! Map) continue;
        final text = (e['text'] ?? '').toString();
        if (text.isEmpty) continue;
        nodes.add(_TraceNode(text, (e['time'] ?? '').toString(),
            tag: (e['tag'] ?? '').toString()));
      }
      return nodes.isEmpty ? null : nodes;
    } catch (_) {
      return null;
    }
  }

  /// 根据订单时间线动态生成物流跟踪（每单不同，且与订单状态一致）。
  /// 抓包订单有真实全量时间线（logisticsTraces）时直接照搬；
  /// 否则把抓包最新一条（item.logistics）置顶 + 本地补全历史。
  List<_TraceNode> _buildTraces() {
    final real = _realTraces;
    if (real != null) return real;
    final it = item;
    if (it == null) return _demoTraces;
    final city = _cityOf(it.address);
    final recv = it.receiver.isNotEmpty ? it.receiver : '本人';
    final create = _parseT(it.createTime) ?? DateTime.now();
    final pay = _parseT(it.payTime);
    final ship = _parseT(it.shipTime) ??
        (pay ?? create).add(const Duration(hours: 8));
    final traces = <_TraceNode>[];
    // 真实最新物流（抓包接口 orderStatus.subTitle）置顶
    if (it.logistics.isNotEmpty) {
      traces.add(_TraceNode(it.logistics, '最新',
          tag: const ['', '', '运输中', '派送中', '已签收'][_stage]));
    }
    if (_stage >= 4) {
      traces.add(_TraceNode(
          '【$city市】已签收，签收人：$recv。感谢使用$_company，期待再次为您服务',
          _fmtT(ship.add(const Duration(hours: 52))),
          tag: '已签收'));
    }
    if (_stage >= 3) {
      traces.add(_TraceNode(
          '【$city市】包裹正在派送中，派件人：王林，电话：131****0996，请保持电话畅通',
          _fmtT(ship.add(const Duration(hours: 46))),
          tag: '派送中'));
    }
    if (_stage >= 2) {
      traces.addAll([
        _TraceNode('【$city市】快件已到达【$city转运中心】，准备发往下一站',
            _fmtT(ship.add(const Duration(hours: 26))), tag: '运输中'),
        _TraceNode('【金华市】快件已发车，发往【$city转运中心】',
            _fmtT(ship.add(const Duration(hours: 14))), tag: '运输中'),
        _TraceNode(
            '【金华市】快件已到达 金华集散点', _fmtT(ship.add(const Duration(hours: 5))),
            tag: '运输中'),
        _TraceNode('【金华市】$_company 已收取快件，揽件员：王师傅 138****6621',
            _fmtT(ship.add(const Duration(hours: 2))), tag: '已揽收'),
        _TraceNode('商家已发货，包裹等待揽收', _fmtT(ship), tag: '已揽收'),
        _TraceNode('包裹已出库，正在通知快递揽收',
            _fmtT(ship.subtract(const Duration(hours: 1))), tag: '已揽收'),
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

  /// 横幅副文案：抓包真实时间线最新一条 > 抓包最新物流 > 按状态生成
  String get _bannerSubtitle {
    final real = _realTraces;
    if (real != null) return real.first.text;
    final it = item;
    if (it != null && it.logistics.isNotEmpty) return it.logistics;
    final city = _cityOf(it?.address ?? '');
    final recv =
        it != null && it.receiver.isNotEmpty ? it.receiver : '本人';
    switch (_stage) {
      case 4:
        return '已签收，签收人：$recv。如有疑问请联系快递公司或商家';
      case 3:
        return '包裹正在派送中，【$city市】派件人：王林，电话：131****0996，请耐心等待';
      case 2:
        return '包裹正在运输中，【$city市】快件到达【$city转运中心】，准备发往下一站';
      case 1:
        return '商家正在备货，将在承诺时间内发出';
      default:
        return '订单已创建，等待买家付款';
    }
  }

  /// 横幅时间：抓包真实时间线用最新一条的时间，否则按状态推算
  String get _bannerTime {
    final real = _realTraces;
    if (real != null && real.first.time.isNotEmpty) return real.first.time;
    final it = item;
    final create = _parseT(it?.createTime ?? '') ?? DateTime.now();
    final pay = _parseT(it?.payTime ?? '');
    final ship = _parseT(it?.shipTime ?? '') ??
        (pay ?? create).add(const Duration(hours: 8));
    final t = switch (_stage) {
      4 => ship.add(const Duration(hours: 52)),
      3 => ship.add(const Duration(hours: 46)),
      2 => ship.add(const Duration(hours: 26)),
      _ => create,
    };
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';
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
          _buildStatusBanner(),
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

  /// 顶部橙色状态横幅：状态 + 最新物流文案 + 时间 + 商品缩略图（对齐真实淘宝）
  Widget _buildStatusBanner() {
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
                Text(_bannerStatus,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(_bannerSubtitle,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12)),
                const SizedBox(height: 3),
                Text(_bannerTime,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11)),
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
                Text(_company,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
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

  /// 物流跟踪时间线：三段展开（最新1条 → 最近4条 → 全部），动画过渡
  Widget _buildTraceCard() {
    final traces = _buildTraces();
    final visibleCount = _expandLevel == 0
        ? 1
        : _expandLevel == 1
            ? (traces.length < 4 ? traces.length : 4)
            : traces.length;
    final visible = traces.take(visibleCount).toList();
    // 只有还有更多可展开时才显示按钮
    final hasMore = visibleCount < traces.length;
    final btnText = _expandLevel == 0
        ? '查看更多物流明细'
        : _expandLevel == 1 && hasMore
            ? '展开更多物流明细'
            : '收起更多物流明细';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('物流跟踪',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  // 阶段分组标签（已签收/派送中/运输中/已揽收，对齐真实淘宝）
                  if (visible[i].tag.isNotEmpty &&
                      (i == 0 || visible[i].tag != visible[i - 1].tag))
                    _traceTagRow(visible[i].tag, isFirst: i == 0),
                  _traceRow(visible[i],
                      isFirst: i == 0, isLast: i == visible.length - 1),
                ],
              ],
            ),
          ),
          // 展开/收起按钮（对齐真实淘宝：空心圆点 + 灰字）
          GestureDetector(
            onTap: () => setState(() {
              _expandLevel = _expandLevel == 0
                  ? 1
                  : _expandLevel == 1 && hasMore
                      ? 2
                      : 0;
            }),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: const Color(0xFFDDDDDD), width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(btnText,
                      style: const TextStyle(
                          color: Color(0xFF999999), fontSize: 12)),
                  Icon(
                    _expandLevel == 2 || (_expandLevel == 1 && !hasMore)
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: const Color(0xFF999999),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 阶段分组标签行（对齐真实淘宝：粗体黑字，如"已签收""派送中""运输中"）
  Widget _traceTagRow(String tag, {required bool isFirst}) {
    return Row(
      children: [
        const SizedBox(width: 20),
        const SizedBox(width: 10),
        Padding(
          padding: EdgeInsets.only(bottom: 6, top: isFirst ? 0 : 4),
          child: Text(tag,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isFirst ? AppColors.primary : const Color(0xFF1A1A1A))),
        ),
      ],
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
