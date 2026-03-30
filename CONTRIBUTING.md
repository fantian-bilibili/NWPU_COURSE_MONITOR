# Contributing Guide

本文档面向继续维护本仓库的开发者与 AI 协作者。

## 分支策略

- `main`：稳定发布分支，仅接收经过验证的发布合并。
- `develop`：日常开发主分支，功能开发与 bug 修复优先进入 `develop`。

向 `develop` 提交前，确保：

- `flutter analyze` 无警告
- `flutter test` 通过
- 已同步最新 `develop`（如有冲突请先 rebase）

向 `main` 提交仅通过 PR，禁止直接推送。

## 文档阅读顺序

建议新贡献者按以下顺序阅读文档：

1. [根 README](./README.md)
   - 先了解项目定位、当前版本、核心功能、版本同步方式和基本构建入口。
2. [项目结构说明](./docs/PROJECT_STRUCTURE.md)
   - 了解目录分层、运行时数据流、核心文件职责和高风险模块。
3. [构建与发布指南](./docs/build/BUILD_AND_RELEASE.md)
   - 了解版本同步、Android / Windows 构建、发布前检查与打包规范。
4. [上游参考与归因](./docs/UPSTREAM_ATTRIBUTION.md)
   - 了解教务导入相关参考来源和许可证归因要求。

## 目录说明

- `PROJECT_STRUCTURE.md`
  - 代码结构、运行时架构、核心业务流、高风险文件说明。
- `build/BUILD_AND_RELEASE.md`
  - 版本同步、构建命令、打包方式、发布验证清单。
- `UPSTREAM_ATTRIBUTION.md`
  - 第三方参考实现与许可证归因。
- `references/`
  - 参考实现快照，不参与当前 Flutter 运行时。

## 面向 AI 交接的本地文档

如果你当前是在本地工作区里和另一套 AI 协作，优先再读：

- `agent_handoff/README.md`

说明：

- `agent_handoff/` 是本地 handoff 包，默认被 `.gitignore` 忽略。
- 它面向另一工作区的 AI 接手开发，内容比公开文档更偏执行与排障。
- 如果你要迁移到新的工作区，需要手动复制整个 `agent_handoff/` 文件夹。

## 文档维护规则

- 行为变化时优先更新文档，而不是事后补文档。
- 版本号变更时，至少检查：
  - `README.md`
  - `docs/build/BUILD_AND_RELEASE.md`
  - `agent_handoff/README.md`
  - `agent_handoff/01_project_snapshot.md`
- 文档统一使用 `UTF-8` 编码。

## 新功能放置顺序

新增功能时，优先按下面顺序放代码：

1. 数据结构：`lib/models/models.dart`
2. 业务编排：`lib/state/app_state.dart`
3. IO / 平台能力：`lib/services/...`
4. 页面展示：`lib/app/pages/...`
5. 通用 UI：`lib/app/widgets/...`

## 不建议做的事

- 不要把导入导出、通知、小组件逻辑直接写在页面里。
- 不要绕开 `AppState` 在页面里直接操作持久化。
- 不要把平台专有逻辑散落到多个页面里。
- 不要为了"修编码"把中文重新改回 `\uXXXX`。

## 开发约定

- 用户可见中文统一直接写中文，不使用 `\uXXXX` 逃避编码问题。
- Markdown / Dart / YAML 一律使用 `UTF-8` 保存。
- 涉及第三方代码或参考实现时，必须同步更新 `docs/UPSTREAM_ATTRIBUTION.md`。
- 涉及导入解析逻辑时，优先保留样本、截图、HTML 或接口响应，以便复现和调试。
