# NWPU Course Monitor 课程管家

旨在让西工大学生更稳定地管理课表、成绩、提醒与桌面展示。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Version: v1.0.2.release%20build4](https://img.shields.io/badge/Version-v1.0.2.release%20build4-blue.svg)](https://github.com/fantian-bilibili/NWPU_COURSE_MONITOR/releases)

NWPU Course Monitor 是一个基于 Flutter 的多端课程表与成绩管理应用，当前主要围绕西北工业大学教务场景开发。它支持按学期管理课程与成绩，支持教务系统一键导入课表和成绩，支持 Excel / JSON / CSV / ICS 文件导入导出，并提供提醒通知、Android 小组件和 Windows 小窗模式。

## 当前状态

- 当前源码版本：`1.0.2+4`
- 当前展示版本：`1.0.2.release build4`
- 当前版本配置源：`tool/version_config.yaml`
- 当前重点验证平台：Android、Windows
- 当前保留适配入口的平台：iOS、Web、OpenHarmony

## 核心功能

### 1. 课表

- 支持 `日列表`、`周列表`、`周视图` 三种查看模式。
- 支持手动新增、编辑、删除课程。
- 课程详情采用折叠式展示，常用信息与详细信息分层显示。
- 冲突课程在周视图中会按并发数量横向分栏，而不是互相覆盖。

### 2. 网课

- 教务导入会识别 `在线开放课程 / 网课 / 不排课` 等课程。
- 网课不会进入日列表、周列表、周视图。
- 网课会在课表页独立模块中展示，并允许绑定成绩。

### 3. 学期管理

- 支持新建、切换、编辑、删除学期。
- 每个学期独立保存：课程、成绩、学期首周周一。
- 切换学期后，课表、成绩、提醒和组件数据会一起切换。

### 4. 教务导入

- 移动端内置 WebView 导入。
- 支持 `课表页面一键导入`。
- 支持 `成绩页面一键提取并导入`。
- 课表导入会优先合并 `页面 HTML` 与 `页面 payload`，减少漏掉网课和特殊课程的概率。
- 当前导入逻辑参考 `docs/references/soaring-schedule/` 中的 NWPU 场景实现，并结合本项目数据模型做了改写。

### 5. 文件导入导出

- 当前学期导入：JSON、CSV、ICS。
- 成绩导入：XLSX、教务成绩页 HTML 提取。
- 导出：当前学期 JSON、当前学期 CSV、全部学期 JSON。
- JSON 导出可选携带作息与提醒设置，方便整机迁移。

### 6. 成绩与 GPA

- 支持课程与成绩绑定。
- 支持自动计算：当前学分绩、已计入学分、加权均分。
- 支持 `P / NP` 成绩：计入"已出分课程"统计、不参与 GPA 计算。
- 成绩导入时会按 `课程代码 -> 课程名称` 双重匹配已有课程；匹配不到的成绩会跳过并给出提示。

### 7. 提醒与作息

- 支持配置每节课的上课时间与下课时间。
- 支持配置提前提醒分钟数。
- 修改作息后会重建提醒计划。

### 8. 小组件与桌面模式

- Android：提供今日课程小组件。
- Windows：提供独立小窗模式，可在完整模式与小窗模式之间切换。
- Windows 小窗模式使用独立窗口流程，避免完整窗口和小窗状态耦合。

## 平台支持情况

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| Android | 已重点适配 | 教务导入、提醒、小组件、导入导出为主要验证路径 |
| Windows | 已重点适配 | 完整客户端 + 小窗模式可用 |
| iOS | Flutter 侧保留入口 | 真机编译与 WidgetKit 扩展仍需要 macOS / Xcode 环境补齐 |
| Web | 基础入口保留 | 不是当前主要交付目标 |
| OpenHarmony | 预留方向 | 需要特定 Flutter fork/toolchain，不在标准 stable Flutter 环境内完成 |

## 快速开始

### 环境要求

- Flutter `3.41.x`
- Dart `3.11.x`
- JDK `17`
- Windows 构建需要 Visual Studio C++ Desktop Workload

### 安装依赖

```bash
flutter pub get
```

### 静态检查与测试

```bash
flutter analyze
flutter test
```

### 本地运行

```bash
flutter run -d android
flutter run -d windows
```

## 版本号与 Build 号管理

版本号采用单一配置源：`tool/version_config.yaml`

当前配置示例：

```yaml
version: 1.0.2
build: 4
channel: release
```

字段含义：

- `version`：用户可见的语义化版本号，固定为 `x.y.z`
- `build`：内部构建号，会同步到 Android `versionCode`、iOS `CFBundleVersion`，以及 Flutter 的 `x.y.z+build`
- `channel`：展示层渠道标记，例如 `preview`、`beta`、`release`、`develop`；不会直接写入 Android / iOS 的真实平台版本号

同步步骤：

```bash
dart run tool/sync_version.dart
```

脚本会同步以下文件：

- `pubspec.yaml`
- `android/local.properties`
- `ios/Flutter/Generated.xcconfig`
- `ios/Flutter/flutter_export_environment.sh`
- `lib/generated/version_info.g.dart`

说明：

- 如果希望界面只显示纯数字版本，可把 `channel` 设为 `stable`
- 如果使用 `channel: release`，展示版本会变成 `1.0.2.release build4`

## 构建与发布

### Android Release

```bash
flutter build apk --release
```

如果当前网络环境访问 Flutter CDN 较慢：

```bash
cmd /c "set FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn&& flutter build apk --release"
```

### Windows Release

```bash
flutter build windows --release
```

更完整的构建、打包、发布前检查请看：

- [构建与发布指南](docs/build/BUILD_AND_RELEASE.md)

## 项目结构

```text
NWPU_COURSE_MONITOR/
 ├─ lib/
 │  ├─ app/                      应用壳、页面与通用组件
 │  ├─ state/                    AppState，全局状态与业务编排
 │  ├─ models/                    领域模型与时间/成绩工具函数
 │  ├─ services/                  存储、导入导出、通知、桌面能力封装
 │  └─ main.dart                  应用入口
 ├─ tool/                        版本同步等辅助脚本
 ├─ web/                         Web 入口资源
 ├─ windows/                      Windows runner 与原生小窗实现
 ├─ docs/                         面向开发者的人类文档
 └─ agent_handoff/                面向另一套 AI 工作区的本地交接文档（Git 忽略）
```

更详细的结构说明请看：

- [项目结构说明](docs/PROJECT_STRUCTURE.md)

## 相关文档

- [文档总览](docs/README.md)
- [项目结构说明](docs/PROJECT_STRUCTURE.md)
- [构建与发布指南](docs/build/BUILD_AND_RELEASE.md)
- [上游参考与归因](docs/UPSTREAM_ATTRIBUTION.md)

如果你当前是在本地工作区里继续和另一套 AI 协作开发，还可以查看：

- `agent_handoff/README.md`

注意：`agent_handoff/` 默认被 `.gitignore` 忽略，不会自动跟随 Git 远程仓库同步，需要手动拷贝到新工作区。

## 开发与协作约定

- 用户可见中文统一直接写中文，不使用 `\uXXXX` 逃避编码问题。
- Markdown / Dart / YAML 一律使用 `UTF-8` 保存。
- 涉及第三方代码或参考实现时，必须同步更新 `docs/UPSTREAM_ATTRIBUTION.md`。
- 涉及导入解析逻辑时，优先保留样本、截图、HTML 或接口响应，以便复现和调试。

## 参考来源

当前教务导入流程参考了 NWPU 场景的开源实现：

- `docs/references/soaring-schedule/`

这些参考文件仅用于理解页面结构与解析思路，不直接参与 Flutter 运行。
