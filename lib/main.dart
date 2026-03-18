
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/home_screen.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: ZhiduApp(),
    ),
  );
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