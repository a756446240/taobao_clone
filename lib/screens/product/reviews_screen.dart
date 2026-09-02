import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../providers/reviews_provider.dart';
import '../../widgets/app_image.dart';

/// 商品评价列表页（详情页评价区点击进入）
/// 好评率概览 + 标签筛选 + 评价流（晒图/追评/商家回复/有用），按商品名哈希稳定生成
class ReviewsScreen extends StatefulWidget {
  final SearchResultItem item;
  const ReviewsScreen({super.key, required this.item});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  /// 评价内容模板池
  static const _contents = [
    '宝贝质量很好，和描述的一样，物流也很快，好评！',
    '第二次回购了，性价比很高，推荐入手~',
    '包装很用心，没有破损，做工精细，很满意的一次购物。',
    '颜色比图片还好看，上身效果超预期，朋友都说好看！',
    '客服态度很好，有问必答，发货速度也快。',
    '用了几天才来评价，质量确实不错，会推荐给家人。',
    '这个价位能买到这种品质真的很值，已经收藏店铺了。',
    '尺码标准，按照详情页的表选就没问题，物流隔天就到了。',
    '双十一囤的，价格美丽，东西也没让我失望。',
    '材质摸起来很舒服，没有异味，孩子用着放心。',
    '比在实体店看的便宜不少，质量一点不差，好评！',
    '稍微有点色差，但在可接受范围内，整体还是满意的。',
    '已经是第三次买了，家里人都喜欢用，会一直回购。',
    '收到货很惊喜，细节处理得很好，一看就是用心做的产品。',
    '物流超快，昨天下单今天就到了，东西也很好，满分！',
  ];

  static const _nickPool = [
    '淘友**酱', '爱吃橘子的猫', '山**风', '买***家', '柠檬不萌',
    't***8', '王**哥', '小确幸', 'z***3', '追光少年',
    '橘**子', '不负好时光', 'm***6', '认真生活', '一**笑',
  ];

  static const _specs = ['默认款', '升级款', '礼盒装'];

  /// 标签筛选：key=标签名，value=命中条件在生成时打标
  static const _tagNames = ['全部', '晒图', '有追评', '质量不错', '物流快', '性价比高'];

  String _activeTag = '全部';
  final Set<int> _usefulMarked = {};

  int get _seed {
    var h = 0;
    for (final c in widget.item.title.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  /// 生成 12 条评价（同商品稳定）
  late final List<_Review> _reviews = _buildReviews();

  List<_Review> _buildReviews() {
    final list = <_Review>[];
    for (var i = 0; i < 12; i++) {
      final s = _seed + i * 97;
      final content = _contents[s % _contents.length];
      final tags = <String>{
        if (content.contains('质量') || content.contains('品质') || content.contains('做工')) '质量不错',
        if (content.contains('物流') || content.contains('发货') || content.contains('隔天') || content.contains('到了')) '物流快',
        if (content.contains('性价比') || content.contains('价位') || content.contains('便宜') || content.contains('价格')) '性价比高',
      };
      list.add(_Review(
        nick: _nickPool[(s ~/ 3) % _nickPool.length],
        stars: 5 - (s % 11 == 0 ? 1 : 0) - (s % 23 == 0 ? 1 : 0), // 极少 3-4 星
        content: content,
        spec: _specs[(s ~/ 7) % _specs.length],
        daysAgo: 1 + (s ~/ 5) % 58,
        hasPhoto: s % 3 == 0,
        hasFollowUp: s % 4 == 1,
        followUp: s % 4 == 1 ? '用了一段时间，${s % 2 == 0 ? '依然很好用，满意！' : '质量依旧在线，值得推荐。'}' : null,
        hasReply: s % 4 == 2,
        useful: (s ~/ 11) % 90,
        tags: tags,
      ));
    }
    return list;
  }

  int get _goodRate {
    final five = _reviews.where((r) => r.stars >= 4).length;
    return (five / _reviews.length * 100).round();
  }

  List<_Review> get _filtered {
    switch (_activeTag) {
      case '晒图':
        return _reviews.where((r) => r.hasPhoto).toList();
      case '有追评':
        return _reviews.where((r) => r.hasFollowUp).toList();
      case '全部':
        return _reviews;
      default:
        return _reviews.where((r) => r.tags.contains(_activeTag)).toList();
    }
  }

  int _tagCount(String tag) {
    switch (tag) {
      case '全部':
        return _reviews.length;
      case '晒图':
        return _reviews.where((r) => r.hasPhoto).length;
      case '有追评':
        return _reviews.where((r) => r.hasFollowUp).length;
      default:
        return _reviews.where((r) => r.tags.contains(tag)).length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    // 用户自己发布的评价置顶展示（晒图标签下只显示带图的）
    final userReviews = context
        .watch<ReviewsProvider>()
        .reviewsFor(widget.item.title)
        .where((r) =>
            _activeTag == '全部' ||
            (_activeTag == '晒图' && r.photoPaths.isNotEmpty))
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        title: const Text('宝贝评价',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _buildSummary(),
          _buildTagChips(),
          for (final r in userReviews) _buildUserReviewCard(r),
          for (var i = 0; i < filtered.length; i++)
            _buildReviewCard(filtered[i]),
          if (filtered.isEmpty && userReviews.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: Text('暂无该标签的评价', style: AppTextStyles.middleSub)),
            ),
        ],
      ),
    );
  }

  /// 用户自己发布的评价卡（真实晒图文件 + 我的评价标记）
  Widget _buildUserReviewCard(UserReview r) {
    final nick = r.anonymous ? '匿名用户' : '我';
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary,
                child: Text(nick[0],
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(nick, style: AppTextStyles.smallBold)),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EC),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: AppColors.primary),
                ),
                child: const Text('我的评价',
                    style:
                        TextStyle(color: AppColors.primary, fontSize: 9)),
              ),
              const SizedBox(width: 8),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(Icons.star_rounded,
                        size: 14,
                        color: i < r.stars
                            ? const Color(0xFFFFB400)
                            : const Color(0xFFE0E0E0))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.content, style: AppTextStyles.small.copyWith(height: 1.5)),
          const SizedBox(height: 6),
          Text('刚刚 · ${r.spec.isNotEmpty ? r.spec : '默认款'}',
              style:
                  AppTextStyles.min.copyWith(color: AppColors.subText)),
          if (r.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in r.photoPaths)
                  GestureDetector(
                    onTap: () => _previewFile(p),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(p),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 72,
                          height: 72,
                          color: const Color(0xFFF0F0F0),
                          child: const Icon(Icons.broken_image_outlined,
                              color: Color(0xFFCCCCCC)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _previewFile(String path) {
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: InteractiveViewer(
            child: Center(
              child: Image.file(File(path),
                  width: MediaQuery.of(ctx).size.width,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 64)),
            ),
          ),
        ),
      ),
    );
  }

  /// 顶部好评率概览
  Widget _buildSummary() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('$_goodRate',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 30,
                          fontWeight: FontWeight.bold)),
                  const Text('%',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const Text('好评率',
                  style: TextStyle(color: AppColors.subText, fontSize: 11)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  ...List.generate(
                      5,
                      (i) => Icon(Icons.star_rounded,
                          size: 18,
                          color: i < 4
                              ? const Color(0xFFFFB400)
                              : const Color(0xFFE0E0E0))),
                  const SizedBox(width: 6),
                  Text('4.8 分',
                      style: AppTextStyles.smallBold
                          .copyWith(color: const Color(0xFFFFB400))),
                ]),
                const SizedBox(height: 6),
                Text(
                  '共 ${widget.item.commentCount.isNotEmpty ? widget.item.commentCount : '2000+'} 条评价，大家都在夸：质量好、物流快、性价比高',
                  maxLines: 2,
                  style: AppTextStyles.min
                      .copyWith(color: AppColors.subText, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 标签筛选 chips
  Widget _buildTagChips() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _tagNames.map((t) {
          final active = t == _activeTag;
          return GestureDetector(
            onTap: () => setState(() => _activeTag = t),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFFFF1EC)
                    : const Color(0xFFF5F5F5),
                border: Border.all(
                    color: active
                        ? AppColors.primary
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text('$t(${_tagCount(t)})',
                  style: TextStyle(
                      fontSize: 12,
                      color: active
                          ? AppColors.primary
                          : Colors.black87)),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 单条评价卡
  Widget _buildReviewCard(_Review r) {
    final idx = _reviews.indexOf(r);
    final marked = _usefulMarked.contains(idx);
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 + 昵称 + 星级
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    AppColors.primary.withValues(alpha: 0.12),
                child: Text(r.nick[0],
                    style: const TextStyle(
                        color: AppColors.primary, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(r.nick, style: AppTextStyles.smallBold)),
              Row(
                children: List.generate(
                    5,
                    (i) => Icon(Icons.star_rounded,
                        size: 14,
                        color: i < r.stars
                            ? const Color(0xFFFFB400)
                            : const Color(0xFFE0E0E0))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r.content,
              style: AppTextStyles.small.copyWith(height: 1.5)),
          const SizedBox(height: 6),
          Text('${r.daysAgo}天前 · ${r.spec}',
              style: AppTextStyles.min
                  .copyWith(color: AppColors.subText)),
          // 晒图（用商品图做缩略图，点击可放大预览）
          if (r.hasPhoto && widget.item.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var k = 0; k < 1 + (idx % 3); k++) ...[
                  GestureDetector(
                    onTap: () => _previewImage(),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: AppImage(
                          url: widget.item.imageUrl,
                          width: 72,
                          height: 72),
                    ),
                  ),
                  if (k < (idx % 3)) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
          // 追评
          if (r.hasFollowUp && r.followUp != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('追评：${r.followUp}',
                  style: AppTextStyles.min.copyWith(
                      color: Colors.black87, height: 1.4)),
            ),
          ],
          // 商家回复
          if (r.hasReply) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F0),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                  '商家回复：亲亲，感谢您的支持，我们会继续努力，期待您的再次光临！',
                  style: AppTextStyles.min.copyWith(
                      color: const Color(0xFF8B5A2B), height: 1.4)),
            ),
          ],
          const SizedBox(height: 8),
          // 有用按钮
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => setState(() {
                marked
                    ? _usefulMarked.remove(idx)
                    : _usefulMarked.add(idx);
              }),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      marked
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      size: 14,
                      color: marked
                          ? AppColors.primary
                          : AppColors.subText),
                  const SizedBox(width: 4),
                  Text('有用(${r.useful + (marked ? 1 : 0)})',
                      style: TextStyle(
                          fontSize: 11,
                          color: marked
                              ? AppColors.primary
                              : AppColors.subText)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previewImage() {
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: InteractiveViewer(
            child: Center(
              child: AppImage(
                  url: widget.item.imageUrl,
                  width: MediaQuery.of(ctx).size.width),
            ),
          ),
        ),
      ),
    );
  }
}

class _Review {
  final String nick;
  final int stars;
  final String content;
  final String spec;
  final int daysAgo;
  final bool hasPhoto;
  final bool hasFollowUp;
  final String? followUp;
  final bool hasReply;
  final int useful;
  final Set<String> tags;

  const _Review({
    required this.nick,
    required this.stars,
    required this.content,
    required this.spec,
    required this.daysAgo,
    required this.hasPhoto,
    required this.hasFollowUp,
    this.followUp,
    required this.hasReply,
    required this.useful,
    required this.tags,
  });
}
