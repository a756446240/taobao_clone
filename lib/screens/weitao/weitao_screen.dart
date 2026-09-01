import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// 微淘 AI 视频数据（搬运自 HaotaoMarket v3.4 APK）
class _WeitaoVideo {
  final String asset;
  final String title;
  final String tag;
  const _WeitaoVideo(this.asset, this.title, this.tag);
}

const List<_WeitaoVideo> _videos = [
  _WeitaoVideo('assets/videos/video1.mp4', '进口辅酶Q10软胶囊 60粒装',
      'Swisse 海外旗舰店'),
  _WeitaoVideo('assets/videos/video2.mp4', '智能仓储分拣 全程可视化物流',
      '菜鸟国际物流'),
  _WeitaoVideo('assets/videos/video3.mp4', '618 全球好物节 大促预热',
      '天猫国际'),
  _WeitaoVideo('assets/videos/video4.mp4', '源头好货 跨境直采航拍之旅',
      '海外直营'),
];

/// 微淘页：抖音式全屏视频流，上下滑动切换（单击暂停/播放）
/// 播放实现：每个视频页各自持有 controller，仅初始化当前激活页，
/// 失败时显示错误占位并可点击重试。
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
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题栏
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('上滑切换 · 点击暂停',
                      style: AppTextStyles.min
                          .copyWith(color: AppColors.subText)),
                ],
              ),
            ),
            // 视频流：上下滑动切换，占满整个栏目
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _videos.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, index) => _VideoPage(
                  video: _videos[index],
                  isActive: index == _current,
                  muted: _muted,
                  onToggleMute: () => setState(() => _muted = !_muted),
                ),
              ),
            ),
            // 底部信息 + 指示器
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_videos[_current].title}  ·  ${_videos[_current].tag}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.min
                          .copyWith(color: AppColors.subText),
                    ),
                  ),
                  ...List.generate(_videos.length, (i) {
                    final active = i == _current;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.only(left: 4),
                      width: active ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.primary
                            : const Color(0xFFdddddd),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个视频页：自己持有 controller（v3.4 已验证的播放方案）
class _VideoPage extends StatefulWidget {
  final _WeitaoVideo video;
  final bool isActive;
  final bool muted;
  final VoidCallback onToggleMute;

  const _VideoPage({
    required this.video,
    required this.isActive,
    required this.muted,
    required this.onToggleMute,
  });

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _ctl;
  bool _initError = false;
  bool _playing = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    // 只初始化当前激活页，避免同时创建多个播放器导致低端机解码器实例不足
    if (widget.isActive) _init();
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

  @override
  Widget build(BuildContext context) {
    final c = _ctl;
    return GestureDetector(
      onTap: _togglePlay,
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
                      // 静音按钮
                      Positioned(
                        right: 12,
                        top: 12,
                        child: GestureDetector(
                          onTap: widget.onToggleMute,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              widget.muted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      // 底部渐变 + 标题
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                          child: Text(
                            widget.video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
