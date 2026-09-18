import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

bool get _isDesktop =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

Future<void> initializeDesktopWindow() async {
  if (!_isDesktop) return;
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1100, 700),
    minimumSize: Size(600, 500),
    center: true,
    title: 'SmartStock Inventory System',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> toggleFullscreen() async {
  if (!_isDesktop) return;
  final current = await windowManager.isFullScreen();
  await windowManager.setFullScreen(!current);
}

Future<void> exitFullscreen() async {
  if (!_isDesktop) return;
  if (await windowManager.isFullScreen()) {
    await windowManager.setFullScreen(false);
  }
}
