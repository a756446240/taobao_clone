import 'dart:convert';
import 'dart:io';

/// 快递联网查询共享工具（v1.9.100 起，物流页/退款页共用）
/// - 公司识别：快递100 autonumber（免 key，全公司覆盖）
/// - 实时轨迹：apizero 双通道优先（匿名 30 次/天），快递100 严格判失败兜底
class ExpressOnline {
  ExpressOnline._();

  /// 快递100 comCode → 中文公司名
  static const comCodeNames = {
    'shunfeng': '顺丰速运',
    'yuantong': '圆通速递',
    'zhongtong': '中通快递',
    'shentong': '申通快递',
    'yunda': '韵达快递',
    'jd': '京东物流',
    'youzhengguonei': '邮政快递包裹',
    'ems': 'EMS',
    'jtexpress': '极兔速递',
    'huitongkuaidi': '百世快递',
    'debangwuliu': '德邦快递',
    'danniao': '丹鸟',
    'cainiao': '菜鸟速递',
  };

  /// 模拟手机浏览器请求头（快递100 对无 UA/Referer 的请求会拦截返回非 JSON）
  static void applyBrowserHeaders(HttpClientRequest req, String referer) {
    req.headers.set(HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1');
    req.headers.set(HttpHeaders.refererHeader, referer);
    req.headers.set(HttpHeaders.acceptHeader,
        'application/json, text/javascript, */*; q=0.01');
  }

  /// 快递公司官方 logo（快递100 图床，实测长期有效）
  static String logoForComCode(String comCode) =>
      'https://cdn.kuaidi100.com/images/all/56/$comCode.png';

  /// 联网识别快递公司（快递100 autonumber，全公司覆盖，实测可用）
  /// 返回 (comCode, 中文公司名)，失败返回 ('','')
  static Future<(String, String)> detectCompany(String waybill) async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(
          'https://www.kuaidi100.com/autonumber/autoComNum?text=$waybill'));
      applyBrowserHeaders(req, 'https://www.kuaidi100.com/');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body = await resp.transform(utf8.decoder).join();
      client.close();
      final auto = jsonDecode(body)['auto'];
      if (auto is List && auto.isNotEmpty) {
        final code = (auto.first['comCode'] ?? '').toString();
        final named =
            comCodeNames[code] ?? (auto.first['name'] ?? '').toString();
        return (code, named);
      }
    } catch (_) {}
    return ('', '');
  }

  /// apizero 免费物流接口（2026 实测匿名可用，30 次/天）：
  /// /api/express 覆盖 申通/圆通/顺丰/中通/百世/极兔；
  /// /api/express-pro 覆盖 京东/韵达/EMS 及其余公司
  static Future<Map<String, dynamic>?> _fetchApizero(String waybill,
      {bool pro = false}) async {
    final path = pro ? '/api/express-pro' : '/api/express';
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(
          Uri.parse('https://v1.apizero.cn$path?number=$waybill'));
      applyBrowserHeaders(req, 'https://apizero.cn/');
      final resp = await req.close().timeout(const Duration(seconds: 8));
      final body = await resp.transform(utf8.decoder).join();
      client.close();
      final j = jsonDecode(body);
      if (j is! Map) return null;
      if (j['code'] == 4000) return {'upgrade': true}; // 免费版不支持→换 pro
      if (j['code'] != 0) return null;
      final data = j['data'];
      if (data is! Map) return null;
      final traces = data['traces'];
      if (traces is! List || traces.isEmpty) return null;
      final statusDesc = (data['status_desc'] ?? '').toString();
      return {
        'com': (data['com'] ?? '').toString(),
        'comName': (data['com_name'] ?? '').toString(),
        'traces': [
          for (var i = 0; i < traces.length; i++)
            {
              'time': (traces[i]['time'] ?? '').toString(),
              // 首条挂状态标签（已签收/派送中/运输中），驱动页面阶段展示
              'tag': i == 0 ? statusDesc : '',
              'text': (traces[i]['content'] ?? '').toString(),
            }
        ],
      };
    } catch (_) {
      return null;
    }
  }

  /// 联网轨迹 → 订单列表/详情摘要文案（v1.9.110，对齐真实淘宝物流条）：
  /// 派送→「派送中 预计今天送达」；签收→「已签收 您的包裹已送达」；
  /// 其余→「运输中 预计明天送达」。空轨迹返回 ''。
  /// （此前直接拿首条原始轨迹文案当摘要，订单列表显示一大段地址派件员文字，
  ///  用户反馈"联网更新不好用"的根因）
  static String summarize(List<Map<String, String>> traces) {
    if (traces.isEmpty) return '';
    final first = traces.first;
    var tag = (first['tag'] ?? '').toString();
    final text = (first['text'] ?? '').toString();
    if (tag.isEmpty) {
      // 兜底通道无 tag：从文案推断阶段
      if (text.contains('签收') || text.contains('已送达')) {
        tag = '已签收';
      } else if (text.contains('派件') || text.contains('派送')) {
        tag = '派送中';
      }
    }
    if (tag.contains('签收')) return '已签收 您的包裹已送达';
    if (tag.contains('派')) return '派送中 预计今天送达';
    return '运输中 预计明天送达';
  }

  /// 联网查询实时物流轨迹：apizero 双通道优先，快递100 严格判失败兜底
  /// 返回 [{time, tag, text}] 最新在前；失败返回 null
  static Future<List<Map<String, String>>?> fetchTraces(
      String comCode, String waybill) async {
    // 1) apizero（匿名免费，自动识别公司）
    var r = await _fetchApizero(waybill);
    if (r != null && r['upgrade'] == true) {
      r = await _fetchApizero(waybill, pro: true);
    }
    if (r != null && r['traces'] is List) {
      return [
        for (final e in (r['traces'] as List))
          Map<String, String>.from((e as Map)
              .map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
      ];
    }
    // 2) 快递100 兜底（免费通道常返「查无结果」，必须严格判失败）
    if (comCode.isEmpty) return null;
    final urls = [
      'https://m.kuaidi100.com/query?type=$comCode&postid=$waybill',
      'https://www.kuaidi100.com/query?type=$comCode&postid=$waybill&temp=${DateTime.now().millisecondsSinceEpoch / 1000}',
    ];
    for (final url in urls) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8);
        final req = await client.getUrl(Uri.parse(url));
        applyBrowserHeaders(req, 'https://m.kuaidi100.com/');
        final resp = await req.close().timeout(const Duration(seconds: 8));
        final body = await resp.transform(utf8.decoder).join();
        client.close();
        final j = jsonDecode(body);
        if (j is! Map || j['status']?.toString() != '200') continue;
        final data = j['data'];
        if (data is! List || data.isEmpty) continue;
        // 「查无结果」是假轨迹，判失败（v1.9.88 修复：此前会被当成成功）
        if ((data.first['context'] ?? '').toString().contains('查无结果')) {
          continue;
        }
        return [
          for (final e in data)
            {
              'time': (e['time'] ?? '').toString(),
              'tag': '',
              'text': (e['context'] ?? '').toString(),
            }
        ];
      } catch (_) {}
    }
    return null;
  }
}
