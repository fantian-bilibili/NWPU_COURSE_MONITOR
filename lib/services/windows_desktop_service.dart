import 'dart:io';

import 'package:flutter/services.dart';

class WindowsDesktopService {
  static const MethodChannel _channel = MethodChannel(
    'nwpu_course_monitor/windows_desktop',
  );

  Future<bool> setMiniWindowMode(bool enabled) async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final bool? applied = await _channel.invokeMethod<bool>(
        'setMiniWindowMode',
        <String, dynamic>{'enabled': enabled},
      );
      return applied ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> getMiniWindowMode() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final bool? value = await _channel.invokeMethod<bool>(
        'getMiniWindowMode',
      );
      return value ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setAutoStart(bool enabled, {bool startMiniMode = false}) async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final bool? applied = await _channel.invokeMethod<bool>(
        'setAutoStart',
        <String, dynamic>{'enabled': enabled, 'startMini': startMiniMode},
      );
      return applied ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> getAutoStart() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final bool? value = await _channel.invokeMethod<bool>('getAutoStart');
      return value ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> startWindowDrag() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final bool? started = await _channel.invokeMethod<bool>(
        'startWindowDrag',
      );
      return started ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> launchMiniWindowProcess() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final bool? launched = await _channel.invokeMethod<bool>(
        'launchMiniWindowProcess',
      );
      return launched ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> launchMainWindowProcess() async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final bool? launched = await _channel.invokeMethod<bool>(
        'launchMainWindowProcess',
      );
      return launched ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<bool> setMiniWindowDark(bool dark) async {
    if (!Platform.isWindows) {
      return false;
    }
    try {
      final bool? applied = await _channel.invokeMethod<bool>(
        'setMiniWindowDark',
        <String, dynamic>{'enabled': dark},
      );
      return applied ?? false;
    } on PlatformException {
      return false;
    }
  }

  // Backward compatibility entrypoint.
  Future<bool> setDesktopPinned(bool enabled) async {
    return setMiniWindowMode(enabled);
  }

  // Backward compatibility entrypoint.
  Future<bool> getDesktopPinned() async {
    return getMiniWindowMode();
  }
}
