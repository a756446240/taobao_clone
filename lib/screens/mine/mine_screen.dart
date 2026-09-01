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
import '../../providers/material_pool_provider.dart';
import '../../providers/product_image_provider.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/app_image.dart';
import '../../widgets/dialog_helpers.dart';
import '../../widgets/image_picker_helper.dart';
import '../order/logistics_screen.dart';
import '../order/order_list_screen.dart';
import 'ai_order_audit_screen.dart';
import 'ai_order_import_screen.dart';
import 'benefits_screen.dart';
import 'coupon_center_screen.dart';
import 'favorites_screen.dart';
import 'followed_shops_screen.dart';
import 'footprints_screen.dart';
import 'settings_screen.dart';
import 'material_pool_screen.dart';
import 'profile_edit_screen.dart';

/// 我的页（1:1 复刻新版淘宝）
/// 头像/顶部背景图可直接从手机相册选择，所有资料改动持久化保存。
class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
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
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          _buildTopCards(),
          _buildWalletBar(),
          _buildRedPacketBanner(),
          _buildOrderSection(),
          _buildToolCards(),
          _buildCouponCards(),
          _buildAppGrid(),
          _buildRecommendSection(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ============ 顶部个人信息 ============
  Widget _buildHeader() {
    final profile = context.watch<ProfileProvider>();
    final hasBg = profile.headerBg.isNotEmpty;
    return Stack(
      children: [
        // 可换的顶部背景图（双击从相册选）
        Positioned.fill(
          child: GestureDetector(
            onDoubleTap: _pickHeaderBg,
            child: Container(
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
            ),
          ),
        ),
        Container(
          color: hasBg ? Colors.black.withOpacity(0.15) : Colors.transparent,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                GestureDetector(
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
                        onDoubleTap: _gotoEdit,
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
                            onDoubleTap: _gotoEdit,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_outlined,
                                    size: 12, color: Colors.black54),
                                const SizedBox(width: 2),
                                Text(
                                  profile.slogan.isEmpty ? '关注店铺' : profile.slogan,
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 素材库：UI 伪装成"地址"，双击进入（编辑入口双击规则）
                GestureDetector(
                  onDoubleTap: _gotoMaterialPool,
                  child: _headerIcon(Icons.location_on_outlined, '地址'),
                ),
                const SizedBox(width: 16),
                _headerIcon(Icons.headset_mic_outlined, '官方客服'),
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
      ],
    );
  }

  Widget _vipTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF8d6e63),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(text,
          style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }

  Widget _levelTag(String level) {
    // 避免和 88VIP 重复显示
    final display = level == '88VIP' ? '钻石会员' : level;
    return GestureDetector(
      onDoubleTap: _pickLevel,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFF5d4037),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(display,
            style: const TextStyle(color: Colors.white, fontSize: 10)),
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

  /// "地址"按钮 → 商品素材库（导入素材图，打开 App 时随机展示）
  void _gotoMaterialPool() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MaterialPoolScreen()),
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

  // ============ 顶部深金会员卡（本月已省 / 会员中心 / 88VIP / 1元可兑） ============
  Widget _buildTopCards() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 本月已省 1296 元
          const Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '本月已省',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: '1296',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: '元',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ]),
          ),
          const SizedBox(width: 16),
          // 会员中心
          Expanded(child: _memberColumn('会员中心', '免费权益天天领')),
          // 88VIP
          _memberColumn('88VIP', '积分兑换'),
          const SizedBox(width: 10),
          // 1元可兑
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE8C37E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('1元',
                    style: TextStyle(
                        color: Color(0xFF2A1E0C),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Text('可兑',
                    style: TextStyle(
                        color: Color(0xFF2A1E0C),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberColumn(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: Colors.white,
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
                      color: Color(0xFFD9BE8A), fontSize: 11)),
            ),
            const Icon(Icons.chevron_right,
                size: 12, color: Color(0xFFD9BE8A)),
          ],
        ),
      ],
    );
  }

  // ============ 红包/优惠券/积分 整合区（对齐 image#6） ============
  Widget _buildWalletBar() {
    final items = [
      _WalletItem('红包', '领红包', Colors.red),
      _WalletItem('优惠券', '领优惠', const Color(0xFFff7043)),
      _WalletItem('淘金币抵', '¥1.30', const Color(0xFFff8f00)),
      _WalletItem('天猫积分', '5', const Color(0xFFff5252)),
      _WalletItem('充值金', '¥0.00', const Color(0xFF8d6e63)),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          ...items.asMap().entries.expand((e) {
            final w = Expanded(
              child: GestureDetector(
                // 单击进入权益钱包页对应标签
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          BenefitsScreen(initialIndex: e.key)),
                ),
                child: Column(
                  children: [
                    Text(e.value.label,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF666666))),
                    const SizedBox(height: 4),
                    Text(e.value.value,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: e.value.color)),
                  ],
                ),
              ),
            );
            if (e.key == items.length - 1) return [w];
            return [
              w,
              Container(width: 1, height: 24, color: const Color(0xFFeeeeee)),
            ];
          }).toList(),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BenefitsScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.only(left: 6, right: 4),
              child: const Column(
                children: [
                  Text('全部权益',
                      style: TextStyle(fontSize: 12, color: Color(0xFF666666))),
                  SizedBox(height: 4),
                  Icon(Icons.chevron_right, size: 16, color: Color(0xFF999999)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ 领红包 Banner（单击进入红包权益页）============
  Widget _buildRedPacketBanner() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BenefitsScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1E0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.red, size: 18),
            SizedBox(width: 6),
            Expanded(
              child: Text('点击领取今日红包，限时发放错过可惜',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8d4a1f))),
            ),
            Text('去领取',
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // ============ 我的订单 ============
  Widget _buildOrderSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
              _orderItem('待付款'),
              _orderItem('待发货'),
              _orderItem('待收货'),
              _orderItem('待评价'),
              _orderItem('退款/售后'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderItem(String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _gotoOrder(label),
        child: Column(
          children: [
            _orderIcon(label),
            const SizedBox(height: 6),
            Text(label, style: AppTextStyles.small),
          ],
        ),
      ),
    );
  }

  Widget _orderIcon(String label) {
    IconData icon;
    switch (label) {
      case '待付款':
        icon = Icons.account_balance_wallet_outlined;
        break;
      case '待发货':
        icon = Icons.inventory_2_outlined;
        break;
      case '待收货':
        icon = Icons.local_shipping_outlined;
        break;
      case '待评价':
        icon = Icons.rate_review_outlined;
        break;
      default:
        icon = Icons.assignment_return_outlined;
    }
    return Icon(icon, color: AppColors.primary, size: 28);
  }

  // ============ 工具卡片 ============
  Widget _buildToolCards() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _toolIcon(Icons.local_shipping_outlined, '快递', '暂无在途包裹',
              onTap: _openLogistics),
          _toolIcon(Icons.star_border, '收藏的宝贝', '逛逛多宝贝',
              onTap: _openFavorites),
          _toolIcon(Icons.storefront_outlined, '关注店铺', '看店铺动态',
              onTap: _openFollowedShops, onDoubleTap: _openAiAudit),
          _toolIcon(Icons.access_time, '足迹', '看过的内容',
              onTap: _openFootprints, onDoubleTap: _openAiImport),
        ],
      ),
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

  /// 单击"快递" → 物流详情
  void _openLogistics() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogisticsScreen()),
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
      MaterialPageRoute(builder: (_) => const SettingsScreen(version: '1.8.7')),
    );
  }

  Widget _toolIcon(IconData icon, String title, String subtitle,
      {VoidCallback? onTap, VoidCallback? onDoubleTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 6),
            Text(title, style: AppTextStyles.small),
            Text(subtitle,
                style: const TextStyle(color: Color(0xFF999999), fontSize: 10)),
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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              _bigCoupon('¥61', '消费券',
                  bg: const Color(0xFFFFF1E8),
                  fg: const Color(0xFFFF5000)),
              const SizedBox(width: 8),
              _bigCoupon('¥10', '超市加补券',
                  bg: const Color(0xFFE8F8EE),
                  fg: const Color(0xFF12A150)),
              const SizedBox(width: 8),
              _bigCoupon('¥50', '珠宝加补券',
                  bg: const Color(0xFFF3EBFF),
                  fg: const Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              _bigCoupon('¥45', '玩具加补券',
                  bg: const Color(0xFFE8F1FF),
                  fg: const Color(0xFF2B6DEF)),
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
  Widget _buildAppGrid() {
    final apps = [
      {'label': '芭芭农场', 'asset': 'assets/images/icons/farm.png'},
      {'label': '领淘金币', 'asset': 'assets/images/icons/coin.png'},
      {'label': '红包签到', 'asset': 'assets/images/icons/redpacket.png'},
      {'label': '游戏中心', 'asset': 'assets/images/icons/game.png'},
      {'label': '连连消', 'asset': 'assets/images/icons/lianlian.png'},
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: apps.map((a) => Expanded(
          child: Column(
            children: [
              Image.asset(a['asset']!, width: 48, height: 48),
              const SizedBox(height: 6),
              Text(a['label']!, style: AppTextStyles.min),
            ],
          ),
        )).toList(),
      ),
    );
  }

  // ============ 推荐商品（素材池随机，图+名对应） ============
  List<SearchResultItem>? _recPicks;
  String? _recSig;

  Widget _buildRecommendSection() {
    final pool = context.watch<MaterialPoolProvider>();
    final sig =
        '${pool.entries.length}/${pool.entries.where((e) => e.title.isNotEmpty).length}';
    if (!pool.loading && (_recPicks == null || _recSig != sig)) {
      _recSig = sig;
      _recPicks = pool.recommendGoods(6 + Random().nextInt(3));
    }
    final picks = _recPicks ??
        (([...MockData.guessLikeGoods]..shuffle(Random()))
            .take(6)
            .toList());
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('为你推荐',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
              GestureDetector(
                onTap: () {},
                child: const Text('更多 >',
                    style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.58,
            ),
            itemCount: picks.length,
            itemBuilder: (_, i) => _recommendCard(picks[i]),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onDoubleTap: () => pickProductImageFromGallery(context, item.title),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child:
                AppImage(url: imageUrl, width: double.infinity, height: 170),
          ),
        ),
        const SizedBox(height: 8),
        Text(item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 4),
        Text('¥${item.price}',
            style: const TextStyle(
                color: Color(0xFFff5000),
                fontSize: 15,
                fontWeight: FontWeight.bold)),
        Text(item.shopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF999999), fontSize: 10)),
      ],
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
