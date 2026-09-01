import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/models.dart';
import '../../widgets/app_image.dart';

/// 「问大家」问答数据（详情页预览与问答页共用）
class QaAnswer {
  final String nick;
  final String text;
  final int useful;

  const QaAnswer(this.nick, this.text, this.useful);
}

class QaEntry {
  final String question;
  final List<QaAnswer> answers;

  const QaEntry(this.question, this.answers);
}

/// 按商品标题哈希稳定生成 8 条问答（同商品每次一致，不同商品各异）
List<QaEntry> buildQaEntries(String title) {
  const questions = [
    '尺码标准吗？平时穿 M 码拍什么码合适',
    '质量怎么样？洗几次会变形吗',
    '实物和图片色差大吗',
    '掉色吗？第一次洗会染色吗',
    '敏感肌可以用吗？会不会刺激',
    '有没有异味？打开包装味道大不大',
    '发什么快递？一般几天能到',
    '可以开发票吗？保修多久',
    '小孩/孕妇可以用吗',
    '和实体店买的是一样的吗',
    '起球吗？穿久了会不会显旧',
    '这个价位性价比怎么样，值得入手吗',
  ];
  const answers = [
    '标准的，按平时尺码拍就行，不偏码。',
    '质量很好，洗了好几次了没有变形，放心买。',
    '基本没有色差，实物比图片还好看一点。',
    '不掉色，我第一次洗特意分开洗的，水很清。',
    '我是敏感肌，用了没有不适，挺温和的。',
    '刚打开有一点点味道，晾一天就没了，不影响使用。',
    '发的中通，我这边三天就到了，挺快的。',
    '可以开发票，联系客服备注就行，全国联保一年。',
    '我家孩子一直在用，成分很安全，没问题。',
    '是一样的，我对比过专柜，正品放心入。',
    '穿了一个多月了没有起球，面料很耐穿。',
    '这个价位能买到这种品质真的很值，推荐入手。',
    '偏小半码，建议拍大一码更舒服。',
    '客服说深浅色分开洗就行，我洗了没染色。',
    '物流超快，第二天就收到了，包装也很仔细。',
  ];
  const nicks = [
    '淘友**酱', '爱吃橘子的猫', '山**风', '买***家', '柠檬不萌',
    't***8', '王**哥', '小确幸', 'z***3', '追光少年',
  ];

  var h = 0;
  for (final c in title.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  final start = h % questions.length;
  return [
    for (var i = 0; i < 8; i++)
      QaEntry(
        questions[(start + i * 5) % questions.length],
        [
          for (var j = 0; j < 2 + (h + i * 7) % 4; j++)
            QaAnswer(
              nicks[(h + i * 3 + j) % nicks.length],
              answers[(h + i * 11 + j * 4) % answers.length],
              (h * 7 + i * 13 + j * 29) % 200,
            ),
        ],
      ),
  ];
}

/// 商品「问大家」列表页（详情页问大家区块点击进入）
/// 问答列表 + 查看全部回答 + 我来回答 + 去提问，数据按商品名哈希稳定生成
class QaScreen extends StatefulWidget {
  final SearchResultItem item;
  const QaScreen({super.key, required this.item});

  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  /// 可变副本（支持本地提问/回答追加）
  late final List<_MutableQa> _items = [
    for (final e in buildQaEntries(widget.item.title))
      _MutableQa(e.question, [...e.answers]),
  ];

  /// 已点「有用」的回答（key: 问题下标_回答下标）
  final Set<String> _usefulMarked = {};

  int get _totalAnswers =>
      _items.fold(0, (sum, e) => sum + e.answers.length);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('问大家', style: AppTextStyles.appBarTitleBlack),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProductHeader(),
          _buildSummary(),
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, i) => _buildQuestionCard(i),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildAskBar(),
    );
  }

  // ============ 顶部商品卡 ============
  Widget _buildProductHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: AppImage(url: widget.item.imageUrl, width: 48, height: 48),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.item.title,
                style: AppTextStyles.small,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  // ============ 汇总行 ============
  Widget _buildSummary() {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Text(
        '共 ${_items.length} 个问题 · $_totalAnswers 个回答，买过的淘友帮你解答',
        style: AppTextStyles.minSub,
      ),
    );
  }

  // ============ 问题卡片 ============
  Widget _buildQuestionCard(int qi) {
    final item = _items[qi];
    final best = item.answers.isNotEmpty ? item.answers.first : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showAnswerSheet(qi),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _badge('问', AppColors.primary),
                if (item.mine) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('我的',
                        style:
                            TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.question, style: AppTextStyles.smallBold),
                ),
              ],
            ),
            if (best != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge('答', const Color(0xFF42a5f5)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(best.text,
                        style: AppTextStyles.smallSub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  item.answers.isEmpty
                      ? '暂无回答，等你来答'
                      : '共 ${item.answers.length} 个回答',
                  style: AppTextStyles.min,
                ),
                const Spacer(),
                const Text('查看全部',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.subText)),
                const Icon(Icons.chevron_right,
                    color: AppColors.subLightText, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  // ============ 全部回答 bottom sheet ============
  void _showAnswerSheet(int qi) {
    final answerCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            final item = _items[qi];
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _badge('问', AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(item.question,
                                style: AppTextStyles.smallBold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: item.answers.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(30),
                              child: Text('暂无回答，成为第一个回答的淘友吧',
                                  style: AppTextStyles.smallSubLight),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: item.answers.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: AppColors.divider),
                              itemBuilder: (ctx, ai) {
                                final a = item.answers[ai];
                                final key = '${qi}_$ai';
                                final marked = _usefulMarked.contains(key);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _badge('答', const Color(0xFF42a5f5)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(a.nick,
                                                style: AppTextStyles.minSub),
                                            const SizedBox(height: 3),
                                            Text(a.text,
                                                style: AppTextStyles.small),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => setSheet(() {
                                          if (marked) {
                                            _usefulMarked.remove(key);
                                          } else {
                                            _usefulMarked.add(key);
                                          }
                                        }),
                                        child: Row(
                                          children: [
                                            Icon(
                                              marked
                                                  ? Icons.thumb_up_alt
                                                  : Icons
                                                      .thumb_up_alt_outlined,
                                              size: 14,
                                              color: marked
                                                  ? AppColors.primary
                                                  : AppColors.subLightText,
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${a.useful + (marked ? 1 : 0)}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: marked
                                                    ? AppColors.primary
                                                    : AppColors.subLightText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    // 我来回答
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: answerCtrl,
                              maxLength: 100,
                              decoration: InputDecoration(
                                hintText: '我来回答…',
                                hintStyle: AppTextStyles.smallSubLight,
                                counterText: '',
                                filled: true,
                                fillColor: AppColors.searchBarBg,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              final text = answerCtrl.text.trim();
                              if (text.isEmpty) return;
                              setSheet(() {
                                item.answers.add(QaAnswer('我', text, 0));
                              });
                              answerCtrl.clear();
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('回答成功')));
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Text('发送',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ============ 底部提问栏 ============
  Widget _buildAskBar() {
    return SafeArea(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: GestureDetector(
          onTap: _showAskSheet,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.searchBarBg,
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Row(
              children: [
                Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.subLightText),
                SizedBox(width: 6),
                Text('有什么问题，问问买过的淘友',
                    style: AppTextStyles.smallSubLight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAskSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('向买过的淘友提问', style: AppTextStyles.middleBold),
                const SizedBox(height: 10),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLength: 60,
                  maxLines: 3,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: '请描述你的问题，如：尺码偏吗？质量怎么样？',
                    hintStyle: AppTextStyles.smallSubLight,
                    filled: true,
                    fillColor: AppColors.searchBarBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请先输入问题内容')));
                        return;
                      }
                      setState(() =>
                          _items.insert(0, _MutableQa(text, [], mine: true)));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('提问成功，等待淘友回答')));
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text('发布提问',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 可变问答（页面状态内使用）
class _MutableQa {
  final String question;
  final List<QaAnswer> answers;
  final bool mine;

  _MutableQa(this.question, this.answers, {this.mine = false});
}
