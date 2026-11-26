import 'package:flutter/material.dart';
import 'package:zhidu/l10n/app_localizations.dart';

/// 构建带中文本地化配置的 MaterialApp，供 Widget 测试使用。
///
/// 测试中的屏幕大多调用 `AppLocalizations.of(context)!`，且断言中文文案，
/// 因此需要显式指定 localizations delegates 与 `zh` locale。
Widget buildTestApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('zh', 'CN'),
    home: home,
  );
}
