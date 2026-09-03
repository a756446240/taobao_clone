import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/follow_shops_provider.dart';
import '../../widgets/app_image.dart';
import '../product/product_detail_screen.dart';

/// 微淘 AI 视频数据（搬运自 HaotaoMarket v3.4 APK）
class _WeitaoVideo {
  final String asset;
  final String title;
  final String shop;
  final Color avatarColor;
  final int likes;
  final int comments;
  final int favorites;
  final int shares;
  const _WeitaoVideo(this.asset, this.title, this.shop, this.avatarColor,
      this.likes, this.comments, this.favorites, this.shares);
}

const List<_WeitaoVideo> _videos = [
  _WeitaoVideo('assets/videos/video1.mp4', '进口辅酶Q10软胶囊 60粒装，呵护心脏每一天',
      'Swisse 海外旗舰店', Color(0xFF2B6DEF), 15234, 486, 2381, 315),
  _WeitaoVideo('assets/videos/video2.mp4', '智能仓储分拣 全程可视化物流，你的包裹这样到你手里',
      '菜鸟国际物流', Color(0xFF12A150), 8966, 213, 1024, 158),
  _WeitaoVideo('assets/videos/video3.mp4', '618 全球好物节 大促预热，爆款提前锁定',
      '天猫国际', Color(0xFFFF5000), 32651, 1204, 5603, 892),
  _WeitaoVideo('assets/videos/video4.mp4', '源头好货 跨境直采航拍之旅，带你云逛产地',
      '海外直营', Color(0xFF7C3AED), 6782, 175, 866, 94),
];

/// 预设评论池（按视频索引循环取用，每视频 8 条）
const List<List<String>> _commentPool = [
  [
    '已下单，等活动价！',
    '这个牌子一直在吃，效果不错',
    '物流很快，隔天就到了',
    '主播推荐来的，先收藏',
    '给家里老人买的，复购第三次了',
    '比线下药店便宜不少，正品可验',
    '胶囊不大，好吞咽',
    '求问和鱼油能一起吃吗',
  ],
  [
    '原来包裹是这么分拣的，涨知识了',
    '国际件也能全程追踪，安心',
    '希望配送再快一点',
    '科技感满满',
    '昨天刚收到件，确实是这个流程',
    '跨境 5 天到手，比预期快',
    '分拣中心的机械臂太帅了',
    '建议多拍点这类溯源视频',
  ],
  [
    '618 力度比去年还大',
    '已经加购三件了',
    '求优惠券链接',
    '全球好物节必蹲',
    '预售定金已付，坐等尾款',
    '去年囤的还没用完，今年继续',
    '直播间还有额外满减吗',
    '爆款清单求整理',
  ],
  [
    '产地直拍好治愈',
    '这样的溯源才敢买',
    '求上架同款',
    '航拍太美了',
    '看完直接下了一单',
    '风景绝了，想去旅游',
    '跨境直采这个价格很良心',
    '希望多出一些产地系列',
  ],
];

/// 微淘页：抖音式全屏沉浸式视频流（1:1 对齐淘宝视频 Tab）
/// - 无白顶栏/白底栏，标题与入口全部悬浮在视频上
/// - 右侧操作栏：头像+关注 / 点赞 / 评论 / 收藏 / 分享
/// - 底部渐变区：店铺标签 + 商品标题
/// - 播放实现：每页各自持有 controller，仅初始化当前激活页
class WeitaoScreen extends StatefulWidget {
  const WeitaoScreen({super.key});

  @override
  State<WeitaoScreen> createState() => _WeitaoScreenState();
}

class _WeitaoScreenState extends State<WeitaoScreen> {
  final PageController _pageController = PageController();
  int _current = 0;
  bool _muted = true;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 视频流：上下滑动切换，铺满整个栏目（无限循环 feed，刷不到底）
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: null,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (context, index) => _VideoPage(
              key: ValueKey(index),
              video: _videos[index % _videos.length],
              isActive: index == _current,
              muted: _muted,
            ),
          ),
          // 顶部悬浮栏：AI 视频 + 为你推荐 + 静音开关
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2E4D), Color(0xFFFF7A00)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('AI 视频',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    const Text('为你推荐',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 4)
                            ])),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _muted = !_muted),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black38,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _muted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtCount(int n) {
  if (n >= 10000) return '${(n / 10000).toStringAsFixed(1)}w';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}

/// 单个视频页：自己持有 controller（v3.4 已验证的播放方案）
class _VideoPage extends StatefulWidget {
  final _WeitaoVideo video;
  final bool isActive;
  final bool muted;

  const _VideoPage({
    super.key,
    required this.video,
    required this.isActive,
    required this.muted,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _ctl;
  bool _initError = false;
  bool _playing = false;
  bool _initializing = false;

  // 互动状态（SharedPreferences 持久化，重启不丢）
  bool _liked = false;
  bool _faved = false;
  bool _shared = false;

  // 双击点赞飘心动画
  final List<int> _hearts = [];
  int _heartSeq = 0;

  String get _interactKey => 'weitao_interact_${widget.video.asset}';

  @override
  void initState() {
    super.initState();
    _loadInteract();
    // 只初始化当前激活页，避免同时创建多个播放器导致低端机解码器实例不足
    if (widget.isActive) _init();
  }

  Future<void> _loadInteract() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_interactKey);
    if (raw == null || !mounted) return;
    setState(() {
      _liked = raw.contains('L');
      _faved = raw.contains('F');
      _shared = raw.contains('S');
    });
  }

  Future<void> _saveInteract() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_interactKey,
        '${_liked ? 'L' : ''}${_faved ? 'F' : ''}${_shared ? 'S' : ''}');
  }

  void _toggleLike() {
    setState(() => _liked = !_liked);
    _saveInteract();
  }

  /// 双击：未点赞则补赞 + 飘心动画（对齐抖音/逛逛手势）
  void _onDoubleTap() {
    if (!_liked) _toggleLike();
    setState(() => _hearts.add(++_heartSeq));
  }

  Future<void> _init() async {
    if (_initializing || _ctl != null) return;
    _initializing = true;
    try {
      final c = VideoPlayerController.asset(widget.video.asset);
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(widget.muted ? 0 : 1);
      if (!mounted) {
        c.dispose();
        return;
      }
      setState(() {
        _ctl = c;
        _initError = false;
      });
      if (widget.isActive) {
        await c.play();
        if (mounted) setState(() => _playing = true);
      }
    } catch (_) {
      if (mounted) setState(() => _initError = true);
    } finally {
      _initializing = false;
    }
  }

  @override
  void didUpdateWidget(covariant _VideoPage old) {
    super.didUpdateWidget(old);
    if (old.muted != widget.muted) {
      _ctl?.setVolume(widget.muted ? 0 : 1);
    }
    if (widget.isActive && !old.isActive) {
      // 变为激活页：未初始化则初始化，已初始化则从头播放
      if (_ctl == null) {
        _init();
      } else if (!_playing) {
        _ctl!.seekTo(Duration.zero);
        _ctl!.play();
        setState(() => _playing = true);
      }
    }
    if (!widget.isActive && old.isActive) {
      // 离开激活页：释放播放器，回收解码器资源
      final c = _ctl;
      _ctl = null;
      _playing = false;
      c?.dispose();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final c = _ctl;
    if (c == null) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _playing = false;
      } else {
        c.play();
        _playing = true;
      }
    });
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ============ 评论底部抽屉 ============
  void _openComments() {
    final videoIndex = _videos.indexOf(widget.video);
    final presets =
        _commentPool[videoIndex % _commentPool.length];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(
        video: widget.video,
        presets: presets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctl;
    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: _onDoubleTap,
      child: Container(
        color: Colors.black,
        child: _initError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white54, size: 40),
                    const SizedBox(height: 8),
                    const Text('视频加载失败',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        setState(() => _initError = false);
                        _init();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text('点击重试',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              )
            : c == null
                ? Center(
                    child: widget.isActive
                        ? const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white54),
                          )
                        : const Icon(Icons.play_circle_outline,
                            size: 56, color: Colors.white24),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      // 视频画面（铺满）
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: c.value.size.width,
                          height: c.value.size.height,
                          child: VideoPlayer(c),
                        ),
                      ),
                      // 暂停态角标
                      if (!_playing)
                        const Center(
                          child: Icon(Icons.play_circle_fill,
                              size: 64, color: Colors.white70),
                        ),
                      // 双击点赞飘心层
                      for (final id in _hearts)
                        Center(
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey(id),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 700),
                            onEnd: () {
                              if (mounted) {
                                setState(() => _hearts.remove(id));
                              }
                            },
                            builder: (_, t, __) => Opacity(
                              opacity: 1 - t,
                              child: Transform.translate(
                                offset: Offset(0, -60 * t),
                                child: Transform.scale(
                                  scale: 0.8 + 0.6 * t,
                                  child: const Icon(Icons.favorite,
                                      color: Color(0xFFFF2E4D), size: 80),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 播放进度条（可拖动）
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SizedBox(
                          height: 3,
                          child: VideoProgressIndicator(
                            c,
                            allowScrubbing: true,
                            padding: EdgeInsets.zero,
                            colors: const VideoProgressColors(
                              playedColor: AppColors.primary,
                              bufferedColor: Colors.white24,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ),
                      ),
                      // 右侧操作栏
                      Positioned(
                        right: 8,
                        bottom: 96,
                        child: _buildActionRail(),
                      ),
                      // 底部渐变 + 店铺标签 + 标题
                      Positioned(
                        left: 0,
                        right: 72,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 28, 12, 14),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(widget.video.shop,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500)),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              // 带货商品卡（按视频确定性选品）
                              _buildGoodsCard(context),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  /// 带货商品：按视频标题哈希从猜你喜欢池确定性选 1 件
  SearchResultItem get _goods {
    const pool = MockData.guessLikeGoods;
    var h = _videos.indexOf(widget.video) * 3 + 7;
    for (final c in widget.video.title.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return pool[h % pool.length];
  }

  Widget _buildGoodsCard(BuildContext context) {
    final goods = _goods;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(item: goods)),
      ),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AppImage(url: goods.imageUrl, width: 36, height: 36),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goods.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF333333))),
                  const SizedBox(height: 2),
                  Text('视频同款 ¥${goods.price}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFFF5000),
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                context.read<CartProvider>().addToCart(
                      shopName: goods.shopName,
                      title: goods.title,
                      price: double.tryParse(goods.price) ?? 0,
                      imageUrl: goods.imageUrl,
                      spec: '视频同款',
                      quantity: 1,
                    );
                _toast('已加入购物车');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF5000), Color(0xFFFF7A33)],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Text('去购买',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ 右侧操作栏：头像+关注 / 点赞 / 评论 / 收藏 / 分享 ============
  Widget _buildActionRail() {
    final v = widget.video;
    // 关注状态走全局 FollowShopsProvider（与直播间/店铺主页/关注列表同源）
    final followProvider = context.watch<FollowShopsProvider>();
    final followed = followProvider.isFollowed(v.shop);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 头像 + 关注角标
        GestureDetector(
          onTap: () {
            final now = followProvider.toggle(v.shop);
            _toast(now ? '已关注 ${v.shop}' : '已取消关注');
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: v.avatarColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(v.shop[0],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              Positioned(
                bottom: -8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: followed
                        ? const Color(0xFF999999)
                        : AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.2),
                  ),
                  child: Icon(
                      followed ? Icons.check : Icons.add,
                      color: Colors.white,
                      size: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _railItem(
          icon: _liked ? Icons.favorite : Icons.favorite_border,
          color: _liked ? const Color(0xFFFF2E4D) : Colors.white,
          label: _fmtCount(v.likes + (_liked ? 1 : 0)),
          onTap: _toggleLike,
        ),
        const SizedBox(height: 16),
        _railItem(
          icon: Icons.chat_bubble_outline,
          color: Colors.white,
          label: _fmtCount(v.comments),
          onTap: _openComments,
        ),
        const SizedBox(height: 16),
        _railItem(
          icon: _faved ? Icons.star : Icons.star_border,
          color: _faved ? const Color(0xFFFFC107) : Colors.white,
          label: _fmtCount(v.favorites + (_faved ? 1 : 0)),
          onTap: () {
            setState(() => _faved = !_faved);
            _saveInteract();
          },
        ),
        const SizedBox(height: 16),
        _railItem(
          icon: Icons.share,
          color: Colors.white,
          label: _fmtCount(v.shares + (_shared ? 1 : 0)),
          onTap: () {
            Clipboard.setData(const ClipboardData(
                text: '【淘宝】https://m.tb.cn/h.weT88 这条微淘太有趣了，快来看看吧'));
            setState(() => _shared = true);
            _saveInteract();
            _toast('链接已复制，快去分享吧');
          },
        ),
      ],
    );
  }

  Widget _railItem({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 3)])),
        ],
      ),
    );
  }
}

/// 评论底部抽屉：预设评论 + 本地追加
class _CommentSheet extends StatefulWidget {
  final _WeitaoVideo video;
  final List<String> presets;
  const _CommentSheet({required this.video, required this.presets});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  late final List<String> _comments;
  final _inputCtl = TextEditingController();
  static const _nickPool = [
    '淘友**酱',
    '爱吃橘子的猫',
    '买家小Q',
    '种草达人Leo',
    '潜水用户007',
    '囤货小能手',
    '云逛街的阿May',
    '数码老饕',
    '宝妈爱剁手',
    '性价比研究所',
  ];

  /// 评论者昵称/时间/点赞数：按评论内容哈希确定性派生，不再清一色循环
  static int _hashOf(String s) =>
      s.codeUnits.fold(0, (a, c) => (a * 31 + c) & 0x7fffffff);

  @override
  void initState() {
    super.initState();
    _comments = List.of(widget.presets);
  }

  @override
  void dispose() {
    _inputCtl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputCtl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.insert(0, text);
      _inputCtl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.62,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('共 ${widget.video.comments} 条评论',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            // 评论列表
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _comments.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final isMine =
                      i == 0 && _comments.length > widget.presets.length;
                  final h = _hashOf('${_comments[i]}#$i');
                  final nick = isMine ? '我' : _nickPool[h % _nickPool.length];
                  // 时间文案：近几条按小时，其余按天
                  final timeText = isMine
                      ? '刚刚'
                      : (i < 3 ? '${1 + h % 5}小时前' : '${1 + h % 6}天前');
                  final likeCount = isMine ? 0 : 3 + h % 80;
                  final colors = [
                    const Color(0xFFFF5000),
                    const Color(0xFF2B6DEF),
                    const Color(0xFF12A150),
                    const Color(0xFF7C3AED),
                  ];
                  final color = colors[h % colors.length];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: color.withValues(alpha: 0.15),
                          child: Text(nick[0],
                              style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$nick · $timeText',
                                  style: const TextStyle(
                                      color: Color(0xFF999999),
                                      fontSize: 12)),
                              const SizedBox(height: 3),
                              Text(_comments[i],
                                  style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            const Icon(Icons.favorite_border,
                                size: 16, color: Color(0xFFBBBBBB)),
                            Text('$likeCount',
                                style: const TextStyle(
                                    color: Color(0xFFBBBBBB),
                                    fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 输入栏
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border:
                    Border(top: BorderSide(color: Color(0xFFF0F0F0))),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TextField(
                          controller: _inputCtl,
                          decoration: const InputDecoration(
                            hintText: '说点什么...',
                            hintStyle: TextStyle(
                                color: Color(0xFFBBBBBB), fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 9),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _send,
                      child: const Text('发送',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
