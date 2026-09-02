import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/models.dart';
import '../../providers/cart_provider.dart';
import '../../providers/reviews_provider.dart';
import '../../widgets/app_image.dart';

/// 淘宝式发表评价页：店铺头 + 商品行 + 三项星级 + 文字 + 图片 + 匿名开关
class RateOrderScreen extends StatefulWidget {
  final ShoppingCartShop shop;
  final OrderItem item;

  const RateOrderScreen({super.key, required this.shop, required this.item});

  @override
  State<RateOrderScreen> createState() => _RateOrderScreenState();
}

class _RateOrderScreenState extends State<RateOrderScreen> {
  final TextEditingController _reviewCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _photos = [];

  /// 描述相符 / 物流服务 / 服务态度
  final Map<String, int> _ratings = {'描述相符': 5, '物流服务': 5, '服务态度': 5};
  bool _anonymous = true;

  static const _starLabels = ['非常差', '差', '一般', '好', '非常好'];

  Future<void> _pickPhotos() async {
    final remain = 6 - _photos.length;
    if (remain <= 0) return;
    final files = await _picker.pickMultiImage();
    if (files.isEmpty) return;
    setState(() {
      _photos.addAll(files.take(remain));
    });
  }

  /// 把相册临时路径的照片复制到 App 文档目录，防止缓存被系统清理后晒图丢失
  Future<List<String>> _persistPhotos() async {
    if (_photos.isEmpty) return const [];
    final dir = await getApplicationDocumentsDirectory();
    final saveDir = Directory('${dir.path}/review_photos');
    if (!saveDir.existsSync()) saveDir.createSync(recursive: true);
    final saved = <String>[];
    for (final f in _photos) {
      try {
        final ext = f.path.contains('.')
            ? f.path.substring(f.path.lastIndexOf('.'))
            : '.jpg';
        final name =
            'review_${DateTime.now().millisecondsSinceEpoch}_${saved.length}$ext';
        final copied = await File(f.path).copy('${saveDir.path}/$name');
        saved.add(copied.path);
      } catch (_) {}
    }
    return saved;
  }

  Future<void> _publish() async {
    final text = _reviewCtrl.text.trim();
    if (text.isEmpty && _photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('写点内容或晒张图再发布吧～'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final photos = await _persistPhotos();
    if (!mounted) return;
    // 三项星级取平均（四舍五入）
    final avg = (_ratings.values.reduce((a, b) => a + b) / _ratings.length);
    context.read<ReviewsProvider>().add(UserReview(
          productTitle: widget.item.title,
          shopName: widget.shop.shopName,
          content: text.isEmpty ? '此用户没有填写文字评价' : text,
          stars: avg.round().clamp(1, 5),
          spec: widget.item.configuration,
          photoPaths: photos,
          anonymous: _anonymous,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
    // 订单移出「待评价」→ 交易成功
    context.read<CartProvider>().markRated(widget.shop, widget.item);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('评价发布成功，感谢分享！'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('发表评价',
            style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          _buildShopHeader(),
          _buildProductCard(),
          const SizedBox(height: 8),
          _buildRatingCard(),
          const SizedBox(height: 8),
          _buildReviewCard(),
        ],
      ),
      bottomSheet: _buildPublishBar(),
    );
  }

  /// 店铺头
  Widget _buildShopHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          const Icon(Icons.storefront_outlined,
              color: Colors.black87, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(widget.shop.shopName,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          if (widget.shop.shopType == ShopType.tianMao) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(3),
              ),
              child: const Text('天猫',
                  style: TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ],
        ],
      ),
    );
  }

  /// 商品行
  Widget _buildProductCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 56,
              height: 56,
              child: AppImage(url: widget.item.imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  /// 三项星级评分
  Widget _buildRatingCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          for (final entry in _ratings.entries.toList()) _ratingRow(entry.key),
        ],
      ),
    );
  }

  Widget _ratingRow(String label) {
    final value = _ratings[label]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTap: () => setState(() => _ratings[label] = i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Icon(
                  i <= value ? Icons.star : Icons.star_border,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
            ),
          const Spacer(),
          Text(_starLabels[value - 1],
              style: const TextStyle(color: AppColors.primary, fontSize: 12)),
        ],
      ),
    );
  }

  /// 评价文字 + 图片 + 匿名开关
  Widget _buildReviewCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _reviewCtrl,
            maxLines: 5,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: '分享你的使用心得，帮助其他小伙伴～',
              hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
              border: InputBorder.none,
              counterStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 10),
            ),
          ),
          const SizedBox(height: 4),
          _buildPhotoGrid(),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('匿名评价',
                    style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
              ),
              Switch(
                value: _anonymous,
                activeTrackColor: AppColors.primary,
                onChanged: (v) => setState(() => _anonymous = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _photos.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.file(
                  File(_photos[i].path),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: () => setState(() => _photos.removeAt(i)),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.only(
                          topRight: Radius.circular(6),
                          bottomLeft: Radius.circular(6)),
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 12),
                  ),
                ),
              ),
            ],
          ),
        if (_photos.length < 6)
          GestureDetector(
            onTap: _pickPhotos,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: Color(0xFF999999), size: 22),
                  SizedBox(height: 3),
                  Text('晒图',
                      style:
                          TextStyle(color: Color(0xFF999999), fontSize: 10)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 底部发布栏
  Widget _buildPublishBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: SafeArea(
        child: GestureDetector(
          onTap: _publish,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF5000), Color(0xFFFF7A33)],
              ),
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Text('发布评价',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}
