import 'dart:convert';
import 'dart:io';

/// 快递联网查询共享工具（v1.9.100 起，物流页/退款页共用）
/// v1.9.136 修复：快递100 autonumber 已失效（对真实单号也返「不是有效的
/// 快递单号」），公司识别改本地单号规则优先；apizero 显式 com 调免费通道
/// （避免 auto 识别被判升级），顺丰/中通自动带手机号后 4 位
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

  /// 快递100 comCode → apizero com
  static const _apizeroCom = {
    'shunfeng': 'sf',
    'yuantong': 'yto',
    'zhongtong': 'zto',
    'shentong': 'sto',
    'huitongkuaidi': 'best',
    'jtexpress': 'jt',
    'jd': 'jd',
    'yunda': 'yunda',
    'ems': 'ems',
  };

  /// apizero 免费通道（/api/express）支持的公司
  static const _freeComs = {'sf', 'yto', 'zto', 'sto', 'best', 'jt'};

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

  /// 本地单号规则识别公司（v1.9.136：autonumber 已失效，本地规则零联网覆盖主流公司）
  /// 返回 (快递100 comCode, 中文名)，识别不了返回 ('','')
  static (String, String) detectLocal(String waybill) {
    final w = waybill.trim().toUpperCase();
    if (w.isEmpty) return ('', '');
    if (RegExp(r'^SF\d{9,15}$').hasMatch(w)) return ('shunfeng', '顺丰速运');
    if (RegExp(r'^YT\d{9,15}$').hasMatch(w)) return ('yuantong', '圆通速递');
    if (RegExp(r'^JT\d{9,15}$').hasMatch(w)) return ('jtexpress', '极兔速递');
    if (RegExp(r'^JD[A-Z]{0,3}\d{9,15}$').hasMatch(w)) return ('jd', '京东物流');
    if (RegExp(r'^YD\d{9,15}$').hasMatch(w)) return ('yunda', '韵达快递');
    // 申通：15 位数字，77 开头（实测 773442217376054）
    if (RegExp(r'^77\d{13}$').hasMatch(w)) return ('shentong', '申通快递');
    // 中通：14 位数字，73/75/78/79 开头（实测 79033349096068）
    if (RegExp(r'^(73|75|78|79)\d{12}$').hasMatch(w)) {
      return ('zhongtong', '中通快递');
    }
    if (RegExp(r'^\d{13}$').hasMatch(w)) {
      if (RegExp(r'^(43|46)').hasMatch(w)) return ('yunda', '韵达快递');
      if (RegExp(r'^(10|11|50|56)').hasMatch(w)) return ('ems', 'EMS');
      if (RegExp(r'^(95|96|97|98|99)').hasMatch(w)) {
        return ('youzhengguonei', '邮政快递包裹');
      }
    }
    // 圆通旧单号：12 位数字 88 开头
    if (RegExp(r'^88\d{10}$').hasMatch(w)) return ('yuantong', '圆通速递');
    return ('', '');
  }

  /// 从掩码手机号里抠后 4 位（顺丰/中通联网查询必传），抠不到返回 ''
  static String extractPhone4(String text) {
    final m = RegExp(r'(\d{4})\D*$').firstMatch(text);
    return m?.group(1) ?? '';
  }

  /// 联网识别快递公司：本地规则优先（v1.9.136），识别不了再试 autonumber
  /// 返回 (comCode, 中文公司名)，失败返回 ('','')
  static Future<(String, String)> detectCompany(String waybill) async {
    final local = detectLocal(waybill);
    if (local.$1.isNotEmpty) return local;
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
  /// /api/express 覆盖 申通/圆通/顺丰/中通/百世/极兔（显式 com 才不走 auto，
  /// 顺丰/中通还必须带 phone=手机号后 4 位）；
  /// /api/express-pro 覆盖 京东/韵达/EMS 及其余公司（匿名额度极少）
  static Future<Map<String, dynamic>?> _fetchApizero(String waybill,
      {bool pro = false, String com = '', String phone4 = ''}) async {
    final path = pro ? '/api/express-pro' : '/api/express';
    try {
      var url = 'https://v1.apizero.cn$path?number=$waybill';
      if (com.isNotEmpty) url += '&com=$com';
      if (phone4.isNotEmpty) url += '&phone=$phone4';
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(url));
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

  /// 快递100 m 站免费查询（无配额限制；圆通等多数公司无需手机号直接出轨迹，
  /// 顺丰/中通/申通要手机号后 4 位校验，查不到会返「查无结果」判失败）
  static Future<List<Map<String, String>>?> _fetchKuaidi100(
      String comCode, String waybill) async {
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

  /// 联网查询实时物流轨迹（v1.9.143：通道顺序调整为快递100 m 站优先——
  /// 免费无配额，圆通等可直接出轨迹（实测真实单号 13 条）；
  /// apizero 匿名 30 次/天容易 429，留给顺丰/中通/申通这些要手机号的兜底）
  /// 返回 [{time, tag, text}] 最新在前；失败返回 null
  static Future<List<Map<String, String>>?> fetchTraces(
      String comCode, String waybill,
      {String phone4 = ''}) async {
    // 1) 快递100 m 站优先（免费无配额）
    if (comCode.isNotEmpty) {
      final kd = await _fetchKuaidi100(comCode, waybill);
      if (kd != null) return kd;
    }
    // 2) apizero（显式 com 免费通道 → pro → 自动识别兜底）
    Map<String, dynamic>? r;
    final apCom = _apizeroCom[comCode] ?? '';
    if (apCom.isNotEmpty) {
      if (_freeComs.contains(apCom)) {
        // 顺丰/中通免费通道必须带手机号后 4 位，没带直接走 pro
        final needPhone = apCom == 'sf' || apCom == 'zto';
        if (!needPhone || phone4.isNotEmpty) {
          r = await _fetchApizero(waybill, com: apCom, phone4: phone4);
          if (r != null && r['upgrade'] == true) r = null;
        }
        r ??= await _fetchApizero(waybill,
            pro: true, com: apCom, phone4: phone4);
      } else {
        // 京东/韵达/EMS 等只有 pro 通道
        r = await _fetchApizero(waybill,
            pro: true, com: apCom, phone4: phone4);
      }
    }
    if (r == null || r['traces'] is! List) {
      // 公司未知或显式通道失败：旧自动识别链路兜底
      r = await _fetchApizero(waybill);
      if (r != null && r['upgrade'] == true) {
        r = await _fetchApizero(waybill, pro: true);
      }
    }
    if (r != null && r['traces'] is List) {
      return [
        for (final e in (r['traces'] as List))
          Map<String, String>.from((e as Map)
              .map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')))
      ];
    }
    return null;
  }
}
