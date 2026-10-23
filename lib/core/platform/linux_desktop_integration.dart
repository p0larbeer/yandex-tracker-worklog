import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Установка .desktop + иконки в ~/.local/share (Linux AppImage / desktop).
abstract final class LinuxDesktopIntegration {
  static bool get isSupported =>
      !kIsWeb && Platform.isLinux;

  static Future<String> install({
    required String appName,
    required String desktopId,
  }) async {
    if (!isSupported) {
      throw StateError('Только Linux');
    }
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) {
      throw StateError('Не найден HOME');
    }

    final exec = Platform.environment['APPIMAGE']?.trim().isNotEmpty == true
        ? Platform.environment['APPIMAGE']!
        : Platform.resolvedExecutable;

    final appsDir = Directory('$home/.local/share/applications');
    final iconsDir = Directory(
      '$home/.local/share/icons/hicolor/256x256/apps',
    );
    await appsDir.create(recursive: true);
    await iconsDir.create(recursive: true);

    final iconPath = '${iconsDir.path}/$desktopId.png';
    try {
      final data = await rootBundle.load('assets/branding/app_icon.png');
      await File(iconPath).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      // без иконки — всё равно ставим desktop
    }

    final desktopPath = '${appsDir.path}/$desktopId.desktop';
    final desktop = '''
[Desktop Entry]
Type=Application
Name=$appName
Comment=Desktop worklog client for Yandex Tracker
Exec="$exec"
Icon=$desktopId
Terminal=false
Categories=Office;Utility;
StartupWMClass=$desktopId
''';
    await File(desktopPath).writeAsString(desktop);

    try {
      await Process.run('update-desktop-database', [appsDir.path]);
    } catch (_) {}

    return desktopPath;
  }
}
