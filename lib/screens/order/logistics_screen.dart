import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/material_pool_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/product_card.dart';

/// 物流跟踪节点（tag = 阶段标签：已签收/派送中/运输中/已揽收，对齐真实淘宝分组）
class _TraceNode {
  final String text;
  final String time;
  final String tag;
  const _TraceNode(this.text, this.time, {this.tag = ''});
}

/// 手机淘宝式物流详情页（v1.9.77 重做，对齐真实淘宝）：
/// - 上半屏可缩放地图（双指缩放/拖动，货车 + 预计送达气泡 + 收货地标记）
/// - 顶部悬浮头：状态 + 自动确认倒计时 + 客服/包裹/更多
/// - 公司行（复制/打电话）→ 最新一条物流 → 「查看更多物流明细 ›」底部弹层
/// - 送至固定收货地址 → 商品卡（查看全部订单信息）→ 商品推荐（同首页逻辑）
class LogisticsScreen extends StatefulWidget {
  /// 可选：从订单卡片进入时带上商品信息
  final OrderItem? item;
  final String shopName;

  const LogisticsScreen({super.key, this.item, this.shopName = ''});

  @override
  State<LogisticsScreen> createState() => _LogisticsScreenState();
}

class _LogisticsScreenState extends State<LogisticsScreen> {
  OrderItem? get item => widget.item;

  // ===== 固定收货信息（对齐用户真实默认地址：淄博 中房大厦） =====
  static const _receiver = '黑山灰';
  static const _phoneMasked = '86-186****5652';
  static const _addrShort = '中房大厦C座1001';
  static const _addrFull = '山东省 淄博市 张店区 科苑街道 中房大厦C座1001';

  List<SearchResultItem>? _recPicks;

  // ============ 数据：抓包真实时间线优先，本地生成兜底 ============

  /// 抓包真实全量时间线（logisticsTraces JSON [{"time","tag","text"}] 最新在前）
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

  /// 物流阶段：0=已下单 1=已付款 2=运输中 3=派送中 4=已签收
  int get _stage {
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

  /// 头部大状态（对齐真实淘宝：已发货/运输中/派送中/已签收）
  String get _headStatus {
    switch (_stage) {
      case 4:
        return '已签收';
      case 3:
        return '派送中';
      case 2:
        final tag = _realTraces?.first.tag ?? '';
        return tag.isNotEmpty ? tag : '运输中';
      case 1:
        return '等待发货';
      default:
        return '已下单';
    }
  }

  /// 自动确认倒计时（付款后 10 天，已签收不显示）
  String get _countdown {
    if (_stage >= 4) return '';
    final it = item;
    final base = _parseT(it?.payTime ?? '') ?? _parseT(it?.createTime ?? '');
    if (base == null) return '还剩9天22小时自动确认';
    final deadline = base.add(const Duration(days: 10));
    var diff = deadline.difference(DateTime.now());
    if (diff.isNegative) diff = Duration.zero;
    return '还剩${diff.inDays}天${diff.inHours % 24}小时自动确认';
  }

  /// 地图气泡（对齐真实淘宝：预计后天送达/预计今天送达/已送达）
  String get _etaBubble => switch (_stage) {
        4 => '已送达',
        3 => '预计今天送达',
        _ => '预计后天送达',
      };

  static DateTime? _parseT(String s) =>
      s.isEmpty ? null : DateTime.tryParse(s.replaceAll(' ', 'T'));

  static String _fmtT(DateTime t) =>
      '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// 快递公司：抓包真实公司优先，缺省按单号前缀推断，再缺省顺丰
  String get _company {
    final c = item?.shipCompany ?? '';
    if (c.isNotEmpty) return c;
    final no = item?.waybillNo ?? '';
    if (no.startsWith('YT')) return '圆通速递';
    if (no.startsWith('SF')) return '顺丰速运';
    if (no.startsWith('ZTO') || no.startsWith('7')) return '中通快递';
    return '顺丰速运';
  }

  /// 运单号：抓包真实单号优先，否则由订单号派生
  String get _waybillNo {
    final it = item;
    if (it == null) return 'SF3102886642157';
    if (it.waybillNo.isNotEmpty) return it.waybillNo;
    final digits = it.orderNo.replaceAll(RegExp(r'\D'), '');
    return 'SF${digits.padLeft(13, '0').substring(0, 13)}';
  }

  /// 本地生成时间线（无抓包数据时的兜底，与订单状态一致）
  List<_TraceNode> _buildLocalTraces() {
    final it = item;
    final create = _parseT(it?.createTime ?? '') ?? DateTime.now();
    final pay = _parseT(it?.payTime ?? '');
    final ship = _parseT(it?.shipTime ?? '') ??
        (pay ?? create).add(const Duration(hours: 8));
    final traces = <_TraceNode>[];
    if (it != null && it.logistics.isNotEmpty) {
      traces.add(_TraceNode(it.logistics, '最新',
          tag: const ['', '', '运输中', '派送中', '已签收'][_stage]));
    }
    if (_stage >= 4) {
      traces.add(_TraceNode(
          '【淄博市】已签收，签收人：$_receiver。感谢使用$_company，期待再次为您服务',
          _fmtT(ship.add(const Duration(hours: 52))),
          tag: '已签收'));
    }
    if (_stage >= 3) {
      traces.add(_TraceNode(
          '【淄博市】包裹正在派送中，派件员：王林，电话：131****0996，请保持电话畅通',
          _fmtT(ship.add(const Duration(hours: 46))),
          tag: '派送中'));
    }
    if (_stage >= 2) {
      traces.addAll([
        _TraceNode('【淄博市】快件已到达【淄博转运中心】，准备发往下一站',
            _fmtT(ship.add(const Duration(hours: 26))), tag: '运输中'),
        _TraceNode('【金华市】快件已发车，发往【淄博转运中心】',
            _fmtT(ship.add(const Duration(hours: 14))), tag: '运输中'),
        _TraceNode('【金华市】$_company 已收取快件，揽件员：王师傅 138****6621',
            _fmtT(ship.add(const Duration(hours: 2))), tag: '已揽收'),
        _TraceNode('您的包裹已出库，等待配送，配送公司：$_company，发货单号[${_waybillNo}]',
            _fmtT(ship), tag: '已发货'),
        _TraceNode('商品已经下单', _fmtT(create), tag: '已下单'),
      ]);
    } else if (_stage == 1) {
      traces.add(_TraceNode(
          '订单已付款，商家正在备货，将在 48 小时内发出', _fmtT(pay ?? create),
          tag: '已下单'));
    }
    if (_stage <= 1) {
      traces.add(_TraceNode('商品已经下单', _fmtT(create), tag: '已下单'));
    }
    return traces;
  }

  List<_TraceNode> get _traces => _realTraces ?? _buildLocalTraces();

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label已复制'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============ 页面结构 ============

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // 上半屏：可缩放地图 + 悬浮头
          SizedBox(
            height: 300 + top,
            child: Stack(
              children: [
                Positioned.fill(child: _buildMap()),
                Positioned(
                  top: top + 4,
                  left: 4,
                  right: 8,
                  child: _buildHeader(),
                ),
              ],
            ),
          ),
          // 下半屏：物流信息 + 商品 + 推荐
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildLogisticsCard(),
                const SizedBox(height: 10),
                _buildAddrCard(),
                const SizedBox(height: 10),
                if (item != null) _buildProductCard(),
                const SizedBox(height: 10),
                _buildRecommend(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 悬浮头：返回 + 状态/倒计时（左），客服/包裹/更多（右）
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios,
                size: 16, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_headStatus,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A))),
              if (_countdown.isNotEmpty)
                Text(_countdown,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF666666))),
            ],
          ),
        ),
        _headerAction(Icons.headset_mic_outlined, '客服'),
        const SizedBox(width: 12),
        _headerAction(Icons.inventory_2_outlined, '包裹'),
        const SizedBox(width: 12),
        _headerAction(Icons.more_horiz, ''),
      ],
    );
  }

  Widget _headerAction(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF333333)),
        if (label.isNotEmpty)
          Text(label,
              style:
                  const TextStyle(fontSize: 9, color: Color(0xFF333333))),
      ],
    );
  }

  /// 真实地图（v1.9.78 起，对齐手机淘宝 1:1）：高德在线瓦片 + 可缩放拖动，
  /// 中心 = 淄博中房大厦（华光路）。瓦片加载失败时底层自绘地图兜底。
  static const _ziboCenter = LatLng(36.8135, 118.0548);

  Widget _buildMap() {
    return Stack(
      children: [
        // 兜底：自绘风格化地图（瓦片无网/加载慢时可见）
        Positioned.fill(child: CustomPaint(painter: _ZiboMapPainter())),
        // 真实高德瓦片地图（缩放手感与淘宝一致）
        Positioned.fill(
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _ziboCenter,
              initialZoom: 16,
              minZoom: 10,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom |
                      InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                subdomains: const ['1', '2', '3', '4'],
                userAgentPackageName: 'com.taobao.clone',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _ziboCenter,
                    width: 120,
                    height: 110,
                    alignment: Alignment.topCenter,
                    child: _mapMarker(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 地图中心标记：预计送达气泡 + 货车 + 收货地（对齐真实淘宝）
  Widget _mapMarker() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(_etaBubble,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        Container(width: 2, height: 8, color: AppColors.primary),
        const Icon(Icons.local_shipping, color: Color(0xFF5B3A29), size: 30),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFDDDDDD)),
          ),
          child: const Text('收  淄博市',
              style: TextStyle(fontSize: 10, color: Color(0xFF333333))),
        ),
      ],
    );
  }

  /// 物流卡：公司行（复制/打电话）+ 最新一条 + 查看更多物流明细
  Widget _buildLogisticsCard() {
    final latest = _traces.first;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Column(
        children: [
          // 公司行
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFF7B5AA6),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(_company.characters.first,
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('$_company $_waybillNo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A))),
              ),
              GestureDetector(
                onTap: () => _copy(_waybillNo, '运单号'),
                child: const Text('复制',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF666666))),
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () => _copy('05338795880', '联系电话'),
                child: const Text('打电话',
                    style:
                        TextStyle(fontSize: 12, color: Color(0xFF666666))),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 最新一条物流（阶段标签 + 时间 橙色）
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(Icons.fiber_manual_record,
                    size: 10, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${latest.tag.isNotEmpty ? '${latest.tag}  ' : ''}${latest.time}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ),
                        if (latest.tag.contains('发货') &&
                            !latest.tag.contains('签收')) ...[
                          const Spacer(),
                          const Text('预计今天18:33前揽收',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(latest.text,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF666666),
                            height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 查看更多物流明细 → 底部弹层
          GestureDetector(
            onTap: _showTraceSheet,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.radio_button_unchecked,
                      size: 10, color: Color(0xFFBBBBBB)),
                  SizedBox(width: 8),
                  Text('查看更多物流明细',
                      style:
                          TextStyle(fontSize: 12, color: Color(0xFF999999))),
                  Icon(Icons.chevron_right,
                      size: 14, color: Color(0xFFBBBBBB)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 送至地址卡（固定淄博 中房大厦）
  Widget _buildAddrCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.radio_button_unchecked,
                size: 12, color: Color(0xFFBBBBBB)),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('送至  $_addrShort',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A))),
                SizedBox(height: 4),
                Row(
                  children: [
                    Text('$_receiver  $_phoneMasked',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF999999))),
                    SizedBox(width: 6),
                    Text('号码保护中',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFFBBBBBB))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 商品卡：店铺 + 商品行 + 查看全部订单信息（对齐真实淘宝）
  Widget _buildProductCard() {
    final it = item!;
    final total = it.price * it.quantity;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                    widget.shopName.isNotEmpty ? widget.shopName : '海外专营店',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A))),
              ),
              const Icon(Icons.chevron_right,
                  size: 16, color: Color(0xFFBBBBBB)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AppImage(url: it.imageUrl, width: 56, height: 56),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(it.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF1A1A1A))),
                        ),
                        const SizedBox(width: 8),
                        Text('¥${it.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A))),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(it.configuration,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF999999))),
                        ),
                        Text('~¥${(total + 11).toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFBBBBBB),
                                decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 6),
                        Text('x${it.quantity}',
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF999999))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('7天价保  7天无理由退货  正品保障',
                        style: TextStyle(
                            fontSize: 10, color: Color(0xFF2E7D32))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('查看全部订单信息',
                    style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                Icon(Icons.keyboard_arrow_down,
                    size: 14, color: Color(0xFFBBBBBB)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 商品推荐：与首页推荐同逻辑（素材池优先，内置 mock 兜底）
  Widget _buildRecommend() {
    final pool = context.watch<MaterialPoolProvider>();
    if (!pool.loading && _recPicks == null) {
      _recPicks = pool.recommendGoods(6);
    }
    final picks = _recPicks ??
        (([...MockData.guessLikeGoods]..shuffle(Random(20260904)))
            .take(6)
            .toList());
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.62,
          ),
          itemCount: picks.length,
          itemBuilder: (_, i) => ProductCard(item: picks[i]),
        ),
      ],
    );
  }

  /// 「查看更多物流明细」底部弹层：完整时间线 + 底部收货地址（对齐真实淘宝）
  void _showTraceSheet() {
    final traces = _traces;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Center(
                      child: Text('详细信息',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close,
                        size: 22, color: Color(0xFF666666)),
                  ),
                ],
              ),
            ),
            // 公司行
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF7B5AA6),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(_company.characters.first,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$_company $_waybillNo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  GestureDetector(
                    onTap: () => _copy(_waybillNo, '运单号'),
                    child: const Text('复制',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF666666))),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: () => _copy('05338795880', '联系电话'),
                    child: const Text('打电话',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF666666))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            // 完整时间线
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                itemCount: traces.length + 1,
                itemBuilder: (_, i) {
                  if (i == traces.length) {
                    // 底部收货地址（对齐真实淘宝弹层）
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: Color(0xFF999999)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$_receiver，186****5652，$_addrFull',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF666666),
                                  height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final n = traces[i];
                  return _sheetTraceRow(n, isFirst: i == 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 弹层时间线行：阶段标签(粗体) + 时间 + 文案
  Widget _sheetTraceRow(_TraceNode n, {required bool isFirst}) {
    final headColor = isFirst ? AppColors.primary : const Color(0xFF1A1A1A);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 16,
            child: Column(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFirst
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                        color: isFirst
                            ? AppColors.primary
                            : const Color(0xFFCCCCCC),
                        width: 1.5),
                  ),
                ),
                Expanded(
                  child: Container(
                      width: 1, color: const Color(0xFFEEEEEE)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${n.tag.isNotEmpty ? '${n.tag}  ' : ''}${n.time}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: headColor),
                  ),
                  const SizedBox(height: 3),
                  Text(n.text,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                          height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 淄博张店风格化自绘地图（中房大厦周边，可缩放）
class _ZiboMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 底色（浅灰绿，仿高德浅色底图）
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFEDF2EC));

    final road = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final block = Paint()..color = const Color(0xFFE3EAE2);
    final park = Paint()..color = const Color(0xFFD5E8D0);
    final water = Paint()..color = const Color(0xFFCFE3F0);

    // 地块
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .06, h * .06, w * .3, h * .22),
            const Radius.circular(6)),
        block);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .62, h * .08, w * .3, h * .18),
            const Radius.circular(6)),
        park);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .08, h * .66, w * .26, h * .24),
            const Radius.circular(6)),
        block);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(w * .68, h * .7, w * .24, h * .2),
            const Radius.circular(6)),
        water);

    // 路网（横竖主路 + 斜路）
    road.strokeWidth = 14;
    canvas.drawLine(Offset(0, h * .42), Offset(w, h * .38), road); // 华光路
    road.strokeWidth = 10;
    canvas.drawLine(Offset(w * .46, 0), Offset(w * .5, h), road); // 纵路
    canvas.drawLine(Offset(0, h * .72), Offset(w, h * .78), road);
    canvas.drawLine(Offset(w * .16, 0), Offset(w * .12, h), road);
    road.strokeWidth = 5;
    canvas.drawLine(Offset(w * .78, 0), Offset(w * .86, h), road);
    canvas.drawLine(Offset(0, h * .18), Offset(w, h * .14), road);

    // 文字标注
    void label(String text, double x, double y,
        {double size = 11, Color color = const Color(0xFF7A8A7C)}) {
      final tp = TextPainter(
        text: TextSpan(
            text: text, style: TextStyle(fontSize: size, color: color)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x, y));
    }

    label('中房大厦(华光路)', w * .6, h * .3, size: 13, color: const Color(0xFF556255));
    label('中房教育综合体', w * .56, h * .44);
    label('卓霖装饰', w * .82, h * .46);
    label('食养生鲜\n生活超市', w * .2, h * .5, size: 10);
    label('中国移动', w * .4, h * .52);
    label('中房天玺', w * .9, h * .28, size: 10);
    label('庞氏推拿', w * .5, h * .12, size: 10);
    label('东1门', w * .88, h * .04, size: 10);
    label('5号楼', w * .54, h * .08, size: 10);
    label('P', w * .1, h * .58, size: 12, color: const Color(0xFF7B8FDD));
    label('P', w * .5, h * .62, size: 12, color: const Color(0xFF7B8FDD));
    label('P', w * .04, h * .36, size: 12, color: const Color(0xFF7B8FDD));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
