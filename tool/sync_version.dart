import 'dart:io';

const String _configPath = 'tool/version_config.yaml';
const String _pubspecPath = 'pubspec.yaml';
const String _androidLocalPropertiesPath = 'android/local.properties';
const String _iosGeneratedXcconfigPath = 'ios/Flutter/Generated.xcconfig';
const String _iosExportEnvPath = 'ios/Flutter/flutter_export_environment.sh';
const String _generatedVersionInfoPath = 'lib/generated/version_info.g.dart';

Future<void> main() async {
  final Map<String, String> config = _readVersionConfig(_configPath);
  final String buildName = _requireBuildName(config['version']);
  final String buildNumber = _requireBuildNumber(config['build']);
  final String channel = _normalizeChannel(config['channel']);

  final String fullVersion = '$buildName+$buildNumber';
  final String displayVersion = _buildDisplayVersion(
    version: buildName,
    channel: channel,
  );
  final String displayVersionWithBuild = '$displayVersion build$buildNumber';

  final List<_SyncTarget> targets = <_SyncTarget>[
    _SyncTarget(
      path: _pubspecPath,
      required: true,
      updates: <_LineUpdate>[
        _LineUpdate(
          pattern: RegExp(r'^version:\s*.+$', multiLine: true),
          replacement: 'version: $fullVersion',
        ),
      ],
    ),
    _SyncTarget(
      path: _androidLocalPropertiesPath,
      updates: <_LineUpdate>[
        _LineUpdate(
          pattern: RegExp(r'^flutter\.versionName=.*$', multiLine: true),
          replacement: 'flutter.versionName=$buildName',
          appendIfMissing: true,
        ),
        _LineUpdate(
          pattern: RegExp(r'^flutter\.versionCode=.*$', multiLine: true),
          replacement: 'flutter.versionCode=$buildNumber',
          appendIfMissing: true,
        ),
      ],
    ),
    _SyncTarget(
      path: _iosGeneratedXcconfigPath,
      updates: <_LineUpdate>[
        _LineUpdate(
          pattern: RegExp(r'^FLUTTER_BUILD_NAME=.*$', multiLine: true),
          replacement: 'FLUTTER_BUILD_NAME=$buildName',
        ),
        _LineUpdate(
          pattern: RegExp(r'^FLUTTER_BUILD_NUMBER=.*$', multiLine: true),
          replacement: 'FLUTTER_BUILD_NUMBER=$buildNumber',
        ),
      ],
    ),
    _SyncTarget(
      path: _iosExportEnvPath,
      updates: <_LineUpdate>[
        _LineUpdate(
          pattern: RegExp(r'^export "FLUTTER_BUILD_NAME=.*"$', multiLine: true),
          replacement: 'export "FLUTTER_BUILD_NAME=$buildName"',
        ),
        _LineUpdate(
          pattern: RegExp(
            r'^export "FLUTTER_BUILD_NUMBER=.*"$',
            multiLine: true,
          ),
          replacement: 'export "FLUTTER_BUILD_NUMBER=$buildNumber"',
        ),
      ],
    ),
    _SyncTarget(
      path: _generatedVersionInfoPath,
      createIfMissing: true,
      overwriteEntireFile: true,
      generatedContent: _buildGeneratedVersionInfo(
        version: buildName,
        build: buildNumber,
        channel: channel,
        displayVersion: displayVersion,
        displayVersionWithBuild: displayVersionWithBuild,
      ),
    ),
  ];

  final List<String> logs = <String>[];
  bool hasError = false;

  for (final _SyncTarget target in targets) {
    final File file = File(target.path);
    if (!file.existsSync()) {
      if (target.createIfMissing) {
        _ensureParentDirectory(file);
        file.writeAsStringSync(target.generatedContent ?? '');
        logs.add('已生成：${target.path}');
        continue;
      }

      if (target.required) {
        logs.add('未找到必需文件：${target.path}');
        hasError = true;
      } else {
        logs.add('跳过（文件不存在）：${target.path}');
      }
      continue;
    }

    if (target.overwriteEntireFile) {
      final String original = file.readAsStringSync();
      final String next = target.generatedContent ?? '';
      if (original != next) {
        file.writeAsStringSync(next);
        logs.add('已更新：${target.path}');
      } else {
        logs.add('无需修改：${target.path}');
      }
      continue;
    }

    String original = file.readAsStringSync();
    final String lineEnding = original.contains('\r\n') ? '\r\n' : '\n';
    String content = original;
    bool changed = false;

    for (final _LineUpdate update in target.updates) {
      final bool matched = update.pattern.hasMatch(content);
      if (matched) {
        final String replaced = content.replaceFirst(
          update.pattern,
          update.replacement,
        );
        changed = changed || replaced != content;
        content = replaced;
        continue;
      }

      if (update.appendIfMissing) {
        if (content.isNotEmpty && !content.endsWith('\n')) {
          content += lineEnding;
        }
        content += update.replacement + lineEnding;
        changed = true;
        continue;
      }

      logs.add('未匹配到：${target.path} -> ${update.pattern.pattern}');
    }

    if (changed) {
      file.writeAsStringSync(content);
      logs.add('已更新：${target.path}');
    } else {
      logs.add('无需修改：${target.path}');
    }
  }

  stdout.writeln('平台版本：$fullVersion');
  stdout.writeln('展示版本：$displayVersionWithBuild');
  if (channel != 'stable') {
    stdout.writeln('说明：渠道标记不会写入 iOS/Android 真实版本号，只用于展示。');
  }
  for (final String log in logs) {
    stdout.writeln(log);
  }

  if (hasError) {
    exitCode = 1;
    return;
  }

  stdout.writeln('完成。现在可直接执行 flutter build 命令。');
}

Map<String, String> _readVersionConfig(String path) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw StateError('未找到版本配置文件：$path');
  }
  final List<String> lines = file.readAsLinesSync();
  final Map<String, String> result = <String, String>{};
  for (final String rawLine in lines) {
    final String line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final int index = line.indexOf(':');
    if (index <= 0) {
      continue;
    }
    final String key = line.substring(0, index).trim();
    final String value = line.substring(index + 1).trim();
    result[key] = value;
  }
  return result;
}

String _requireBuildName(String? value) {
  final String text = (value ?? '').trim();
  final RegExp pattern = RegExp(r'^\d+\.\d+\.\d+$');
  if (!pattern.hasMatch(text)) {
    throw StateError('version 必须是 x.y.z 形式，例如 1.0.2');
  }
  return text;
}

String _requireBuildNumber(String? value) {
  final String text = (value ?? '').trim();
  final int? number = int.tryParse(text);
  if (number == null || number <= 0) {
    throw StateError('build 必须是正整数，例如 1');
  }
  return '$number';
}

String _normalizeChannel(String? value) {
  final String text = (value ?? 'stable').trim();
  if (text.isEmpty) {
    return 'stable';
  }
  final RegExp pattern = RegExp(r'^[A-Za-z0-9._-]+$');
  if (!pattern.hasMatch(text)) {
    throw StateError('channel 只能包含字母、数字、点、下划线或短横线。');
  }
  return text;
}

String _buildDisplayVersion({
  required String version,
  required String channel,
}) {
  if (channel == 'stable') {
    return version;
  }
  return '$version.$channel';
}

String _buildGeneratedVersionInfo({
  required String version,
  required String build,
  required String channel,
  required String displayVersion,
  required String displayVersionWithBuild,
}) {
  final String safeChannel = _dartString(channel);
  final String safeVersion = _dartString(version);
  final String safeBuild = _dartString(build);
  final String safeDisplayVersion = _dartString(displayVersion);
  final String safeDisplayVersionWithBuild = _dartString(
    displayVersionWithBuild,
  );
  return '''
// GENERATED CODE - DO NOT EDIT BY HAND.
// Generated by `dart run tool/sync_version.dart`.

const String kAppVersion = '$safeVersion';
const String kAppBuildNumber = '$safeBuild';
const String kAppChannel = '$safeChannel';
const String kAppDisplayVersion = '$safeDisplayVersion';
const String kAppDisplayVersionWithBuild = '$safeDisplayVersionWithBuild';
const bool kAppIsStableChannel = kAppChannel == 'stable';
''';
}

String _dartString(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}

void _ensureParentDirectory(File file) {
  final Directory directory = file.parent;
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
}

class _SyncTarget {
  const _SyncTarget({
    required this.path,
    this.updates = const <_LineUpdate>[],
    this.required = false,
    this.createIfMissing = false,
    this.overwriteEntireFile = false,
    this.generatedContent,
  });

  final String path;
  final List<_LineUpdate> updates;
  final bool required;
  final bool createIfMissing;
  final bool overwriteEntireFile;
  final String? generatedContent;
}

class _LineUpdate {
  const _LineUpdate({
    required this.pattern,
    required this.replacement,
    this.appendIfMissing = false,
  });

  final RegExp pattern;
  final String replacement;
  final bool appendIfMissing;
}
