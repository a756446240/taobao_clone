import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/remote_images.dart';

/// 通用图片组件：优先本地资源（离线可用），兜底网络图缓存
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

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return _placeholder();
    }
    // 1. 本地映射优先（已下载到 assets 的网络图）
    final local = remoteImageMap[url];
    if (local != null) {
      return Image.asset(local, width: width, height: height, fit: fit);
    }
    // 2. 显式本地资源
    if (url.startsWith('assets/')) {
      return Image.asset(url, width: width, height: height, fit: fit);
    }
    // 2.5 本地文件路径（用户自定义替换的商品图）
    if (url.startsWith('/') ||
        url.startsWith('file:') ||
        RegExp(r'^[A-Za-z]:[/\\]').hasMatch(url)) {
      final path = url.startsWith('file:')
          ? url.substring(url.indexOf('file:') + 5).replaceFirst('//', '/')
          : url;
      return Image.file(File(path),
          width: width, height: height, fit: fit, errorBuilder: (_, __, ___) => _placeholder());
    }
    // 3. 兜底：网络图缓存
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => _placeholder(),
      errorWidget: (_, __, ___) => _placeholder(),
    );
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

