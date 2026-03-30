# 构建与发布指南

本文档是当前仓库唯一的构建、版本同步与发布入口文档。

## 1. 版本同步

版本号采用单一配置源：`tool/version_config.yaml`

当前配置：

```yaml
version: 1.0.2
build: 4
channel: release
```

### 字段说明

- `version`
  - 用户可见版本号，必须是 `x.y.z`
- `build`
  - 内部构建号，必须是正整数
  - 会同步到：Android `versionCode`、iOS `CFBundleVersion`、Flutter `version: x.y.z+build`
- `channel`
  - 展示层渠道标记，例如：`preview`、`beta`、`release`、`develop`
  - 不会直接写入 Android / iOS 的真实平台版本号
  - 若希望界面仅显示纯数字版本，请使用 `stable`

### 修改步骤

1. 编辑 `tool/version_config.yaml`
2. 运行：

```bash
dart run tool/sync_version.dart
```

3. 确认以下文件已同步更新：
   - `pubspec.yaml`
   - `android/local.properties`
   - `ios/Flutter/Generated.xcconfig`
   - `ios/Flutter/flutter_export_environment.sh`
   - `lib/generated/version_info.g.dart`

### 当前展示与平台版本的区别

以当前配置为例：

- 展示版本：`1.0.2.release build4`
- 平台真实构建版本：`1.0.2+4`

## 2. 通用准备

在仓库根目录执行：

```bash
flutter pub get
flutter analyze
flutter test
```

## 3. Android

### 3.1 环境要求

- Flutter 3.41.x
- JDK 17
- Android SDK

### 3.2 Debug 运行

```bash
flutter run -d android
```

### 3.3 Release 构建

```bash
flutter build apk --release
```

如果当前网络环境访问 Flutter 依赖较慢：

```bash
cmd /c "set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn&& flutter build apk --release"
```

构建产物：`build/app/outputs/flutter-apk/app-release.apk`

### 3.4 Android 发布前检查

至少确认：

- 课表页能正常打开
- 学期切换正常
- 网课模块正常显示
- 教务课表导入可进入 WebView
- 教务成绩导入可进入 WebView
- Excel 成绩导入正常
- 设置页修改作息后不报错
- 提醒重建不报错
- 小组件同步不报错

## 4. Windows

### 4.1 环境要求

- Flutter 3.41.x
- Visual Studio C++ Desktop Workload

### 4.2 Debug 运行

```bash
flutter run -d windows
```

### 4.3 Release 构建

```bash
flutter build windows --release
```

### 4.4 构建产物

- 主程序：`build/windows/x64/runner/Release/nwpu_course_monitor.exe`
- 完整发布目录：`build/windows/x64/runner/Release/`

### 4.4 GitHub Release 打包建议

不要只上传单个 `exe`，建议压缩整个 `Release/` 目录。

建议命名：

- `nwpu_course_monitor-windows-x64-1.0.2.release-build4.zip`

### 4.5 Windows 发布前检查

至少确认：

- 主窗口可打开
- 四个主页面切换正常
- JSON / CSV / ICS / XLSX 导入导出正常
- 教务课表导入和成绩导入入口正常
- GPA 页面正常
- 设置页正常
- Windows 小窗模式可进入、可退出、可拖动
- 如果开启了开机自启动，确认模式与设置一致

## 5. iOS

必须在 `macOS + Xcode` 环境下进行。

### 5.1 环境要求

- macOS
- Xcode
- Flutter 3.41.x

### 5.2 构建

```bash
flutter build ipa
```

### 5.3 注意事项

- 提醒功能需要 iOS 通知权限
- 小组件需要额外添加 WidgetKit extension
- `home_widget` 的 iOS 扩展需要保持 widget kind 一致

## 6. OpenHarmony / HarmonyOS

标准 stable Flutter 不能直接完成当前 Harmony 构建。

### 前提

- OpenHarmony Flutter SDK / fork
- DevEco 或对应工具链
- `hdc`、`hvigorw`、`ohpm` 可用

### 说明

当前仓库保留了 Flutter 侧主逻辑，但 Harmony 的实际构建流程依赖特定工具链，不在当前 Windows + stable Flutter 环境内完成。

## 7. 调试与发布中的常见误判

### 7.1 Android 首次 Release 看起来像"卡住"

常见原因是依赖下载慢，不一定是真死锁，尤其是：

- `mergeReleaseNativeLibs`
- Flutter embedding / native libs 下载阶段

优先做法：

1. 先等待并观察网络
2. 使用国内镜像命令重试
3. 不要把上一次生成的旧 `app-release.apk` 当作本次成功产物

### 7.2 Debug 卡顿不等于 Release 卡顿

- Debug 的内存、动画和帧率表现不代表 Release
- 涉及 UI 卡顿、Windows 小窗渲染问题时，优先补一次 Release 验证

## 8. 发布清单

每次发版至少确认以下项目：

1. `tool/version_config.yaml` 已更新
2. 已运行 `dart run tool/sync_version.dart`
3. `flutter analyze` 通过
4. `flutter test` 通过
5. Android Release 包可安装
6. Windows Release 目录可独立启动
7. README、`docs/`、`agent_handoff/` 已同步更新
8. 若改动导入解析器，已有新的样本或验证记录

## 9. 相关文档

- [根 README](../../README.md)
- [文档总览](../README.md)
- [项目结构说明](../PROJECT_STRUCTURE.md)
- [上游参考与归因](../UPSTREAM_ATTRIBUTION.md)
