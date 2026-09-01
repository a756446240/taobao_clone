import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../widgets/app_image.dart';
import '../home/live_list_screen.dart';
import '../home/live_room_screen.dart';

/// 消息页 4 个快捷入口的二级列表页（v1.9.7）
/// - 通知消息：系统/活动通知，支持单条已读与"全部已读"
/// - 互动消息：赞和收藏/评论/新增粉丝，粉丝可"回关"
/// - 物流消息：包裹进度卡片，可展开完整物流时间线
/// - 直播消息：关注主播的开播提醒，可直接进入直播间
enum QuickMsgKind { notice, interact, logistics, live }

class QuickMessagesScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final QuickMsgKind kind;

  const QuickMessagesScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.kind,
  });

  @override
  State<QuickMessagesScreen> createState() => _QuickMessagesScreenState();
}

class _QuickMessagesScreenState extends State<QuickMessagesScreen> {
  /// 头像配色盘（按昵称哈希取色，稳定）
  static const _palette = [
    Color(0xFFef5350), Color(0xFFffa726), Color(0xFF66bb6a), Color(0xFF42a5f5),
    Color(0xFFab47bc), Color(0xFF8d6e63), Color(0xFF26c6da), Color(0xFFec407a),
  ];

  static int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  Color _avatarColor(String name) => _palette[_hash(name) % _palette.length];

  // ============ 通知消息 ============
  late final List<_Notice> _notices = [
    const _Notice('系统升级公告', '亲爱的用户，App 已升级至最新版本，新增购物车批量管理、直播间下单等功能，快来体验吧！本次升级不会清除您的任何数据。', '09:12', true),
    const _Notice('账号安全提醒', '您的账号于今天 08:47 在新设备上登录，若非本人操作，请立即前往「设置-账号与安全」修改密码并冻结账号。', '08:50', true),
    const _Notice('优惠券到账通知', '您有一张 10 元无门槛优惠券已到账，全场通用，有效期至本周日 24:00，点击详情查看可用商品。', '昨天', true),
    const _Notice('会员权益更新', '88VIP 会员权益已更新：新增视频平台月卡任选、专属客服绿色通道等 3 项权益，立即前往会员中心查看。', '昨天', false),
    const _Notice('大促活动预告', '秋冬焕新季大促将于本周五 0 点开启，全场满 300 减 50，部分商品折上折，可提前加购锁定库存。', '周一', false),
    const _Notice('评价有礼提醒', '您有 3 笔订单待评价，发表优质评价可获得积分奖励，积分可在积分商城兑换好礼。', '上周', false),
  ];

  // ============ 互动消息 ============
  static const _interactNames = [
    '爱吃橘子的猫', '穿搭博主小七', '数码老炮儿', '甜甜的桃子', '爱健身的 Leo',
    '厨房小当家', '旅行家阿远', '护肤成分党', '爱读书的麦子', '手工达人柚子',
    '宠物观察员', '咖啡续命选手',
  ];
  int _interactTab = 0; // 0 全部 / 1 赞和收藏 / 2 评论 / 3 新增粉丝
  final Set<int> _followed = {};
  late final List<_Interact> _interacts = [
    for (var i = 0; i < 12; i++)
      _Interact(
        type: _hash(_interactNames[i]) % 3,
        name: _interactNames[i],
        text: const [
          '赞了你的评价「质量很好，物流也快」',
          '收藏了你晒单的商品「慵懒风针织毛衣」',
        ][i % 2],
        comment: const [
          '这个毛衣起球吗？求真实反馈',
          '亲，面膜敏感肌能用吗',
          '电饭煲煮粥会溢锅吗',
          '跑步鞋偏码吗，平时 38 拍多大',
        ][i % 4],
        time: const ['刚刚', '5分钟前', '18分钟前', '1小时前', '2小时前', '3小时前',
            '5小时前', '昨天', '昨天', '2天前', '3天前', '上周'][i],
      ),
  ];

  // ============ 物流消息 ============
  late final List<_Logi> _logistics = [
    for (var i = 0; i < 5; i++)
      _Logi(
        goods: const ['慵懒风针织毛衣', '保湿修护面膜30片', '混合坚果大礼包', '蓝牙降噪耳机', '婴儿柔湿巾80抽*6'][i],
        cover: 'assets/images/remote/r${(38 + i).toString().padLeft(4, '0')}.jpg',
        company: const ['中通快递', '圆通速递', '顺丰速运', '韵达快递', '京东物流'][i],
        status: i % 3, // 0 运输中 / 1 派送中 / 2 已签收
        latest: const [
          '【杭州市】快件已到达 杭州转运中心',
          '【上海市】派送员 王师傅 正在为您派送，请保持电话畅通',
          '【杭州市】您的快件已签收，感谢使用，期待再次为您服务',
        ][i % 3],
        time: const ['10:24', '08:56', '昨天 17:30', '昨天 09:12', '周一 15:44'][i],
      ),
  ];

  // ============ 直播消息 ============
  late final List<LiveRoom> _liveRooms = buildLiveRooms().take(6).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title, style: AppTextStyles.appBarTitleBlack),
        centerTitle: true,
        actions: [
          if (widget.kind == QuickMsgKind.notice && _notices.any((n) => n.unread))
            TextButton(
              onPressed: () => setState(() {
                for (var i = 0; i < _notices.length; i++) {
                  _notices[i] = _notices[i].copyRead();
                }
              }),
              child: const Text('全部已读',
                  style: TextStyle(color: AppColors.subText, fontSize: 13)),
            ),
        ],
      ),
      body: switch (widget.kind) {
        QuickMsgKind.notice => _buildNoticeList(),
        QuickMsgKind.interact => _buildInteractList(),
        QuickMsgKind.logistics => _buildLogisticsList(),
        QuickMsgKind.live => _buildLiveList(),
      },
    );
  }

  // ============ 通知消息 ============
  Widget _buildNoticeList() {
    return ListView.separated(
      itemCount: _notices.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, i) {
        final n = _notices[i];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (n.unread) {
              setState(() => _notices[i] = n.copyRead());
            }
            _showNoticeDetail(n);
          },
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(n.title,
                                style: n.unread
                                    ? AppTextStyles.smallBold
                                    : AppTextStyles.small,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(n.time, style: AppTextStyles.min),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(n.content,
                          style: AppTextStyles.minSub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (n.unread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(left: 6, top: 5),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoticeDetail(_Notice n) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.title, style: AppTextStyles.middleBold),
              const SizedBox(height: 4),
              Text(n.time, style: AppTextStyles.min),
              const SizedBox(height: 12),
              Text(n.content,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }

  // ============ 互动消息 ============
  Widget _buildInteractList() {
    const tabs = ['全部', '赞和收藏', '评论', '新增粉丝'];
    final list = _interactTab == 0
        ? _interacts
        : [for (final m in _interacts) if (m.type == _interactTab - 1) m];
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _interactTab = i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _interactTab == i
                          ? AppColors.primary
                          : AppColors.searchBarBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(tabs[i],
                        style: TextStyle(
                          fontSize: 12,
                          color: _interactTab == i
                              ? Colors.white
                              : Colors.black87,
                        )),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, i) {
              final m = list[i];
              final idx = _interacts.indexOf(m);
              return Container(
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(m.name, 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(m.name,
                                    style: AppTextStyles.smallBold,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text(m.time, style: AppTextStyles.min),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (m.type == 0)
                            Text(m.text, style: AppTextStyles.smallSub)
                          else if (m.type == 1)
                            Text('评论了你：${m.comment}',
                                style: AppTextStyles.smallSub)
                          else
                            const Text('开始关注你了，快去看看 TA 的主页吧',
                                style: AppTextStyles.smallSub),
                        ],
                      ),
                    ),
                    if (m.type == 2)
                      GestureDetector(
                        onTap: () => setState(() {
                          _followed.contains(idx)
                              ? _followed.remove(idx)
                              : _followed.add(idx);
                        }),
                        child: Container(
                          margin: const EdgeInsets.only(left: 8, top: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _followed.contains(idx)
                                ? Colors.white
                                : AppColors.primary,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                                color: _followed.contains(idx)
                                    ? AppColors.cartDisable
                                    : AppColors.primary),
                          ),
                          child: Text(
                            _followed.contains(idx) ? '已关注' : '回关',
                            style: TextStyle(
                              fontSize: 12,
                              color: _followed.contains(idx)
                                  ? AppColors.subText
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============ 物流消息 ============
  Widget _buildLogisticsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _logistics.length,
      itemBuilder: (context, i) {
        final l = _logistics[i];
        final statusConf = const [
          ('运输中', Color(0xFFff9800)),
          ('派送中', Color(0xFF42a5f5)),
          ('已签收', Color(0xFF66bb6a)),
        ][l.status];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    Text(l.company, style: AppTextStyles.smallBold),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusConf.$2.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(statusConf.$1,
                          style:
                              TextStyle(fontSize: 10, color: statusConf.$2)),
                    ),
                    const Spacer(),
                    Text(l.time, style: AppTextStyles.min),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child:
                          AppImage(url: l.cover, width: 52, height: 52),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.goods,
                              style: AppTextStyles.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(l.latest,
                              style: AppTextStyles.minSub,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _showLogisticsTimeline(l),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 9),
                  child: Center(
                    child: Text('查看物流详情',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.primary)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogisticsTimeline(_Logi l) {
    final steps = [
      (l.latest, l.time, true),
      ('【${const ['武汉', '南京', '上海', '郑州', '苏州'][_hash(l.company) % 5]}市】快件已发出，下一站 转运中心', '昨天 22:10', false),
      ('【广州市】快件已从 广州转运中心 发出', '昨天 14:05', false),
      ('【广州市】商家已发货，快递公司已揽收', '2天前 19:32', false),
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l.company} · ${l.goods}', style: AppTextStyles.middleBold),
              const SizedBox(height: 14),
              for (final s in steps)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.$3
                                ? AppColors.primary
                                : AppColors.cartDisable,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (s != steps.last)
                          Container(
                              width: 1.5,
                              height: 44,
                              color: AppColors.divider),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.$1,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: s.$3
                                      ? AppColors.primary
                                      : Colors.black87,
                                  fontWeight: s.$3
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                )),
                            const SizedBox(height: 2),
                            Text(s.$2, style: AppTextStyles.min),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ 直播消息 ============
  Widget _buildLiveList() {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _liveRooms.length,
      itemBuilder: (context, i) {
        final r = _liveRooms[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              _buildAvatar(r.anchor, 44),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(r.anchor,
                              style: AppTextStyles.smallBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('直播中',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 9)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('正在直播：${r.title}',
                        style: AppTextStyles.smallSub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text('${r.viewersText}人观看',
                        style: AppTextStyles.min),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AppImage(url: r.cover, width: 74, height: 56),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LiveRoomScreen(room: r))),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('去看看',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, double size) {
    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(color: _avatarColor(name), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(name.substring(0, 1),
          style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.42,
              fontWeight: FontWeight.bold)),
    );
  }
}

/// 通知消息模型
class _Notice {
  final String title;
  final String content;
  final String time;
  final bool unread;

  const _Notice(this.title, this.content, this.time, this.unread);

  _Notice copyRead() => _Notice(title, content, time, false);
}

/// 互动消息模型（type: 0 赞和收藏 / 1 评论 / 2 新增粉丝）
class _Interact {
  final int type;
  final String name;
  final String text; // 赞/收藏的文案
  final String comment; // 评论内容
  final String time;

  const _Interact({
    required this.type,
    required this.name,
    required this.text,
    required this.comment,
    required this.time,
  });
}

/// 物流消息模型（status: 0 运输中 / 1 派送中 / 2 已签收）
class _Logi {
  final String goods;
  final String cover;
  final String company;
  final int status;
  final String latest;
  final String time;

  const _Logi({
    required this.goods,
    required this.cover,
    required this.company,
    required this.status,
    required this.latest,
    required this.time,
  });
}
