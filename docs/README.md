# 文档总览

本文档用于说明当前仓库文档的阅读顺序，以及不同文档分别解决什么问题。

## 推荐阅读顺序

1. [根 README](./README.md)
   - 先了解项目定位、当前版本、核心功能、版本同步方式和基本构建入口。
2. [项目结构说明](./PROJECT_STRUCTURE.md)
   - 了解目录分层、运行时数据流、核心文件职责和高风险模块。
3. [构建与发布指南](./build/BUILD_AND_RELEASE.md)
   - 了解版本同步、Android / Windows 构建、发布前检查与打包规范。
4. [上游参考与归因](./UPSTREAM_ATTRIBUTION.md)
   - 了解教务导入相关参考来源和许可证归因要求。

## 文档目录说明

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
