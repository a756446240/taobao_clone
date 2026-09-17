import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/mock_data.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/material_pool_provider.dart';
import '../../providers/product_image_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/image_picker_helper.dart';
import '../home/channel_screen.dart';
import '../message/chat_screen.dart';
import '../order/express_library_screen.dart';
import '../order/order_list_screen.dart';
import 'ai_order_audit_screen.dart';
import 'ai_order_import_screen.dart';
import 'taobao_sync_import_screen.dart';
import 'benefits_screen.dart';
import 'coupon_center_screen.dart';
import 'favorites_screen.dart';
import 'followed_shops_screen.dart';
import 'footprints_screen.dart';
import 'settings_screen.dart';
import 'material_pool_screen.dart';
import 'address_screen.dart';
import 'profile_edit_screen.dart';

/// 我的页（1:1 复刻新版淘宝）
/// 头像/顶部背景图可直接从手机相册选择，所有资料改动持久化保存。
class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
  // ============ 农场横幅倒计时（v1.9.117：逐位滚动，到底自动循环） ============
  static const int _farmInitSeconds = 10 * 3600 + 44 * 60 + 20;
  int _farmSeconds = _farmInitSeconds;
  Timer? _farmTimer;

  // v1.9.119：页面滚动控制器（下滑出吸顶栏）+ 圆圈行横向滚动（指示条联动）
  final ScrollController _scrollCtrl = ScrollController();
  final ScrollController _circleCtrl = ScrollController();
  bool _showTopBar = false;
  double _circleRatio = 0;

  @override
  void initState() {
    super.initState();
    _farmTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _farmSeconds--;
        if (_farmSeconds < 0) _farmSeconds = _farmInitSeconds; // 滚完自动循环
      });
    });
    _scrollCtrl.addListener(() {
      final show = _scrollCtrl.offset > 110;
      if (show != _showTopBar) setState(() => _showTopBar = show);
    });
    _circleCtrl.addListener(() {
      if (!_circleCtrl.hasClients) return;
      final max = _circleCtrl.position.maxScrollExtent;
      if (max <= 0) return;
      setState(() =>
          _circleRatio = (_circleCtrl.offset / max).clamp(0.0, 1.0));
    });
  }

  @override
  void dispose() {
    _farmTimer?.cancel();
    _scrollCtrl.dispose();
    _circleCtrl.dispose();
    super.dispose();
  }

  /// 单个字符的滚动切换（新字符从下方滚入，旧字符向上滚出）
  Widget _rollChar(String ch, TextStyle style) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      transitionBuilder: (child, anim) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.7),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        return ClipRect(
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: SizedBox(
        key: ValueKey(ch),
        width: ch == ':' ? 4 : 7.5,
        child: Text(ch, style: style, textAlign: TextAlign.center),
      ),
    );
  }

  /// 滚动倒计时文本：hh:mm:ss 逐位滚动
  Widget _rollingCountdown(TextStyle style) {
    final h = (_farmSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_farmSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_farmSeconds % 60).toString().padLeft(2, '0');
    final chars = '$h:$m:$s'.split('');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: chars.map((c) => _rollChar(c, style)).toList(),
    );
  }

  // ============ 相册选图 ============
  Future<String?> _pickImageToLocal(String subDir) async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${dir.path}/$subDir');
      if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
      final ext = picked.path.contains('.')
          ? picked.path.substring(picked.path.lastIndexOf('.'))
          : '.jpg';
      final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}$ext';
      final saved = await File(picked.path).copy('${saveDir.path}/$fileName');
      return saved.path;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('选择图片失败')));
      }
      return null;
    }
  }

  Future<void> _pickAvatar() async {
    final path = await _pickImageToLocal('profile_avatars');
    if (path != null) {
      await context.read<ProfileProvider>().updateAvatar(path);
    }
  }

  Future<void> _pickHeaderBg() async {
    final path = await _pickImageToLocal('profile_headers');
    if (path != null) {
      await context.read<ProfileProvider>().updateHeaderBg(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          ListView(
            controller: _scrollCtrl,
            padding: EdgeInsets.zero,
            children: [
              // v1.9.118：农场横幅已收进黑框会员区（v1.9.117 重复展示问题修复）
              // 渐变头（含黑框会员区）→ 快递/收藏/关注店铺/足迹
              // → 我的订单 → 芭芭农场等圆圈（横向翻页）→ 领券中心 → 推荐流
              _buildHeaderSection(),
              _buildToolCards(),
              _buildOrderSection(),
              _buildAppGrid(),
              _buildCouponCards(),
              _buildFeedSection(),
              const SizedBox(height: 16),
            ],
          ),
          // v1.9.119：下滑时吸顶栏（淘宝名字 + 地址/专属客服/设置）
          _buildStickyBar(),
        ],
      ),
    );
  }

  /// 下滑吸顶栏：头像+昵称 左，地址/专属客服/设置 右（对齐真实淘宝）
  Widget _buildStickyBar() {
    final profile = context.watch<ProfileProvider>();
    final top = MediaQuery.of(context).padding.top;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      top: _showTopBar ? 0 : -(top + 64),
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, top + 8, 14, 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE0CC), Color(0xFFFFB088)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // v1.9.120：吸顶栏不带头像（用户要求，对齐真实淘宝只留名字+按钮）
            Expanded(
              child: Text(
                profile.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            GestureDetector(
              onTap: _gotoAddress,
              behavior: HitTestBehavior.opaque,
              child: _stickyBtn(
                  icon: Icons.location_on_outlined, label: '地址'),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _openOfficialService,
              behavior: HitTestBehavior.opaque,
              child: _stickyBtn(
                  asset: 'assets/icons/mine/ic_service_vip.png', label: '专属客服'),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: _openSettings,
              behavior: HitTestBehavior.opaque,
              child: _stickyBtn(
                  icon: Icons.settings_outlined, label: '设置'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stickyBtn({IconData? icon, String? asset, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 20,
          child: asset != null
              ? Image.asset(asset, height: 20, fit: BoxFit.contain)
              : Icon(icon, size: 19, color: Colors.black87),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.black87)),
      ],
    );
  }

  // ============ 顶部渐变区（v1.9.116：渐变背景贯穿覆盖会员卡+权益栏） ============
  Widget _buildHeaderSection() {
    final profile = context.watch<ProfileProvider>();
    final hasBg = profile.headerBg.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        gradient: hasBg
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE0CC), Color(0xFFFFB088)],
              ),
        image: hasBg
            ? DecorationImage(
                image: FileImage(File(profile.headerBg)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Column(
        children: [
          _buildHeaderContent(profile),
          _buildMemberFrame(),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ============ 顶部个人信息 ============
  Widget _buildHeaderContent(ProfileProvider profile) {
    return GestureDetector(
      onDoubleTap: _pickHeaderBg, // 双击从相册换顶部背景图
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              GestureDetector(
                onTap: _gotoEdit, // 单击进资料编辑
                onDoubleTap: _pickAvatar, // 头像双击从相册选
                child: ClipOval(
                  child: Container(
                    width: 44,
                    height: 44,
                    color: const Color(0xFFffd180),
                    child: profile.avatar.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 28)
                        : AppImage(url: profile.avatar, width: 44, height: 44),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _gotoEdit, // 单击进资料编辑
                      child: Text(profile.nickname,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 4),
                    // 88VIP / 等级 / 关注店铺
                    Row(
                      children: [
                        _vipTag('88VIP'),
                        const SizedBox(width: 6),
                        _levelTag(profile.level),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _gotoEdit, // 单击进资料编辑
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront_outlined,
                                  size: 12, color: Color(0xFF1A1A1A)),
                              const SizedBox(width: 2),
                              Text(
                                profile.slogan.isEmpty ? '关注店铺' : profile.slogan,
                                style: const TextStyle(
                                    color: Color(0xFF1A1A1A), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 地址：单击进收货地址列表（对齐真实淘宝），双击进素材库
              GestureDetector(
                onTap: _gotoAddress,
                onDoubleTap: _gotoMaterialPool,
                child: _headerIcon(Icons.location_on_outlined, '地址'),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _openOfficialService,
                child: _vipServiceIcon(),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: _openSettings,
                onDoubleTap: _gotoEdit,
                child: _headerIcon(Icons.settings_outlined, '设置'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 88VIP 徽章：深棕黑底 + 金色渐变字（v1.9.116 对齐真实淘宝：偏胖偏窄渐变字）
  Widget _vipTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: const Color(0xFF241A0E),
        borderRadius: BorderRadius.circular(3),
      ),
      child: ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF9EAC7), Color(0xFFD8A556)],
        ).createShader(bounds),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                height: 1.1)),
      ),
    );
  }

  /// 会员等级徽章（钻石会员等）：深藏青底 + 银白渐变字
  Widget _levelTag(String level) {
    // 避免和 88VIP 重复显示
    final display = level == '88VIP' ? '钻石会员' : level;
    return GestureDetector(
      onTap: _pickLevel, // 单击切换会员等级
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
        decoration: BoxDecoration(
          color: const Color(0xFF323A5C),
          borderRadius: BorderRadius.circular(3),
        ),
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFB8C5E6)],
          ).createShader(bounds),
          child: Text(display,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  height: 1.1)),
        ),
      ),
    );
  }

  Future<void> _pickLevel() async {
    final profile = context.read<ProfileProvider>();
    final level = await DialogHelpers.showOptionPicker(
      context,
      title: '会员等级',
      options: ProfileProvider.levelOptions,
      currentValue: profile.level,
    );
    if (level != null) {
      await profile.save(
        avatar: profile.avatar,
        nickname: profile.nickname,
        level: level,
        slogan: profile.slogan,
        address: profile.address,
        headerBg: profile.headerBg,
      );
    }
  }

  void _gotoEdit() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
    );
  }

  /// "地址"双击 → 商品素材库（导入素材图，打开 App 时随机展示）
  void _gotoMaterialPool() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MaterialPoolScreen()),
    );
  }

  /// "地址"单击 → 收货地址列表（对齐真实淘宝，左滑 设为默认/复制/删除）
  void _gotoAddress() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddressScreen()),
    );
  }

  Widget _headerIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.black87),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87)),
      ],
    );
  }

  /// 专属客服标：真实淘宝 88VIP 耳机贴图（v1.9.117 从真淘宝截图抠取）
  Widget _vipServiceIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/icons/mine/ic_service_vip.png',
            height: 22, fit: BoxFit.contain),
        const SizedBox(height: 2),
        const Text('专属客服',
            style: TextStyle(fontSize: 10, color: Colors.black87)),
      ],
    );
  }

  // ============ 整体黑框会员区（v1.9.117 对齐真实淘宝） ============
  // 深棕黑框内含：上行（本月已省）→ 权益行（白字）→ 农场横幅；
  // v1.9.125：白卡收进黑框内部右上（v1.9.123 的「立顶」探出黑框上缘
  // 被用户驳回——真实淘宝白卡完全在黑框内，垂直对齐本月已省行，带投影）
  Widget _buildMemberFrame() {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2A1E0C),
                Color(0xFF4C3714),
                Color(0xFF7A5C24),
              ],
            ),
            border: Border.all(color: const Color(0xFFC9A25E), width: 0.6),
          ),
          child: Column(
            children: [
              // 上行：本月已省（右侧留白给立顶白卡）
              Padding(
                padding: const EdgeInsets.only(right: 182),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BenefitsScreen()),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: '本月已省',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            // v1.9.131：对齐 15:50 真淘宝参考图 本月已省140元
                            text: '140',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: '元',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ]),
                      ),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right,
                          size: 14, color: Color(0xFFD9BE8A)),
                    ],
                  ),
                ),
              ),
              // v1.9.127 白卡探出后底边在黑框内 y≈50，权益行 16+26+26=68 起，不重叠
              const SizedBox(height: 26),
              _buildWalletRowInDark(),
              const SizedBox(height: 12),
              _buildFarmBanner(),
            ],
          ),
        ),
        // 白卡：右上，顶部探出黑框上缘 6pt（16:01 真淘宝实测）——
        // 白卡像一张纸插在黑框槽里，探出部分 + 左上角卡其三角 = 折纸效果。
        // v1.9.126 的「白卡整体收在黑框内 + 内部三角」被用户否了（没有折纸感），
        // 关键不是三角大小而是【探出+三角填补凹槽】的结构
        Positioned(
          top: 0, // 黑框 margin-top 6 → 白卡探出黑框上缘 6pt
          right: 12,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _memberWhiteCard(),
              // 折角三角：填补白卡顶缘与黑框顶缘之间的凹槽，
              // 直角在右下，竖直边贴白卡左缘（高度=探出量 6pt）
              const Positioned(
                left: -8,
                top: 0,
                child: _FoldCorner(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 右上白色立体卡：会员中心 | 88VIP | ¥2红包（对齐真实淘宝立体框架）
  Widget _memberWhiteCard() {
    void gotoBenefits() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BenefitsScreen()),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          // v1.9.124 立顶卡：深棕底上 0.30 黑影几乎不可见——
          // 加深到 0.55 + 大模糊 + 扩散，白卡明显浮在黑框上缘
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: gotoBenefits,
            child: _memberCol('会员中心', '去解锁会员权益'),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: gotoBenefits,
            child: _memberCol('88VIP', '2元红包'),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openCouponCenter,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF5A4E), Color(0xFFE8211A)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('¥2',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          height: 1.1)),
                  Text('红包',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          height: 1.1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 白色立体卡里的栏目（黑字标题 + 灰字副标题›）
  Widget _memberCol(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF999999), fontSize: 11)),
            ),
            const Icon(Icons.chevron_right,
                size: 12, color: Color(0xFF999999)),
          ],
        ),
      ],
    );
  }

  // ============ 权益行（v1.9.117：黑框内白字版，对齐真实淘宝） ============
  Widget _buildWalletRowInDark() {
    // v1.9.128：数值对齐 13:16 真淘宝截图（原 领红包/领优惠/¥1.30/5/¥0.00 被用户点「离谱」）
    // v1.9.129：4 项竖杆删除 + 借钱卡片（竖杆+全部权益竖排+去使用按钮）
    // v1.9.130：用户反馈「借钱栏和左边项目对齐，去使用删除后框架缩小去空白」
    // ——借钱改为第 5 个等宽栏（标签 12px/值 15px bold，与其他栏同规格同基线），
    // 去使用按钮删除，行高回到全部权益竖排高度（≈62pt），黑框不再留白
    final items = [
      // v1.9.131：数值对齐 15:50 真淘宝新参考图（¥1464/29张/¥7.91/2348）
      _WalletItem('红包', '¥1464', Colors.white),
      _WalletItem('优惠券', '29张', Colors.white),
      _WalletItem('淘金币抵', '¥7.91', const Color(0xFFFFD28A)),
      _WalletItem('天猫积分', '2348', const Color(0xFFFFD28A)),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...items.asMap().entries.map((e) => Expanded(
              child: GestureDetector(
                // 单击进入权益钱包页对应标签
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => BenefitsScreen(initialIndex: e.key)),
                ),
                child: Column(
                  children: [
                    Text(e.value.label,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xCCFFFFFF))),
                    const SizedBox(height: 4),
                    Text(e.value.value,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: e.value.color)),
                  ],
                ),
              ),
            )),
        // 借钱：第 5 个等宽栏，与左边 4 栏同规格同基线（采样色 #B9AC9B/#E3DBCA）
        Expanded(
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => BenefitsScreen(initialIndex: 4)),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('借钱',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFB9AC9B))),
                    SizedBox(width: 2),
                    Icon(Icons.help_outline,
                        size: 11, color: Color(0xFFB9AC9B)),
                  ],
                ),
                SizedBox(height: 4),
                Text('一键查额',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE3DBCA))),
              ],
            ),
          ),
        ),
        // 借钱与全部权益之间的竖杆 + 全部权益竖排 + ›
        // v1.9.131：竖排收紧到与左侧「标签+数值」两行同高（≈40pt，
        // 10px/height1.0 紧凑排），益底对齐数值行底（用户点名，对齐 15:50
        // 真淘宝参考图）；行高从 62pt 降下来后，下方横幅随 Column 自然
        // 上移补齐，黑框底部多余空白消除、整体框缩小
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const BenefitsScreen()),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                  width: 1,
                  height: 38,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  color: const Color(0x40FFFFFF)),
              const Text('全\n部\n权\n益',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      height: 1.0,
                      color: Color(0xFFB9AC9B))),
              const Icon(Icons.chevron_right,
                  size: 12, color: Color(0xFFB9AC9B)),
            ],
          ),
        ),
      ],
    );
  }

  // ============ 农场横幅（v1.9.117：黑框内版，倒计时逐位滚动、到底自动循环） ============
  Widget _buildFarmBanner() {
    const textStyle = TextStyle(fontSize: 12, color: Color(0xFF6E6117));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChannelScreen(
            entry: const HomeIconEntry(
                '芭芭农场', '领', 0xFFff4d4f, 'assets/images/icons/farm.png'),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F3D8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFE8DFA8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.eco,
                  size: 13, color: Color(0xFF8A7B1E)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Flexible(
                    child: Text('3000肥料已到账，',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle),
                  ),
                  _rollingCountdown(textStyle),
                  const Text('后失效', style: textStyle),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                border:
                    Border.all(color: const Color(0xFFB3A24A), width: 0.8),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Text('去查收',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8A7B1E),
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ============ 我的订单 ============
  Widget _buildOrderSection() {
    // v1.9.100：五个入口图标右上角橙色角标，数量按 IPA 内订单实际状态统计
    final counts =
        CartProvider.statusCounts(context.watch<CartProvider>().shops);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('我的订单', style: AppTextStyles.middleBold),
              const Spacer(),
              GestureDetector(
                onTap: () => _gotoOrder('全部订单'),
                child: const Text('全部 >', style: AppTextStyles.smallSub),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _orderItem('待付款', counts['待付款'] ?? 0),
              _orderItem('待发货', counts['待发货'] ?? 0),
              _orderItem('待收货', counts['待收货'] ?? 0),
              _orderItem('待评价', counts['待评价'] ?? 0),
              _orderItem('退款/售后', counts['退款/售后'] ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderItem(String label, [int badge = 0]) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _gotoOrder(label),
        child: Column(
          children: [
            _orderIcon(label, badge),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.small),
          ],
        ),
      ),
    );
  }

  Widget _orderIcon(String label, [int badge = 0]) {
    // v1.9.117：图标换真实淘宝 1:1 贴图（从真淘宝截图抠取，透明底）
    String asset;
    switch (label) {
      case '待付款':
        asset = 'assets/icons/mine/ic_daifukuan.png';
        break;
      case '待发货':
        asset = 'assets/icons/mine/ic_daifahuo.png';
        break;
      case '待收货':
        asset = 'assets/icons/mine/ic_daishouhuo.png';
        break;
      case '待评价':
        asset = 'assets/icons/mine/ic_daipingjia.png';
        break;
      default:
        asset = 'assets/icons/mine/ic_tuikuan.png';
    }
    final ic = Image.asset(asset, height: 26, fit: BoxFit.contain);
    if (badge <= 0) return ic;
    // 橙色数字角标（对齐真实淘宝：图标右上角橙色圆底白字，>99 显示 99+）
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ic,
        Positioned(
          right: -8,
          top: -5,
          child: Container(
            constraints: const BoxConstraints(minWidth: 16),
            height: 16,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5000),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              badge > 99 ? '99+' : '$badge',
              style: const TextStyle(
                  fontSize: 10,
                  height: 1,
                  color: Colors.white,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  // ============ 工具卡片 ============
  Widget _buildToolCards() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _toolIcon('assets/icons/mine/ic_kuaidi.png', '快递',
              onTap: _openLogistics),
          _toolIcon('assets/icons/mine/ic_shoucang.png', '收藏',
              onTap: _openFavorites),
          _toolIcon('assets/icons/mine/ic_guanzhu.png', '关注店铺',
              onTap: _openFollowedShops, onDoubleTap: _openAiAudit),
          _toolIcon('assets/icons/mine/ic_zuji.png', '足迹',
              onTap: _openFootprints,
              onDoubleTap: _openAiImport,
              onLongPress: _openTaobaoSync),
        ],
      ),
    );
  }

  /// 长按「足迹」→ 淘宝订单 JSON 同步导入（隐藏入口，界面不显示）
  void _openTaobaoSync() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TaobaoSyncImportScreen()),
    );
  }

  /// 双击"足迹" → AI 订单截图解析
  void _openAiImport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiOrderImportScreen()),
    );
  }

  /// 双击"关注店铺" → AI 数据校验
  void _openAiAudit() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiOrderAuditScreen()),
    );
  }

  /// 单击"关注店铺" → 关注店铺列表
  void _openFollowedShops() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FollowedShopsScreen()),
    );
  }

  /// 单击"快递" → 快递库（v1.9.136：所有抓包/联网快递汇总列表）
  void _openLogistics() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExpressLibraryScreen()),
    );
  }

  /// 单击"收藏的宝贝" → 收藏夹
  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  /// 单击"足迹" → 我的足迹（双击仍是 AI 订单截图解析）
  void _openFootprints() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FootprintsScreen()),
    );
  }

  /// 单击"设置" → 设置页（双击仍是编辑资料）
  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen(version: '1.9.140')),
    );
  }

  /// 单击"官方客服" → 平台客服会话
  void _openOfficialService() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ChatScreen(
          conversation: Conversation(
            avatar: '',
            title: '淘宝官方客服',
            description: '官方客服在线，有问题随时问',
            createAt: '',
          ),
          accentColor: Color(0xFFFF5000),
        ),
      ),
    );
  }

  /// 快捷入口：真实淘宝 1:1 贴图图标（v1.9.117），下方灰字已按需求删除
  Widget _toolIcon(String asset, String title,
      {VoidCallback? onTap,
      VoidCallback? onDoubleTap,
      VoidCallback? onLongPress}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Image.asset(asset, height: 26, fit: BoxFit.contain),
            const SizedBox(height: 6),
            Text(title, style: AppTextStyles.small),
          ],
        ),
      ),
    );
  }

  // ============ 领券中心（单击整卡 → 领券中心完整页） ============
  Widget _buildCouponCards() {
    return GestureDetector(
      onTap: _openCouponCenter,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('领券中心', style: AppTextStyles.middleBold)),
              const Text('惊喜优惠券  限量抢 >', style: AppTextStyles.smallSub),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // v1.9.116：首卡 88VIP 专享金色券，其余红底券（对齐真实淘宝）
              _vipCoupon('¥635', '88VIP专享'),
              const SizedBox(width: 8),
              _bigCoupon('¥6', '秋装加补券',
                  bg: const Color(0xFFFFECEF),
                  fg: const Color(0xFFFF2450)),
              const SizedBox(width: 8),
              _bigCoupon('¥5', '智家加补券',
                  bg: const Color(0xFFFFECEF),
                  fg: const Color(0xFFFF2450)),
              const SizedBox(width: 8),
              _bigCoupon('¥50', '珠宝加补券',
                  bg: const Color(0xFFFFECEF),
                  fg: const Color(0xFFFF2450)),
            ],
          ),
        ],
      ),
      ),
    );
  }

  /// 单击领券中心卡片 → 领券中心完整页
  void _openCouponCenter() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CouponCenterScreen()),
    );
  }

  /// 88VIP 专享券：黄金渐变底 + 深棕按钮（领券中心首卡，对齐真实淘宝）
  Widget _vipCoupon(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6E7C8), Color(0xFFE3C78E)],
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: Color(0xFF7A5A1C),
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: const Color(0xFF7A5A1C).withValues(alpha: 0.75),
                    fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF3A2C12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('去领取',
                  style: TextStyle(
                      color: Color(0xFFF6E7C8), fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bigCoupon(String value, String label,
      {required Color bg, required Color fg}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: fg,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: fg.withValues(alpha: 0.65), fontSize: 11)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: fg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('去领取',
                  style: TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ],
        ),
      ),
    );
  }

  // ============ App 圆圈入口（真实淘宝图标，素材库 icons/） ============
  // 单击进入对应频道落地页（复用首页金刚区的 ChannelScreen）
  Widget _buildAppGrid() {
    // v1.9.119：横向翻页（第 2 页露出游戏中心）+ 橙色滚动指示条（对齐真实淘宝）
    final apps = [
      ('芭芭农场', 'assets/icons/mine/cir_farm.png'),
      ('领淘金币', 'assets/icons/mine/cir_coin.png'),
      ('红包签到', 'assets/icons/mine/cir_redpacket.png'),
      ('连连消', 'assets/icons/mine/cir_lianlian.png'),
      ('试用领取', 'assets/icons/mine/cir_tryout.png'),
      ('游戏中心', 'assets/icons/mine/cir_game.png'),
    ];
    // 频道页入口沿用原 HomeIconEntry（图标在频道页内单独展示）
    HomeIconEntry entryOf(String title) {
      switch (title) {
        case '芭芭农场':
          return const HomeIconEntry(
              '芭芭农场', '领', 0xFFff4d4f, 'assets/images/icons/farm.png');
        case '领淘金币':
          return const HomeIconEntry(
              '领淘金币', '币', 0xFFf7b500, 'assets/images/icons/coin.png');
        case '红包签到':
          return const HomeIconEntry(
              '红包签到', '签', 0xFFff2d2d, 'assets/images/icons/redpacket.png');
        case '连连消':
          return const HomeIconEntry(
              '连连消', '消', 0xFFa855f7, 'assets/images/icons/lianlian.png');
        case '游戏中心':
          return const HomeIconEntry(
              '游戏中心', '游', 0xFFf97316, 'assets/images/icons/game.png');
        default:
          return const HomeIconEntry(
              '试用领取', 'U', 0xFFef4444, 'assets/images/icons/tryout.png');
      }
    }

    final itemWidth = (MediaQuery.of(context).size.width - 24) / 5;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 62,
            child: ListView.builder(
              controller: _circleCtrl,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: apps.length,
              itemBuilder: (_, i) {
                final a = apps[i];
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => ChannelScreen(entry: entryOf(a.$1))),
                  ),
                  child: SizedBox(
                    width: itemWidth,
                    child: Image.asset(a.$2, height: 58, fit: BoxFit.contain),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // 橙色滚动指示条（对齐真实淘宝：灰轨 + 橙拇指随滚动移动）
          SizedBox(
            width: 36,
            height: 4,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8E8E8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Positioned(
                  left: 18 * _circleRatio,
                  top: 0,
                  bottom: 0,
                  width: 18,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ 猜你喜欢 / 我的收藏 / 我的评价（三栏目切换） ============
  int _feedTab = 0;

  /// 猜你喜欢商品缓存（素材池随机，图+名对应）
  List<SearchResultItem>? _recPicks;
  String? _recSig;

  Widget _buildFeedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 栏目切换条（白底贴近上方卡片，选中橙色下划线）
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _feedTabItem(0, '猜你喜欢'),
              _feedTabItem(1, '我的收藏'),
              _feedTabItem(2, '我的评价', badge: 1),
            ],
          ),
        ),
        // 内容区（直接贴近栏目条，无间隔）
        if (_feedTab == 0) _buildGuessLike(),
        if (_feedTab == 1) _buildFavoritesFeed(),
        if (_feedTab == 2) _buildMyReviews(),
      ],
    );
  }

  Widget _feedTabItem(int index, String label, {int badge = 0}) {
    final selected = _feedTab == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _feedTab = index),
      child: Container(
        margin: const EdgeInsets.only(right: 24),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2.5,
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.black87 : const Color(0xFF666666),
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 3),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFff2d2d),
                  shape: BoxShape.circle,
                ),
                child: Text('$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 8)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============ 猜你喜欢（原"为你推荐"，商品推荐上提贴近栏目条） ============
  /// 「换一批」计数：变一次就重新随机一批素材
  int _recNonce = 0;

  Widget _buildGuessLike() {
    final pool = context.watch<MaterialPoolProvider>();
    final sig =
        '${pool.entries.length}/${pool.entries.where((e) => e.title.isNotEmpty).length}/$_recNonce';
    if (!pool.loading && (_recPicks == null || _recSig != sig)) {
      _recSig = sig;
      _recPicks = pool.recommendGoods(6 + Random().nextInt(3));
    }
    final picks = _recPicks ??
        (([...MockData.guessLikeGoods]..shuffle(Random()))
            .take(6)
            .toList());
    // 双列瀑布流（左右列各自撑内容高度，卡片底部不留白）
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < picks.length; i++) {
      (i.isEven ? left : right).add(_recommendCard(picks[i]));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (final w in left)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: w),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  children: [
                    for (final w in right)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: w),
                  ],
                ),
              ),
            ],
          ),
          // 「换一批」：单击重新随机一批素材池商品
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _recNonce++;
              _recPicks = null;
            }),
            child: Container(
              margin: const EdgeInsets.only(top: 2, bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFdddddd)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh,
                      size: 15, color: Color(0xFF666666)),
                  SizedBox(width: 4),
                  Text('换一批',
                      style: TextStyle(
                          fontSize: 13, color: Color(0xFF666666))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recommendCard(SearchResultItem item) {
    // 监听替换结果，点击图片可从相册换图
    final overrideUrl =
        context.watch<ProductImageProvider>().imageFor(item.title);
    final imageUrl = overrideUrl ?? item.imageUrl;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onDoubleTap: () => pickProductImageFromGallery(context, item.title),
            child: AppImage(url: imageUrl, width: double.infinity, height: 170),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(height: 4),
                Text('¥${item.price}',
                    style: const TextStyle(
                        color: Color(0xFFff5000),
                        fontSize: 15,
                        fontWeight: FontWeight.bold)),
                Text(item.shopName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF999999), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ 我的收藏（共用商品素材库，列表式） ============

  /// 确定性哈希（项目惯例：同一份素材每次展示一致）
  static int _hashOf(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  /// 收藏筛选行选中项（0有降价/1宝贝分类/2宝贝状态/3收藏时间）
  int _favFilter = 0;

  Widget _buildFavoritesFeed() {
    final pool = context.watch<MaterialPoolProvider>();
    final titled =
        pool.entries.where((e) => e.title.isNotEmpty).toList(growable: false);
    // 按选中的筛选项重排（确定性，同一份素材每次展示一致）
    final sorted = [...titled];
    switch (_favFilter) {
      case 0: // 有降价：降价宝贝排前面
        sorted.sort((a, b) =>
            (_hashOf(a.title) % 3).compareTo(_hashOf(b.title) % 3));
        break;
      case 1: // 宝贝分类：按品牌归类
        sorted.sort((a, b) => MaterialPoolProvider.brandOf(a.title)
            .compareTo(MaterialPoolProvider.brandOf(b.title)));
        break;
      case 2: // 宝贝状态：收藏人数多的在前
        sorted.sort((a, b) =>
            (_hashOf(b.title) % 200).compareTo(_hashOf(a.title) % 200));
        break;
      case 3: // 收藏时间：最近收藏在前（倒序）
        break; // 素材池本身即倒序，无需调整
    }
    return Column(
      children: [
        // 筛选行（可单击选中，选中橙色高亮并重排列表）
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _favFilterChip(0, '有降价'),
              _favFilterChip(1, '宝贝分类', arrow: true),
              _favFilterChip(2, '宝贝状态', arrow: true),
              _favFilterChip(3, '收藏时间', arrow: true),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (titled.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('素材库还没有命名的素材，双击「地址」去导入',
                  style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
            ),
          )
        else
          for (final e in sorted.take(10)) _favoriteRow(e),
      ],
    );
  }

  Widget _favFilterChip(int index, String label, {bool arrow = false}) {
    final selected = _favFilter == index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _favFilter = index),
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: 13,
                  color: selected ? AppColors.primary : Colors.black87,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                )),
            if (arrow)
              Icon(Icons.keyboard_arrow_down,
                  size: 14,
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFF999999)),
          ],
        ),
      ),
    );
  }

  /// 收藏条目：左图右文（标题/规格/淘金币抵/价格/店铺 + 降价提醒/找相似）
  Widget _favoriteRow(MaterialEntry e) {
    final h = _hashOf(e.title);
    // v1.9.116：优先抓包真实售价，没有再走品类估价
    // （旧版纯哈希随机最高 ¥300，与商品真实价差离谱）
    final priceText = MaterialPoolProvider.displayPriceOf(e);
    final collectors = 1 + h % 200;
    final coinBack = (h % 300) / 100 + 0.5;
    final shop =
        '${MaterialPoolProvider.brandOf(e.title)}海外旗舰店';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AppImage(url: e.imagePath, width: 92, height: 92),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('请选择规格',
                        style:
                            TextStyle(fontSize: 12, color: Color(0xFF999999))),
                    Icon(Icons.chevron_right,
                        size: 14, color: Color(0xFF999999)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    '淘金币抵${coinBack.toStringAsFixed(2)}元  $collectors人收藏',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFff8f00))),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('¥$priceText',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFff5000))),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(shop,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF999999))),
                              ),
                              const Icon(Icons.chevron_right,
                                  size: 12, color: Color(0xFF999999)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _favBtn('降价提醒'),
                    const SizedBox(width: 6),
                    _favBtn('找相似'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _favBtn(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFdddddd)),
        borderRadius: BorderRadius.circular(14),
      ),
      child:
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
    );
  }

  // ============ 我的评价（固定 4 条用户提供的素材） ============
  static const _myReviews = [
    (
      image: 'assets/images/reviews/coffee_box.jpg',
      text: '口感挺好的，不过还是期待瘦身效果！！',
      product: '防弹咖啡粉',
      user: '君君',
      likes: '1',
    ),
    (
      image: 'assets/images/reviews/return_question.jpg',
      text: '退货退款到底谁出运费？看完这篇就明白了',
      product: '',
      user: '爱买买买的喵',
      likes: '56',
    ),
    (
      image: 'assets/images/reviews/return_rate.jpg',
      text: '纯好奇！但是经常退货也不能完全怪买家吧',
      product: '',
      user: '小葵爸比',
      likes: '403',
    ),
    (
      image: 'assets/images/reviews/smart_socket.jpg',
      text: '太赞了，开始发的教程没有X99主板的，自己捣鼓了半天终于成功了',
      product: '智能遥控插座',
      user: '我卟是小白',
      likes: '17',
    ),
  ];

  Widget _buildMyReviews() {
    // 双列瀑布流（左右列高度自然错开）
    final left = <Widget>[];
    final right = <Widget>[];
    for (var i = 0; i < _myReviews.length; i++) {
      final card = _reviewCard(_myReviews[i]);
      (i.isEven ? left : right).add(card);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                for (final w in left)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10), child: w),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                for (final w in right)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 10), child: w),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(
      ({String image, String text, String product, String user, String likes})
          r) {
    return GestureDetector(
      onTap: () => _previewImage(r.image),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(url: r.image, width: double.infinity),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black87)),
                if (r.product.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(r.product,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF999999))),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 9,
                      backgroundColor: Color(0xFFffd180),
                      child: Icon(Icons.person,
                          size: 12, color: Colors.white),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(r.user,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF999999))),
                    ),
                    const Icon(Icons.favorite_border,
                        size: 14, color: Color(0xFF999999)),
                    if (r.likes.isNotEmpty)
                      Text(' ${r.likes}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF999999))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 评价图全屏预览（双指缩放，点击任意处关闭）
  void _previewImage(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dCtx) => GestureDetector(
        onTap: () => Navigator.pop(dCtx),
        child: Container(
          color: Colors.black,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(child: AppImage(url: url)),
          ),
        ),
      ),
    );
  }

  void _gotoOrder(String type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderListScreen(type: type)),
    );
  }
}

class _WalletItem {
  final String label;
  final String value;
  final Color color;
  _WalletItem(this.label, this.value, this.color);
}

/// v1.9.127 折纸三角瓣：白卡探出黑框上缘后，填补白卡顶缘与黑框顶缘凹槽的折角
/// 实测几何（16:01 真淘宝）：直角在右下，竖直直角边贴白卡左缘（高=探出量 6pt），
/// 水平直角边落在黑框顶缘上（宽 8pt），卡其色 #9E8D62（截图像素采样）
class _FoldCorner extends StatelessWidget {
  const _FoldCorner();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(8, 6),
      painter: _FoldCornerPainter(),
    );
  }
}

class _FoldCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF9E8D62);
    final path = Path()
      ..moveTo(size.width, 0) // 上右（白卡左上角顶点）
      ..lineTo(size.width, size.height) // 下右（直角，黑框顶缘与白卡左缘交点）
      ..lineTo(0, size.height) // 下左（黑框顶缘上）
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
