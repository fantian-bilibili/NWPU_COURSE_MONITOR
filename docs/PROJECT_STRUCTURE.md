# 项目结构说明

本文档说明当前仓库的代码组织方式、运行时数据流，以及重要模块的职责边界。

## 1. 仓库顶层结构

```text
NWPU_COURSE_MONITOR/
├─ android/                      Android 原生工程与小组件实现
├─ ios/                          iOS 原生工程
├─ lib/                          Flutter 业务代码
├─ tool/                         维护脚本
├─ web/                          Web 资源
├─ windows/                      Windows runner 与原生能力扩展
├─ docs/                         面向开发者的人类文档
├─ agent_handoff/                面向 AI 的本地迁移文档（Git 忽略）
├─ pubspec.yaml                  Flutter 依赖与版本入口
└─ analysis_options.yaml         静态检查规则
```

## 2. Flutter 代码结构

### 2.1 入口层

- `lib/main.dart`
  - 组合根。
  - 创建 `AppState` 和所有 service。
  - 调用 `initialize()` 后再渲染应用。

### 2.2 应用壳层

- `lib/app/course_app.dart`
  - `MaterialApp`、主题、页面切换、手机端 dock、Windows 小窗入口。
  - 当前顶层页面是：
    - 课表
    - 导入
    - 绩点
    - 设置

### 2.3 页面层

- `lib/app/pages/schedule_page.dart`
  - 课表主页面。
  - 包含日列表、周列表、周视图。
  - 课程详情的折叠展开和绩点录入入口也在这里。
- `lib/app/pages/import_page.dart`
  - 文件导入导出与教务导入入口。
- `lib/app/pages/jwxt_import_webview_page.dart`
  - 教务系统 WebView 导入页面。
- `lib/app/pages/gpa_page.dart`
  - 学分绩总览与已出分课程列表。
- `lib/app/pages/settings_page.dart`
  - 学期管理、作息提醒、主题、组件、关于页。
- `lib/app/pages/windows_mini_schedule_page.dart`
  - Windows 小窗模式专用页面。

### 2.4 组件层

- `lib/app/widgets/frosted_panel.dart`
  - 通用磨砂容器和指标卡。
- `lib/app/widgets/course_editor_dialog.dart`
  - 课程编辑弹窗。
- `lib/app/widgets/grade_editor_dialog.dart`
  - 成绩编辑弹窗。

### 2.5 状态层

- `lib/state/app_state.dart`
  - 仓库最重要的业务编排层。
  - 职责：
    - 课程、成绩、学期、设置的内存态
    - 导入导出流程
    - 小组件同步
    - 提醒重建
    - Windows 小窗模式切换

### 2.6 领域模型层

- `lib/models/models.dart`
  - 数据模型：
    - `CourseSession`
    - `Course`
    - `GradeEntry`
    - `SemesterInfo`
    - `AppSettings`
    - `ImportBundle`
  - 时间、周次、绩点等工具函数也集中在这里。

### 2.7 服务层

- `lib/services/storage_service.dart`
  - 本地持久化，基于 `SharedPreferences`。
- `lib/services/import_export_service.dart`
  - JSON / CSV 导入导出。
- `lib/services/teaching_system_import_service.dart`
  - 教务导入、payload 导入、HTML 快照导入。
- `lib/services/notification_service.dart`
  - 通知初始化与重建。
- `lib/services/widget_sync_service.dart`
  - Android / iOS 组件同步。
- `lib/services/windows_desktop_service.dart`
  - Flutter 与 Windows runner 的 method channel 封装。

### 2.8 生成文件

- `lib/generated/version_info.g.dart`
  - 由 `tool/sync_version.dart` 生成。
  - 用于把版本展示信息带到应用内部。

## 3. 原生扩展位置

### 3.1 Android

- `android/app/src/main/kotlin/com/nwpu/nwpu_course_monitor/MainActivity.kt`
  - Android 主入口。
- `android/app/src/main/kotlin/com/nwpu/nwpu_course_monitor/CourseTodayWidgetProvider.kt`
  - Android 小组件 provider。
- `android/app/src/main/res/layout/course_today_widget.xml`
  - 小组件布局。
- `android/app/src/main/res/xml/course_today_widget_info.xml`
  - 小组件元信息。

### 3.2 Windows

- `windows/runner/main.cpp`
  - 进程入口。
- `windows/runner/flutter_window.cpp`
  - 小窗模式、窗口样式、原生通道。
- `windows/runner/win32_window.cpp`
  - Win32 窗口封装。

### 3.3 iOS

- `ios/Runner/AppDelegate.swift`
  - iOS 入口。
- `ios/Runner/Info.plist`
  - iOS 配置。

## 4. 当前推荐的数据流理解方式

建议把运行时理解成一条主线：

1. `main.dart`
   - 创建 service
   - 注入 `AppState`
2. `AppState.initialize()`
   - 读本地设置与数据
   - 恢复当前学期
   - 初始化提醒 / 组件 / Windows 状态
3. `CourseMonitorApp`
   - 根据 `AppState` 渲染完整主界面或 Windows 小窗
4. 页面层
   - 只负责展示与收集用户操作
5. 用户操作回到 `AppState`
   - `AppState` 调用 service
   - 再统一通知 UI 刷新

这个结构的核心原则是：

- 页面层尽量薄
- 业务编排集中到 `AppState`
- IO 和平台能力集中到 `services/`

## 5. 当前维护建议

### 5.1 新增功能时

优先按下面顺序放置代码：

1. 数据结构变更：`lib/models/models.dart`
2. 业务状态与流程：`lib/state/app_state.dart`
3. 平台能力或 IO：`lib/services/...`
4. 页面展示：`lib/app/pages/...`
5. 通用 UI：`lib/app/widgets/...`

### 5.2 不建议做的事

- 不要把导入导出、提醒、小组件逻辑直接写进页面文件。
- 不要把平台专用逻辑散落到多个页面里。
- 不要绕开 `AppState` 直接在页面里操作持久化。

### 5.3 当前可继续优化的点

- `AppState` 体量已经较大，未来可以按领域拆分：
  - semester
  - import/export
  - schedule settings
  - windows desktop
- `models.dart` 目前是单文件聚合，未来可拆成多文件。
- `pages/` 下仍然是平铺结构，后续可按模块分目录：
  - `schedule/`
  - `import/`
  - `settings/`
  - `windows/`

## 6. 相关文档

- [文档总览](README.md)
- [构建与发布指南](build/BUILD_AND_RELEASE.md)
