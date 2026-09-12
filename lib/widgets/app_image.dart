import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/remote_images.dart';
import '../utils/doc_paths.dart';

/// 通用图片组件：优先本地资源（离线可用），兜底网络图缓存
///
/// v1.9.102：
/// - 协议相对 URL（//img.alicdn.com/...）自动补 https:——旧版会被误判成
///   本地文件路径导致抓包商品图/头像大面积显示不出
/// - 阿里系图床（alicdn/tbcdn）带淘宝 Referer 请求头，绕防盗链
/// - 本地相对路径（order_images/xx.jpg 等）按当前沙盒 Documents 现场解析，
///   自签重装容器路径变化后依然能命中（配合 DocPaths.relativize 存储）
class AppImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  const AppImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  /// 阿里系图床域名：部分图无 Referer 会 403/跳转验证
  static bool _needsTaobaoReferer(String u) =>
      u.contains('alicdn.com') || u.contains('tbcdn.cn');

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder();
    }
    // 0. 协议相对 URL 补 https:（抓包数据常见形态，必须先于本地路径判断）
    var fixed = url;
    if (fixed.startsWith('//')) fixed = 'https:$fixed';
    // 1. 本地映射优先（已下载到 assets 的网络图）
    final local = remoteImageMap[fixed];
    if (local != null) {
      return Image.asset(local, width: width, height: height, fit: fit);
    }
    // 2. 显式本地资源
    if (fixed.startsWith('assets/')) {
      return Image.asset(fixed, width: width, height: height, fit: fit);
    }
    // 3. 网络图（带淘宝 Referer 防 403）
    if (fixed.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: fixed,
        httpHeaders: _needsTaobaoReferer(fixed)
            ? const {'Referer': 'https://www.taobao.com/'}
            : null,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    }
    // 4. 本地文件：相对路径按当前沙盒 Documents 解析（v1.9.102 持久化方案），
    //    绝对路径原样尝试（旧数据兼容）
    final path = DocPaths.resolve(fixed);
    return Image.file(File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFf0f0f0),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Color(0xFFc4c4c4)),
    );
  }
}
