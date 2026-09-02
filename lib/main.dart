import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/banner_pool_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/material_pool_provider.dart';
import 'providers/product_image_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/search_provider.dart';

void main() {
  // 关键：让 widget build 阶段抛错时显示错误页而不是纯白屏（便于 HarmonyOS 等真机排错）
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _FatalErrorScreen(error: details.exceptionAsString());
  };
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    // Android 状态栏透明沉浸
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
    runApp(const TaobaoCloneApp());
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

class TaobaoCloneApp extends StatelessWidget {
  const TaobaoCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => SearchProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProductImageProvider()..load()),
        ChangeNotifierProvider(create: (_) => MaterialPoolProvider()..load()),
        ChangeNotifierProvider(create: (_) => BannerPoolProvider()..load()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: const AppRoot(),
    );
  }
}

/// 任何 widget build 报错时显示此页，方便真机查看错误信息
class _FatalErrorScreen extends StatelessWidget {
  final String error;
  const _FatalErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: const Color(0xFFFFE0E0),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('启动失败',
                      style: TextStyle(
                          color: Color(0xFFB71C1C),
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('请截图发给我（这是 widget build 抛错）',
                      style: TextStyle(color: Color(0xFF333333), fontSize: 14)),
                  const SizedBox(height: 16),
                  SelectableText(
                    error,
                    style: const TextStyle(
                        color: Color(0xFF222222), fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
