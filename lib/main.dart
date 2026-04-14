import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/book_service.dart';
import 'services/ai_service.dart';
import 'services/summary_service.dart';
import 'services/log_service.dart';
import 'services/parsers/format_registry.dart';
import 'services/parsers/epub_parser.dart';
import 'services/parsers/pdf_parser.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化日志服务（可选：启用文件日志）
  await LogService().init(
    minLevel: LogLevel.verbose, // 记录所有级别日志
    writeToFile: true, // 同时写入文件
  );

  LogService().info('Main', '应用启动');

  // 初始化格式注册表
  _initializeFormatRegistry();

  await BookService().init();
  await AIService().init();
  await SummaryService().init();

  LogService().info('Main', '所有服务初始化完成');

  runApp(
    const ZhiduApp(),
  );
}

/// 初始化格式注册表，注册所有支持的解析器
void _initializeFormatRegistry() {
  FormatRegistry.register('.epub', EpubParser());
  FormatRegistry.register('.pdf', PdfParser());
  LogService().info('Main', '格式注册表初始化完成，支持: epub, pdf');
}

class ZhiduApp extends StatelessWidget {
  const ZhiduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智读',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
