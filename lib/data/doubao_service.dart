import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 豆包（火山引擎·方舟 Ark）视觉识别服务。
///
/// 用途：把素材图发给豆包视觉大模型，返回一行淘宝风格商品标题。
///
/// 说明：
/// - 豆包 App 本身免费，但 App 套餐（标准/Pro）不含 API 额度；
///   API 走火山引擎方舟平台按 token 计费，每个模型新用户有 50 万 token
///   免费额度，识别一张图约几百 token，相当于可免费识别上万张。
/// - API Key 在 https://console.volcengine.com/ark → API Key 管理 创建。
class DoubaoService {
  static const _keyApiKey = 'doubao_api_key';
  static const _keyModel = 'doubao_model';
  // 用户自己的推理接入点（视觉模型 Doubao-Seed-2.0-Mini / 260428）
  static const defaultModel = 'ep-20260831210012-wl7c7';
  static const _endpoint =
      'https://ark.cn-beijing.volces.com/api/v3/chat/completions';

  static Future<String> getApiKey() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyApiKey) ?? '';
  }

  static Future<void> saveApiKey(String key) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyApiKey, key.trim());
  }

  static Future<String> getModel() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_keyModel) ?? defaultModel;
  }

  static Future<void> saveModel(String model) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_keyModel, model.trim());
  }

  static Future<bool> get hasApiKey async => (await getApiKey()).isNotEmpty;

  /// 识别一张商品图，返回商品标题；失败抛出异常（消息可展示给用户）
  static Future<String> recognizeProductName(String imagePath) async {
    final key = await getApiKey();
    if (key.isEmpty) throw Exception('请先在素材库页面配置豆包 API Key');

    final file = File(imagePath);
    if (!file.existsSync()) throw Exception('图片文件不存在');
    final bytes = await file.readAsBytes();
    // 控制体积：过大的图直接压到 512px 再编码会更快；这里原图限 4MB
    if (bytes.length > 4 * 1024 * 1024) {
      throw Exception('图片超过 4MB，请换小一点的图');
    }
    final b64 = base64Encode(bytes);
    final lower = imagePath.toLowerCase();
    final mime = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    final model = await getModel();

    final body = jsonEncode({
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  '识别这张商品图，只返回一行淘宝风格的商品标题（30字以内，尽量包含品牌、品名、规格）。'
                  '不要任何解释、不要标点结尾、不要换行。'
            },
            {
              'type': 'image_url',
              'image_url': {'url': 'data:$mime;base64,$b64'}
            }
          ]
        }
      ],
      'max_tokens': 100,
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
    try {
      final req = await client.postUrl(Uri.parse(_endpoint));
      req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      req.add(utf8.encode(body));
      final resp = await req.close().timeout(const Duration(seconds: 60));
      final text = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        String msg = 'HTTP ${resp.statusCode}';
        try {
          final j = jsonDecode(text);
          msg = j['error']?['message']?.toString() ?? msg;
        } catch (_) {}
        throw Exception('豆包接口报错：$msg');
      }
      final j = jsonDecode(text);
      final content =
          j['choices']?[0]?['message']?['content']?.toString().trim() ?? '';
      if (content.isEmpty) throw Exception('豆包没有返回识别结果');
      // 去掉可能的引号/句号
      return content
          .replaceAll(RegExp('^["“\']+|["”\']+\$'), '')
          .replaceAll(RegExp(r'[。.!！]+$'), '')
          .trim();
    } finally {
      client.close();
    }
  }

  /// 通用 chat/completions 调用（429 自动重试），返回文本内容
  static Future<String> _chat(Map<String, dynamic> payload,
      {int retries = 3}) async {
    final key = await getApiKey();
    if (key.isEmpty) throw Exception('请先在素材库页面配置豆包 API Key');
    payload['model'] = await getModel();
    final body = jsonEncode(payload);

    Object? lastError;
    for (var attempt = 0; attempt < retries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: 4 * attempt));
      }
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      try {
        final req = await client.postUrl(Uri.parse(_endpoint));
        req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
        req.add(utf8.encode(body));
        final resp = await req.close().timeout(const Duration(seconds: 90));
        final text = await resp.transform(utf8.decoder).join();
        if (resp.statusCode == 429) {
          lastError = Exception('服务器繁忙，请稍后再试');
          continue; // 429 重试
        }
        if (resp.statusCode != 200) {
          String msg = 'HTTP ${resp.statusCode}';
          try {
            final j = jsonDecode(text);
            msg = j['error']?['message']?.toString() ?? msg;
          } catch (_) {}
          throw Exception('豆包接口报错：$msg');
        }
        final j = jsonDecode(text);
        final content =
            j['choices']?[0]?['message']?['content']?.toString().trim() ?? '';
        if (content.isEmpty) throw Exception('豆包没有返回内容');
        return content;
      } catch (e) {
        lastError = e;
        // 非 429 类错误（图片不合规等）不重试，直接抛出
        if (e is Exception && !e.toString().contains('服务器繁忙')) rethrow;
      } finally {
        client.close();
      }
    }
    throw lastError ?? Exception('请求失败');
  }

  /// 读图并转成 data URL（视觉类调用共用）
  static Future<String> _imageDataUrl(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync()) throw Exception('图片文件不存在');
    final bytes = await file.readAsBytes();
    if (bytes.length > 4 * 1024 * 1024) {
      throw Exception('图片超过 4MB，请换小一点的图');
    }
    final lower = imagePath.toLowerCase();
    final mime = lower.endsWith('.png')
        ? 'image/png'
        : lower.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  /// 解析淘宝订单截图，返回结构化字段；不是订单截图时抛异常
  static Future<Map<String, dynamic>> analyzeOrderScreenshot(
      String imagePath) async {
    final dataUrl = await _imageDataUrl(imagePath);
    final content = await _chat({
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  '这是一张淘宝订单截图。请提取订单信息，只输出 JSON，不要输出任何其他文字：\n'
                      '{"shopName":"店铺名","productTitle":"商品标题","price":实付金额数字,'
                      '"status":"订单状态(待付款/待发货/待收货/已完成/退款中之一)","confidence":0到1的置信度}\n'
                      '如果图片不是订单截图，输出 {"error":"not_order"}'
            },
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl}
            }
          ]
        }
      ],
      'max_tokens': 1024,
      'temperature': 0.1,
    });
    // 从回复中提取 JSON（模型可能包一层 ```json）
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(content);
    if (match == null) throw Exception('AI 未返回有效 JSON');
    final parsed = jsonDecode(match.group(0)!) as Map<String, dynamic>;
    if (parsed.containsKey('error')) throw Exception('图片不是订单截图');
    return parsed;
  }

  /// 店铺客服 AI 回复：根据店铺名和最近聊天记录生成一句淘宝客服风格回复
  static Future<String> generateShopReply({
    required String shopName,
    required List<({bool isMe, String text})> history,
  }) async {
    final msgs = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': '你是淘宝店铺「$shopName」的客服。用淘宝客服口吻回复买家，'
            '亲切、简短（一两句话、60字以内），称呼买家为"亲"，可适当带语气词～。'
            '不要编造具体订单号或物流单号，不要输出任何解释性文字。'
      },
      ...history.map((m) => <String, dynamic>{
            'role': m.isMe ? 'user' : 'assistant',
            'content': m.text,
          }),
    ];
    return _chat({
      'messages': msgs,
      'max_tokens': 200,
      'temperature': 0.8,
    });
  }

  /// 调试用：直接打印识别结果
  static Future<void> debugTest(String imagePath) async {
    try {
      final name = await recognizeProductName(imagePath);
      debugPrint('[Doubao] $imagePath => $name');
    } catch (e) {
      debugPrint('[Doubao] error: $e');
    }
  }
}
