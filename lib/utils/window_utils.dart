import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// 检查是否为桌面平台
bool isDesktopPlatform() {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

/// 初始化桌面平台窗口
/// 在移动平台上调用此函数会立即返回，不会执行任何操作
Future<void> initDesktopWindow() async {
  // 非桌面平台直接返回，不会调用任何window_manager方法
  if (!isDesktopPlatform()) {
    return;
  }

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow();

  try {
    final display = await screenRetriever.getPrimaryDisplay();
    final visibleSize = display.visibleSize ?? display.size;
    final double screenHeight = visibleSize.height;
    final double screenWidth = visibleSize.width;

    double windowHeight = screenHeight;
    double windowWidth = windowHeight * 0.75;

    if (windowWidth > screenWidth) {
      windowWidth = screenWidth;
    }

    await windowManager.setSize(Size(windowWidth, windowHeight));
  } catch (e) {
    await windowManager.setSize(const Size(960, 720));
  }

  await windowManager.center();
  await windowManager.setMinimumSize(const Size(600, 400));
  await windowManager.show();
}
