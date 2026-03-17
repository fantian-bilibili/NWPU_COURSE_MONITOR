# 构建与发布指南

本文档合并了原来的 Android 构建命令说明和多平台构建测试说明，作为当前仓库唯一的构建发布入口文档。

## 1. 版本同步

版本号采用单一配置源：

- `tool/version_config.yaml`

修改方式：

1. 打开 `tool/version_config.yaml`
2. 修改 `version`、`build`、`channel`
3. 执行同步脚本
4. 再执行对应平台的构建命令

字段说明：

- `version`：用户可见版本号，必须是 `x.y.z`
- `build`：内部构建号，必须是正整数；会同步到 Android `versionCode`、iOS `CFBundleVersion`、Flutter `version: x.y.z+build`
- `channel`：展示标记，例如 `preview / beta / rc1`，仅用于界面展示，不直接写入原生平台真实版本号

示例配置：

```yaml
version: 1.0.2
build: 2
channel: preview
```

执行同步：

```bash
dart run tool/sync_version.dart
```

脚本会同步到：

- `pubspec.yaml`
- `android/local.properties`
- `ios/Flutter/Generated.xcconfig`
- `ios/Flutter/flutter_export_environment.sh`
- `lib/generated/version_info.g.dart`

展示示例：

- `version: 1.0.2`
- `build: 2`
- `channel: preview`
- 界面展示版本：`1.0.2.preview build2`
- 平台实际构建版本：`1.0.2+2`

## 2. 通用准备

```bash
flutter pub get
flutter analyze
flutter test
```

如果这三步不过，不建议直接构建发布包。

## 3. Android

### 3.1 Debug 运行

```bash
flutter run -d android
```

### 3.2 Release APK

常规网络：

```bash
flutter build apk --release
```

网络受限时：

```bash
cmd /c "set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn&& flutter build apk --release"
```

### 3.3 产物位置

- `build/app/outputs/flutter-apk/app-release.apk`

### 3.4 Android 发布前检查

- 课程页能正常加载
- 教务导入可打开
- GPA 页面可展示
- 设置页可切换主题、修改作息
- 组件同步和提醒重建不报错

## 4. Windows

### 4.1 Debug 运行

```bash
flutter run -d windows
```

### 4.2 Release 构建

```bash
flutter build windows --release
```

### 4.3 产物位置

- 主程序：`build/windows/x64/runner/Release/nwpu_course_monitor.exe`
- 完整发布目录：`build/windows/x64/runner/Release/`

如果要上传 GitHub Releases，建议打包整个 `Release/` 目录，而不是只上传单个 exe。

建议压缩为：

- `nwpu_course_monitor-windows-x64-<version>.zip`

### 4.4 Windows 发布前检查

- 主窗口可打开
- 页面切换正常
- 导入导出正常
- GPA 页面正常
- 设置页正常
- 小窗模式可切换

## 5. iOS

必须在 macOS + Xcode 环境下进行。

### 5.1 环境要求

- macOS
- Xcode
- CocoaPods
- Apple Developer 签名

### 5.2 运行

```bash
flutter pub get
flutter devices
flutter run -d <ios_device_id>
```

### 5.3 Release

```bash
flutter build ipa
```

### 5.4 iOS 注意事项

- 提醒功能需要 iOS 通知权限
- 小组件需要额外添加 WidgetKit extension
- `home_widget` 的 iOS 侧扩展需与当前项目 widget kind 保持一致

## 6. OpenHarmony / HarmonyOS

不能直接使用 upstream stable Flutter。

### 6.1 前提

- OpenHarmony Flutter SDK / fork
- DevEco 或对应工具链
- `hdc`、`hvigorw`、`ohpm` 可用

### 6.2 说明

当前仓库保留 Flutter 侧主逻辑，但 Harmony 的实际构建流程依赖特定工具链，不在当前 Windows + stable Flutter 环境内完成。

## 7. 发布清单

建议每次发版至少确认以下项目：

1. 版本号已通过 `tool/version_config.yaml` 配置并同步
2. `flutter analyze` 通过
3. `flutter test` 通过
4. Android Release 包能安装
5. Windows Release 目录能独立启动
6. README 与 docs 已同步更新

## 8. 相关文档

- [文档总览](../README.md)
- [项目结构说明](../PROJECT_STRUCTURE.md)
