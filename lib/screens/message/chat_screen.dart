import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/doubao_service.dart';
import '../../models/models.dart';
import '../../widgets/app_image.dart';

/// 聊天页：点击进入实时聊天，发送后对方自动回复
class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final Color? accentColor;

  const ChatScreen({super.key, required this.conversation, this.accentColor});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<Timer> _timers = [];
  final Random _rand = Random();
  bool _typing = false;

  /// 通用回复池
  static const _replies = [
    '亲，在的呢，有什么可以帮您？',
    '好的亲，马上为您查询一下～',
    '这款目前现货充足，拍下后 48 小时内发货哦',
    '亲放心，我们支持 7 天无理由退换的',
    '优惠券已经发放到您的账户了，结算时自动抵扣',
    '亲，还有什么其他问题吗？随时为您效劳',
    '感谢亲的支持，祝您购物愉快～',
  ];

  /// 关键词应答规则
  static final _keywordRules = <List<Pattern>>[
    [RegExp(r'发货|什么时候发|多久发'), '现货订单 48 小时内发出，预售款以页面时间为准哦～'],
    [RegExp(r'物流|快递|到哪'), '亲，包裹正在正常运输中，最新物流可在订单详情查看'],
    [RegExp(r'退货|退款|退'), '支持 7 天无理由退货，退款会在 1-3 个工作日原路返回'],
    [RegExp(r'优惠|便宜|砍价|券'), '亲，店铺首页有优惠券可以领取，下单更划算哦'],
    [RegExp(r'质量|正品|假'), '亲放心，本店均为官方正品，支持验货，假一赔十'],
    [RegExp(r'尺码|大小|码数'), '亲可以参考详情页尺码表，不确定的话告诉我身高体重，帮您推荐'],
    [RegExp(r'有货|现货|库存'), '这款目前库存充足，喜欢可以尽快拍下哦'],
    [RegExp(r'你好|在吗|hi|hello', caseSensitive: false), '亲，您好呀～很高兴为您服务'],
  ];

  @override
  void initState() {
    super.initState();
    // 以会话最后一条消息作为开场
    final desc = widget.conversation.description;
    if (desc.isNotEmpty) {
      _messages.add(ChatMessage(content: desc, isMe: false));
    }
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(content: text, isMe: true));
      _controller.clear();
    });
    _scrollToBottom();
    _scheduleReply(text);
  }

  /// 对方实时回复：先显示"正在输入"，优先豆包 AI 生成客服回复，
  /// 无 API Key / 网络失败时回退本地关键词规则，保证永远有应答
  void _scheduleReply(String userText) {
    if (_typing) return;
    setState(() => _typing = true);
    _scrollToBottom();
    _replyWithAi(userText);
  }

  Future<void> _replyWithAi(String userText) async {
    final started = DateTime.now();
    String reply;
    try {
      // 取最近 6 条作为上下文（含刚发出的这条）
      final recent = _messages.length <= 6
          ? List<ChatMessage>.from(_messages)
          : _messages.sublist(_messages.length - 6);
      reply = await DoubaoService.generateShopReply(
        shopName: widget.conversation.title,
        history: recent
            .map((m) => (isMe: m.isMe, text: m.content))
            .toList(),
      ).timeout(const Duration(seconds: 15));
      if (reply.isEmpty) throw Exception('empty');
    } catch (_) {
      reply = _pickReply(userText);
    }
    // 至少保留一点"对方在打字"的真实感
    final elapsed = DateTime.now().difference(started);
    const minDelay = Duration(milliseconds: 900);
    if (elapsed < minDelay) {
      await Future.delayed(minDelay - elapsed);
    }
    if (!mounted) return;
    setState(() {
      _typing = false;
      _messages.add(ChatMessage(content: reply, isMe: false));
    });
    _scrollToBottom();
  }

  /// 聊天设置：置顶 / 免打扰 / 清空聊天记录 / 投诉
  void _showChatSettingsSheet() {
    var pinned = false;
    var muted = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title:
                        const Text('置顶聊天', style: TextStyle(fontSize: 14)),
                    value: pinned,
                    activeColor: const Color(0xFFFF5000),
                    onChanged: (v) => setSheet(() => pinned = v),
                  ),
                  SwitchListTile(
                    title: const Text('消息免打扰',
                        style: TextStyle(fontSize: 14)),
                    value: muted,
                    activeColor: const Color(0xFFFF5000),
                    onChanged: (v) => setSheet(() => muted = v),
                  ),
                  ListTile(
                    title: const Text('清空聊天记录',
                        style: TextStyle(fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFFCCCCCC)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      setState(() => _messages.clear());
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('聊天记录已清空'),
                              duration: Duration(seconds: 1)));
                    },
                  ),
                  ListTile(
                    title:
                        const Text('投诉', style: TextStyle(fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFFCCCCCC)),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('已收到你的投诉，平台将在 24 小时内处理'),
                              duration: Duration(seconds: 2)));
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _pickReply(String userText) {
    for (final rule in _keywordRules) {
      if ((rule[0] as RegExp).hasMatch(userText)) return rule[1] as String;
    }
    return _replies[_rand.nextInt(_replies.length)];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.conversation.title,
                style: AppTextStyles.middleBold,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.friendSettings,
                color: Colors.black87, size: 22),
            onPressed: _showChatSettingsSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_typing ? 1 : 0),
              itemBuilder: (context, index) {
                if (_typing && index == _messages.length) {
                  return _buildTypingBubble();
                }
                return _buildBubble(_messages[index]);
              },
            ),
          ),
          _buildQuickQuestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = widget.conversation.avatar;
    if (url.isNotEmpty) {
      return ClipOval(child: AppImage(url: url, width: 32, height: 32));
    }
    final color = widget.accentColor ?? AppColors.primary;
    final initial = widget.conversation.title.isNotEmpty
        ? widget.conversation.title[0]
        : '客';
    return CircleAvatar(
      radius: 16,
      backgroundColor: color.withOpacity(0.15),
      child: Text(initial,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  /// "对方正在输入"气泡
  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomRight: Radius.circular(12),
            bottomLeft: Radius.circular(2),
          ),
        ),
        child: const Text('对方正在输入…',
            style: TextStyle(color: Color(0xFF999999), fontSize: 13)),
      ),
    );
  }

  Widget _buildBubble(ChatMessage message) {
    final isMe = message.isMe;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primary : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(isMe ? 12 : 2),
          bottomRight: Radius.circular(isMe ? 2 : 12),
        ),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[_buildAvatar(), const SizedBox(width: 6)],
          Flexible(child: bubble),
          if (isMe) ...[const SizedBox(width: 6), _buildMyAvatar()],
        ],
      ),
    );
  }

  /// 我方头像（橙色"我"字圆标）
  Widget _buildMyAvatar() {
    return const CircleAvatar(
      radius: 16,
      backgroundColor: Color(0xFFFFF1EC),
      child: Text('我',
          style: TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.bold)),
    );
  }

  /// 快捷提问条（点击直接发送，命中关键词应答规则）
  static const _quickQuestions = [
    '什么时候发货？',
    '有优惠券吗？',
    '支持退货吗？',
    '是正品吗？',
  ];

  Widget _buildQuickQuestions() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickQuestions.map((q) {
            return GestureDetector(
              onTap: () {
                _controller.text = q;
                _send();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(q,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black87)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(AppIcons.soundLight, color: Colors.black54, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.searchBarBg,
                borderRadius: BorderRadius.circular(19),
              ),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: AppTextStyles.small,
                decoration: const InputDecoration(
                  hintText: '发送消息…',
                  hintStyle:
                      TextStyle(color: AppColors.searchBarText, fontSize: 14),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(AppIcons.emoji, color: Colors.black54, size: 24),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text('发送',
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
