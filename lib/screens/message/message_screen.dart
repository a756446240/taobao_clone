import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../widgets/app_image.dart';
import 'chat_screen.dart';
import 'quick_messages_screen.dart';

/// 消息页（1:1 复刻 3.4）
/// - 顶部 4 个圆圈入口保留
/// - 右上角“编辑”入口已移除，改为历史消息项右滑显示操作
/// - 每个会话头像根据店铺名自动分配不同图标/颜色，并支持右滑“换头像”
class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  late final List<_HistoryMsg> _history;
  final _rand = Random();

  /// 会话搜索
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 4 个圆圈入口（固定，badge 为未读角标，0 表示不显示）
  static const _quickEntries = <_QuickEntry>[
    _QuickEntry('通知消息', Icons.notifications_active, Color(0xFFef5350), badge: 3),
    _QuickEntry('互动消息', Icons.thumb_up_alt, Color(0xFF42a5f5), badge: 12),
    _QuickEntry('物流消息', Icons.local_shipping, Color(0xFF66bb6a), badge: 1),
    _QuickEntry('直播消息', Icons.videocam, Color(0xFFab47bc)),
  ];

  /// 商家模板
  static const _shopTemplates = [
    _ShopTpl('时尚女装', ['Lily 官方旗舰店', '茵曼旗舰店', '妖精的口袋', 'VERO MODA 官方'], '时尚', Color(0xFFec407a)),
    _ShopTpl('美妆护肤', ['完美日记官方', '花西子官方', '毛戈平官方', '彩妆秀旗舰店'], '美妆', Color(0xFFffa726)),
    _ShopTpl('数码家电', ['小米官方旗舰店', '华为官方旗舰店', '海尔官方', '戴森官方旗舰'], '数码', Color(0xFF42a5f5)),
    _ShopTpl('食品保健', ['良品铺子官方', '三只松鼠旗舰店', '蒙牛官方', '汤臣倍健官方'], '食品', Color(0xFF66bb6a)),
    _ShopTpl('家居生活', ['林氏木业官方', '顾家家居官方', '居然之家', '全友家居官方'], '家居', Color(0xFF8d6e63)),
    _ShopTpl('母婴亲子', ['巴拉巴拉官方', '英氏官方', '好奇官方', '帮宝适官方'], '母婴', Color(0xFFef5350)),
  ];

  /// 消息模板
  static const _msgTemplates = [
    '「顺丰发货」Geonature Momo-M 几何自然系列已发出',
    '欢迎光临本店，更多优惠等你来',
    '你有10淘金币限时奖励，点击去领取',
    '这款是预售款，付款后30天内发货，暂无现货',
    '请确认收货地址，确保配送无误',
    '店铺新会员专享福利，点击查看',
    '「双11预售」定金支付已确认',
    '您的包裹已到达【广州天河站】',
    '您关注的新品已上架',
    '评价晒单赢100元大礼',
    '今日特惠仅剩最后3小时',
    '「限时折扣」本店满200减30',
    '您的会员积分即将到期',
    '新品上市，限量首发',
    '专属客服为您服务',
  ];

  /// 日期模板（2-4 周前）
  static const _datePool = [
    '26/08/06', '26/08/04', '26/08/03', '26/08/01', '26/07/30',
    '26/07/28', '26/07/24', '26/07/22', '26/07/18', '26/07/15',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomAvatars();
    _history = _generateHistory();
  }

  static const _avatarPrefKey = 'message_custom_avatars';
  final Map<String, String> _customAvatars = {};

  /// 读取已保存的自定义头像（按店铺名持久化，重启不丢）
  Future<void> _loadCustomAvatars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_avatarPrefKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((k, v) {
        final path = v.toString();
        if (File(path).existsSync()) _customAvatars[k] = path;
      });
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveCustomAvatars() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_avatarPrefKey, jsonEncode(_customAvatars));
    } catch (_) {}
  }

  /// 每次启动随机生成 10-15 条历史对话
  List<_HistoryMsg> _generateHistory() {
    final count = 10 + _rand.nextInt(6); // 10-15
    final result = <_HistoryMsg>[];
    for (var i = 0; i < count; i++) {
      final tpl = _shopTemplates[_rand.nextInt(_shopTemplates.length)];
      final shopName = tpl.shopNames[_rand.nextInt(tpl.shopNames.length)];
      final msg = _msgTemplates[_rand.nextInt(_msgTemplates.length)];
      final date = _datePool[_rand.nextInt(_datePool.length)];
      final unread = _rand.nextDouble() < 0.4; // 40% 概率有未读
      result.add(_HistoryMsg(
        shopName: shopName,
        message: msg,
        date: date,
        unread: unread,
        color: tpl.color,
        avatarUrl: _avatarForShop(shopName),
      ));
    }
    return result;
  }

  /// 根据店铺名生成一个固定的头像：
  /// - 如果该店铺名已被用户自定义过，则使用本地文件
  /// - 否则用品牌色背景 + 首字
  String _avatarForShop(String shopName) {
    // 用户自定义优先
    final custom = _customAvatars[shopName];
    if (custom != null && File(custom).existsSync()) return custom;
    // 默认使用首字母图标占位
    return '';
  }

  Future<void> _pickAvatar(_HistoryMsg m) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/message_avatars');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'msg_${DateTime.now().millisecondsSinceEpoch}$ext';
      final saved = await File(picked.path).copy('${saveDir.path}/$fileName');
      // 关键修复：同步更新该条目的 avatarUrl（之前只写 map 不更新条目，导致界面无反应）
      setState(() {
        _customAvatars[m.shopName] = saved.path;
        m.avatarUrl = saved.path;
      });
      await _saveCustomAvatars();
    } catch (_) {}
  }

  /// 打开实时聊天（自动回复）
  void _openChat({
    required String title,
    required String lastMessage,
    String avatarUrl = '',
    Color? color,
    _HistoryMsg? markRead,
  }) {
    if (markRead != null && markRead.unread) {
      setState(() => markRead.unread = false);
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversation: Conversation(
            avatar: avatarUrl,
            title: title,
            description: lastMessage,
            createAt: '',
          ),
          accentColor: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('消息', style: AppTextStyles.middleBold),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline,
                color: Color(0xFF333333)),
            offset: const Offset(0, 44),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            onSelected: (v) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  content: Text('$v 功能即将上线'),
                  duration: const Duration(milliseconds: 1200),
                ));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: '添加淘友',
                child: Row(children: [
                  Icon(Icons.person_add_alt, size: 20),
                  SizedBox(width: 10),
                  Text('添加淘友'),
                ]),
              ),
              PopupMenuItem(
                value: '发起群聊',
                child: Row(children: [
                  Icon(Icons.group_add_outlined, size: 20),
                  SizedBox(width: 10),
                  Text('发起群聊'),
                ]),
              ),
              PopupMenuItem(
                value: '扫一扫',
                child: Row(children: [
                  Icon(Icons.qr_code_scanner, size: 20),
                  SizedBox(width: 10),
                  Text('扫一扫'),
                ]),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        // 编辑入口已隐藏到列表项右滑
      ),
      body: Column(
        children: [
          _buildQuickEntries(),
          _buildSearchBar(),
          Expanded(
            child: ListView(
              children: [
                if (_query.isNotEmpty) ...[
                  // 搜索模式：只显示命中的会话
                  ..._history
                      .where((m) =>
                          m.shopName.contains(_query) ||
                          m.message.contains(_query))
                      .map((m) => _historyTile(m)),
                  if (_history.every((m) =>
                      !m.shopName.contains(_query) &&
                      !m.message.contains(_query)))
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(
                        child: Text('没有找到相关会话',
                            style: TextStyle(
                                color: Color(0xFF999999), fontSize: 13)),
                      ),
                    ),
                ] else ...[
                  _systemEntry('交易物流', '暂无包裹动态更新', Icons.local_shipping, const Color(0xFFFF6E40)),
                  _systemEntry('售后保障', '暂无新消息', Icons.assignment_return, const Color(0xFF2196F3)),
                  _systemEntry('AI 购物助手', 'Hi! 我是你的购物助手~帮你挑好货、找优惠！有什么需要，都可以来找我~', Icons.smart_toy, const Color(0xFF7c4dff), date: '26/07/24'),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('两周前的消息',
                        style: TextStyle(
                            color: Color(0xFF999999),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
                  ..._history.map((m) => _historyTile(m)),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索栏：按店铺名 / 消息内容过滤会话
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.trim()),
        decoration: InputDecoration(
          hintText: '搜索会话',
          hintStyle:
              const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
          prefixIcon: const Icon(Icons.search,
              color: Color(0xFF999999), size: 20),
          suffixIcon: _query.isEmpty
              ? null
              : GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                  child: const Icon(Icons.cancel,
                      color: Color(0xFFBBBBBB), size: 18),
                ),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ============ 4 个圆圈入口 ============
  Widget _buildQuickEntries() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _quickEntries.length; i++)
            _buildQuickEntry(_quickEntries[i], i),
        ],
      ),
    );
  }

  Widget _buildQuickEntry(_QuickEntry e, int index) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuickMessagesScreen(
            title: e.title,
            icon: e.icon,
            color: e.color,
            kind: QuickMsgKind.values[index],
          ),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: e.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(e.icon, color: Colors.white, size: 24),
              ),
              if (e.badge > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(9),
                      border:
                          Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text('${e.badge}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(e.title, style: AppTextStyles.min),
        ],
      ),
    );
  }

  // ============ 系统类消息（交易物流/售后保障/AI 购物助手，可点击进入聊天）============
  Widget _systemEntry(String title, String sub, IconData icon, Color color,
      {String? date}) {
    return GestureDetector(
      onTap: () =>
          _openChat(title: title, lastMessage: sub, color: color),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.middle),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.min
                          .copyWith(color: const Color(0xFF999999))),
                ],
              ),
            ),
            if (date != null)
              Text(date,
                  style: AppTextStyles.min
                      .copyWith(color: const Color(0xFF999999))),
          ],
        ),
      ),
    );
  }

  // ============ 历史消息项（右滑显示操作）============
  Widget _historyTile(_HistoryMsg m) {
    return Slidable(
      key: ValueKey(m.shopName + m.date),
      direction: Axis.horizontal,
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.36,
        children: [
          CustomSlidableAction(
            onPressed: (_) => _pickAvatar(m),
            backgroundColor: const Color(0xFF5C6BC0),
            foregroundColor: Colors.white,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 20),
                SizedBox(height: 2),
                Text('换头像', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => _markRead(m),
            backgroundColor: const Color(0xFF66bb6a),
            foregroundColor: Colors.white,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.done_all, size: 20),
                SizedBox(height: 2),
                Text('已读', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          CustomSlidableAction(
            onPressed: (_) => _deleteHistory(m),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_outline, size: 20),
                SizedBox(height: 2),
                Text('删除', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => _openChat(
          title: m.shopName,
          lastMessage: m.message,
          avatarUrl: m.avatarUrl,
          color: m.color,
          markRead: m,
        ),
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // 头像：双击换图；优先自定义图，否则品牌色 + 首字
              GestureDetector(
                onDoubleTap: () => _pickAvatar(m),
                child: _buildAvatar(m),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(m.shopName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.smallBold),
                        ),
                        Text(m.date,
                            style: AppTextStyles.min
                                .copyWith(color: const Color(0xFF999999))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(m.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.smallSub),
                        ),
                        if (m.unread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(minWidth: 20),
                            child: const Text('1',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ),
                      ],
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

  Widget _buildAvatar(_HistoryMsg m) {
    final url = m.avatarUrl;
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AppImage(url: url, width: 44, height: 44),
      );
    }
    final initial = m.shopName.isNotEmpty ? m.shopName[0] : '店';
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: m.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: TextStyle(
              color: m.color, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  void _markRead(_HistoryMsg m) {
    setState(() => m.unread = false);
  }

  void _deleteHistory(_HistoryMsg m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: Text('确定删除与 ${m.shopName} 的对话吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _history.remove(m));
              Navigator.of(ctx).pop();
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _QuickEntry {
  final String title;
  final IconData icon;
  final Color color;
  final int badge;
  const _QuickEntry(this.title, this.icon, this.color, {this.badge = 0});
}

class _ShopTpl {
  final String category;
  final List<String> shopNames;
  final String industry;
  final Color color;
  const _ShopTpl(this.category, this.shopNames, this.industry, this.color);
}

class _HistoryMsg {
  final String shopName;
  final String message;
  final String date;
  bool unread;
  final Color color;
  String avatarUrl;
  _HistoryMsg({
    required this.shopName,
    required this.message,
    required this.date,
    required this.unread,
    required this.color,
    required this.avatarUrl,
  });
}
