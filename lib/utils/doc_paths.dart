import 'package:path_provider/path_provider.dart';

/// 应用文档目录路径工具（v1.9.102）
///
/// 背景：iOS 自签重装后沙盒容器路径会变（/var/.../Application/<UUID>/Documents
/// 中的 UUID 变），所有把「绝对路径」持久化的图片（手动换的商品图/店铺头像/
/// 赠品图/消息头像/banner）在更新 IPA 后全部失效。
///
/// 方案：持久化时一律存「相对于 Documents 的路径」（如 order_images/xx.jpg），
/// 展示/读取时用当前沙盒根目录现场拼回绝对路径。这样无论容器怎么变都能命中。
class DocPaths {
  DocPaths._();

  /// 当前沙盒 Documents 根目录（main() 启动时初始化）
  static String root = '';

  /// 启动时调用一次（WidgetsFlutterBinding.ensureInitialized 之后）
  static Future<void> init() async {
    try {
      root = (await getApplicationDocumentsDirectory()).path;
    } catch (_) {
      root = '';
    }
  }

  /// 已知的图片子目录（历史数据迁移用：从旧绝对路径中抠出相对部分）
  static const knownSubdirs = [
    'order_images',
    'product_images',
    'shop_avatars',
    'gift_images',
    'message_avatars',
    'banner_materials',
    'materials',
    'profile_avatars',
    'profile_backgrounds',
  ];

  static bool isAbsolute(String p) =>
      p.startsWith('/') ||
      p.startsWith('file:') ||
      RegExp(r'^[A-Za-z]:[/\\]').hasMatch(p);

  /// 把任意路径转成「相对于 Documents」的存储形态：
  /// - 已经是相对路径 → 原样返回
  /// - 以当前 root 开头 → 剥掉前缀
  /// - 旧容器绝对路径（root 已变）→ 按已知子目录名抠出相对部分
  /// - 非本地路径（http/assets 等）→ 原样返回
  static String relativize(String path) {
    if (path.isEmpty) return path;
    if (path.startsWith('http') ||
        path.startsWith('//') ||
        path.startsWith('assets/')) {
      return path;
    }
    var p = path.replaceAll('\\', '/');
    if (p.startsWith('file://')) p = p.substring(7);
    if (p.startsWith('file:')) p = p.substring(5);
    if (root.isNotEmpty && p.startsWith(root)) {
      p = p.substring(root.length);
      if (p.startsWith('/')) p = p.substring(1);
      return p;
    }
    if (isAbsolute(p)) {
      for (final sub in knownSubdirs) {
        final idx = p.indexOf('/$sub/');
        if (idx >= 0) return p.substring(idx + 1);
      }
      // 不在已知子目录里的绝对路径没法安全迁移，原样返回
      return p;
    }
    return p;
  }

  /// 把存储形态解析成当前可用的绝对路径：
  /// - 相对路径 → 拼当前 root
  /// - 绝对路径 → 原样（旧数据兼容，文件在不在由调用方判断）
  static String resolve(String path) {
    if (path.isEmpty) return path;
    if (path.startsWith('http') ||
        path.startsWith('//') ||
        path.startsWith('assets/')) {
      return path;
    }
    var p = path.replaceAll('\\', '/');
    if (p.startsWith('file://')) p = p.substring(7);
    if (p.startsWith('file:')) p = p.substring(5);
    if (isAbsolute(p)) return p;
    if (root.isEmpty) return p;
    return '$root/$p';
  }
}
