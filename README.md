# NWPU Course Monitor 课程管家
*旨在让瓜大学子摆脱天天崩溃的神秘蓝色软件*


[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Version: v1.0.2--develop](https://img.shields.io/badge/Version-v1.0.2--develop-blue.svg)](https://github.com/fantian-bilibili/NWPU_COURSE_MONITOR/releases)

NWPU Course Monitor 是一款基于 Flutter 的多端课程表与成绩管理应用，面向西北工业大学课程导入、学期管理、成绩绑定、提醒通知和桌面/桌面组件展示场景。

## AI协作开发声明

当前仓库的开发过程中部分使用了`GPT-5.3-CODEX`以及`GPT-5.4`模型进行代码生成、优化和问题排查。

## 功能与特色

这是一个轻量、跨平台的课程表和成绩管理工具，拥有现代化的UI设计和完整实用的课程表与学分绩管理功能。

- 简洁美观的动效与UI界面
  - 在开发过程中，我们注重各位同学的体验，设计了简洁美观的界面，并加入了流畅的动效，达成和谐美观的视觉效果。
- 课程表功能
  - 支持日列表、周列表、周视图三种模式，满足不同同学的使用习惯。
  - 课程详情折叠展示，方便查看课程信息。
  - 支持手动新增、编辑、删除课程，灵活管理课程表。
- 学期管理
  - 支持新建、切换、编辑学期，课程与成绩按学期独立存储，方便管理不同学期的课程和成绩。
- 教务导入
    - 移动端内置 WebView 导入，兼容翱翔教务系统页面解析逻辑。
    - 支持课程表页面一键导入，也支持成绩页面一键提取后导入。
    - 支持提取后的 payload / HTML 快照导入。
- 成绩与 GPA
  - 支持 Excel 成绩单导入与教务成绩页导入。
  - 课程可绑定绩点，自动计算当前学分绩与已计入学分。
  - 支持 P / NP 成绩，不参与 GPA 计算但计入已出分课程统计。
- 导入导出
    - 支持当前学期的 JSON / CSV 导出，以及全部学期的 JSON 导出，方便备份和迁移数据。
- 提醒功能
    - 依据每节课时间生成上课前通知，提前分钟数可配置，帮助同学们准时上课。
- 桌面组件 / 小组件
    - Android 今日课程组件，Windows 小窗模式，方便在桌面上查看课程信息。

## 平台支持
目前 NWPU Course Monitor 已对Android和Windows平台进行了适配和验证，同时保留了iOS、Web和OpenHarmony方向的适配入口，未来将继续完善这些平台的支持，目前OpenHarmony 端的适配开发已经开始。

## 快速开始

### 1. 环境要求

- Flutter 3.41.x
- Dart 3.11.x
- JDK 17

### 2. 安装依赖

```bash
flutter pub get
```

### 3. 静态检查与测试

```bash
flutter analyze
flutter test
```

### 4. 本地运行

```bash
flutter run -d android
flutter run -d windows
```

## 版本号管理

版本号采用单一配置源：

- 配置文件：`tool/version_config.yaml`
- 同步脚本：`tool/sync_version.dart`

操作步骤：

1. 修改 `tool/version_config.yaml`
2. 执行同步脚本
3. 再执行 `flutter build ...`

配置含义：

- `version`：面向用户显示的语义化版本号，固定使用 `x.y.z`
- `build`：内部构建号，会同步到 Android `versionCode`、iOS `CFBundleVersion`，以及 Flutter 的 `x.y.z+build`
- `channel`：展示层标记，例如 `preview / beta / rc1`，不会直接写进原生平台真实版本号

示例：

```yaml
version: 1.0.2
build: 2
channel: preview
```

然后执行：

```bash
dart run tool/sync_version.dart
```

脚本会同步到：

- `pubspec.yaml`
- `android/local.properties`
- `ios/Flutter/Generated.xcconfig`
- `ios/Flutter/flutter_export_environment.sh`
- `lib/generated/version_info.g.dart`

展示版本会显示为 `1.0.2.preview build2`，但平台实际构建版本仍保持兼容格式。

## 构建发布

Android Release：

```bash
flutter build apk --release
```

如果网络受限，可使用：

```bash
cmd /c "set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn&& flutter build apk --release"
```

Windows Release：

```bash
flutter build windows --release
```

更完整的构建、测试、发布说明见：

- [构建与发布指南](docs/build/BUILD_AND_RELEASE.md)

## 项目结构

```text
NWPU_COURSE_MONITOR/
├─ android/                      Android 原生工程与小组件实现
├─ ios/                          iOS 原生工程
├─ lib/
│  ├─ app/                       页面、应用壳层、通用组件
│  ├─ generated/                 生成文件（例如版本信息）
│  ├─ models/                    领域模型与时间/成绩工具函数
│  ├─ services/                  存储、导入导出、通知、桌面能力封装
│  ├─ state/                     AppState，全局状态与业务编排
│  └─ main.dart                  组合根与应用入口
├─ tool/                         版本同步等辅助脚本
├─ web/                          Web 入口资源
├─ windows/                      Windows runner 与原生小窗实现
├─ docs/                         面向开发者的人类文档
└─ agent_handoff/                面向 AI 工作空间迁移的本地文档（Git 忽略）
```

更详细的模块说明见：

- [项目结构说明](docs/PROJECT_STRUCTURE.md)

## 文档索引

- [文档总览](docs/README.md)
- [项目结构说明](docs/PROJECT_STRUCTURE.md)
- [构建与发布指南](docs/build/BUILD_AND_RELEASE.md)
- [上游参考与致谢](docs/UPSTREAM_ATTRIBUTION.md)

## 参考来源

当前教务导入逻辑参考了 NWPU 场景的开源实现：

- `docs/references/soaring-schedule/`

这些文件仅作为解析流程和页面交互参考，不直接参与 Flutter 运行。
