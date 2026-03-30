# 项目结构说明

本文档说明当前仓库的代码组织方式、运行时数据流，以及重要模块的职责边界。它面向继续维护本项目的开发者与 AI 协作者。

## 1. 顶层结构

```text
NWPU_COURSE_MONITOR/
 ├─ .github/                     GitHub 配置（PR 模板等）
 ├─ lib/                         Flutter 业务代码
 ├─ tool/                        维护脚本
 ├─ web/                         Web 资源
 ├─ windows/                     Windows runner 与原生窗口扩展
 ├─ docs/                        面向开发者的人类文档
 ├─ agent_handoff/               面向另一套 AI 工作区的本地文档（Git 忽略）
 ├─ pubspec.yaml                 Flutter 依赖与版本入口
 └─ analysis_options.yaml        静态检查规则
```

## 2. 代码结构

### 2.1 入口层

- `lib/main.dart`
  - 创建所有 service。
  - 构造唯一的 `AppState`。
  - 先执行 `await appState.initialize()`，再渲染应用。

### 2.2 应用壳层

- `lib/app/course_app.dart`
  - `MaterialApp`、主题、顶层导航、页面切换。
  - 根据平台和状态决定渲染：
    - 完整应用壳
    - Windows 小窗模式
  - 定义全局字体回退、桌面端滚动行为和主要视觉风格。

当前顶层页面共有 4 个：

1. 课表
2. 导入与导出
3. 学分绩
4. 设置

### 2.3 页面层

- `lib/app/pages/schedule_page.dart`
  - 课表主页面。
  - 负责：日列表、周列表、周视图、网课独立展示、课程详情展开、单课程成绩录入入口。
- `lib/app/pages/import_page.dart`
  - 导入导出总入口。
  - 当前分为 3 组：课表导入、成绩导入、备份与迁移。
- `lib/app/pages/jwxt_import_webview_page.dart`
  - 教务系统 WebView 导入页。
  - 当前支持两种模式：课表模式、成绩模式。
- `lib/app/pages/gpa_page.dart`
  - 学分绩总览、指标卡、已出分课程列表。
- `lib/app/pages/settings_page.dart`
  - 学期管理、作息与提醒、主题、小组件、关于、Windows 小窗开关等。
- `lib/app/pages/windows_mini_schedule_page.dart`
  - Windows 小窗模式专用界面。

### 2.4 通用组件层

- `lib/app/widgets/frosted_panel.dart`
  - 通用磨砂卡片容器与指标卡。
- `lib/app/widgets/course_editor_dialog.dart`
  - 课程编辑弹窗。
- `lib/app/widgets/grade_editor_dialog.dart`
  - 成绩编辑弹窗。

### 2.5 状态层

- `lib/state/app_state.dart`
  - 当前仓库最重要的业务编排层。
  - 统一管理：课程、成绩、学期、设置、导入导出流程、提醒同步、小组件同步、Windows 小窗切换。

关键职责：

- 学期增删改切换
- 课程与成绩增删改
- GPA / 加权均分计算
- 文件导入导出
- 教务课表导入
- 教务成绩导入
- 导入后的小组件和提醒重建

### 2.6 领域模型层

- `lib/models/models.dart`
  - 定义领域模型与时间/成绩工具函数。

当前关键模型：

- `CourseSession` — 一段排课信息：星期、节次范围、周次范围、单双周。
- `Course` — 课程主模型。当前支持 `CourseType.scheduled` 与 `CourseType.online`。
- `GradeEntry` — 成绩模型。当前支持 `GradeResultType.gpa`、`pass`、`noPass`。
- `SemesterInfo` — 学期模型，包含名称与学期首周周一。
- `AppSettings` — 主题、提醒、小组件、作息、Windows 小窗与开机启动等设置。
- `ImportBundle` — 文件导入导出使用的统一打包模型。
- `ExcelGradeRow` / `ExcelGradeParseResult` — Excel 成绩单和教务成绩页的中间解析结构。

### 2.7 服务层

- `lib/services/storage_service.dart`
  - 基于 `SharedPreferences` 的本地持久化。
- `lib/services/import_export_service.dart`
  - JSON / CSV / ICS 导入导出；Excel 成绩单解析。
- `lib/services/teaching_system_import_service.dart`
  - 教务系统导入与解析。
  - 当前同时负责：课表 HTML / payload 解析、网课识别、成绩页面 HTML 解析。
- `lib/services/notification_service.dart`
  - 提醒初始化与重建。
- `lib/services/widget_sync_service.dart`
  - Android / iOS 小组件数据同步。
- `lib/services/windows_desktop_service.dart`
  - Windows runner method channel 封装。

### 2.8 生成文件

- `lib/generated/version_info.g.dart`
  - 由 `dart run tool/sync_version.dart` 生成。
  - 负责把展示版本带入应用内关于页等位置。

## 3. 当前关键业务流

### 3.1 文件导入

1. 用户在 `ImportPage` 选择文件。
2. `AppState.importByFile()` 或 `importAllSemestersByFile()` 被调用。
3. `ImportExportService.importFromPath()` 根据扩展名分发：json、csv、ics。
4. 返回 `ImportBundle` 后由 `AppState` 统一合并 / 覆盖。
5. 完成后触发持久化、提醒重建、小组件同步。

### 3.2 教务课表导入

1. 用户进入 `JwxtImportWebViewPage(mode: timetable)`。
2. 页面内提取页面 HTML 和页面 payload。
3. `AppState.importFromJwxtCapture()` 同时解析两路来源并合并。
4. 合并结果写入当前学期。
5. 网课会被标记为 `CourseType.online`，不会进入三种课表视图。

### 3.3 教务成绩导入

1. 用户进入 `JwxtImportWebViewPage(mode: grade)`。
2. 当前实现优先从成绩页 HTML 中解析 `ExcelGradeRow` 风格的中间数据。
3. 用户在导入前选择"教务中的学期名称"映射到"应用内的目标学期"。
4. `AppState.importGradesFromExcel()` 复用统一导入逻辑，将成绩绑定到已有课程。
5. 匹配顺序：课程代码 > 课程名称。匹配失败的成绩会跳过并反馈给用户。

### 3.4 Excel 成绩导入

1. 用户选择 `.xlsx` 文件。
2. `ImportExportService.parseGradeExcel()` 读取表头并识别：课程名称、课程代码、学分、成绩、绩点、学期。
3. 解析结果先进入学期映射对话框。
4. 最终仍由 `AppState.importGradesFromExcel()` 完成落库。

### 3.5 学期切换

1. 用户在设置页切换当前学期。
2. `AppState.switchSemester()` 更新：`_currentSemesterId`、`termStartMonday`。
3. 随后重建：小组件数据、提醒计划。
4. 页面会自动刷新为该学期的数据。

### 3.6 Windows 小窗模式

1. 用户在完整模式下切到小窗模式。
2. `WindowsDesktopService` 通过 method channel 通知原生层。
3. Windows runner 会以独立流程参数 `--windows-mini-window` 启动小窗。
4. Flutter 侧根据 `appState.windowsMiniMode` 渲染专用小窗页面。

## 4. 原生扩展位置

### 4.1 Android

- `android/app/src/main/kotlin/com/nwpu/nwpu_course_monitor/MainActivity.kt`
  - Android 主入口。
- `android/app/src/main/kotlin/com/nwpu/nwpu_course_monitor/CourseTodayWidgetProvider.kt`
  - Android 小组件 Provider。
- `android/app/src/main/res/xml/course_today_widget_info.xml`
  - 小组件元信息。

### 4.2 Windows

- `windows/runner/main.cpp`
  - 进程入口。
- `windows/runner/flutter_window.cpp`
  - 窗口样式、小窗模式、原生方法通道。
- `windows/runner/win32_window.cpp`
  - Win32 窗口封装。

### 4.3 iOS

- `ios/Runner/AppDelegate.swift`
  - iOS 入口。
- `ios/Runner/Info.plist`
  - iOS 配置。

## 5. 高风险文件

以下文件修改时需要更谨慎：

- `lib/state/app_state.dart`
  - 全局状态与业务编排中心，改动容易产生连锁回归。
- `lib/services/teaching_system_import_service.dart`
  - 解析器对上游 HTML 结构和关键字比较敏感。
- `lib/app/course_app.dart`
  - 涉及主题、顶层导航、平台切换与性能。
- `lib/app/pages/schedule_page.dart`
  - 课表三种视图、网课展示、课程详情、成绩录入集中在此。
- `windows/runner/flutter_window.cpp`
  - Windows 小窗模式的原生窗口行为。

## 6. 当前维护建议

### 6.1 新功能放置顺序

新增功能时，优先按下面顺序放代码：

1. 数据结构：`lib/models/models.dart`
2. 业务编排：`lib/state/app_state.dart`
3. IO / 平台能力：`lib/services/...`
4. 页面展示：`lib/app/pages/...`
5. 通用 UI：`lib/app/widgets/...`

### 6.2 不建议做的事

- 不要把导入导出、通知、小组件逻辑直接写在页面里。
- 不要绕开 `AppState` 在页面里直接操作持久化。
- 不要把平台专有逻辑散落到多个页面里。
- 不要为了"修编码"把中文重新改回 `\uXXXX`。

### 6.3 后续可以继续优化的方向

- `AppState` 已比较大，可按领域拆分：semester、import/export、reminder/widget、windows desktop。
- `models.dart` 目前仍是单文件聚合，可拆为多文件。
- `pages/` 当前仍是平铺目录，后续可按模块分组。

## 7. 相关文档

- [根 README](./README.md)
- [构建与发布指南](./build/BUILD_AND_RELEASE.md)
- [上游参考与归因](./UPSTREAM_ATTRIBUTION.md)
