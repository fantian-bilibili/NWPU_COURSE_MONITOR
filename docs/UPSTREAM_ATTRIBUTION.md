# Upstream Attribution

本文件用于记录本仓库引用、改写或借鉴的上游项目来源与许可证信息。

## 上游仓库

- Repository: `Whippap/soaring-schedule`
- URL: `https://github.com/Whippap/soaring-schedule`
- Upstream License: `MIT`
- Checked Date: `2026-03-30`
- License Reference: `https://raw.githubusercontent.com/Whippap/soaring-schedule/main/LICENSE`

## 本仓库保留的参考快照

以下文件保存在 `docs/references/soaring-schedule/`，仅用于审计、对照和理解解析思路：

- `README.md`
- `jwxtParser.ts`
- `CourseImportWizard.tsx`
- `JwxtWebView.tsx`
- `build-flow.md`

## 本仓库中受其启发的实现

以下文件参考了上游项目中对 NWPU 场景的教务导入思路，并结合 Flutter 技术栈与本项目数据模型进行了重写：

- `lib/services/teaching_system_import_service.dart`
- `lib/app/pages/jwxt_import_webview_page.dart`

## 当前归因说明

- 上游主要影响的是：
  - 教务课表页面识别思路
  - WebView 导入流程设计
  - NWPU 场景下的字段提取思路
- 本仓库已经根据自身模型做了较大改写，包括但不限于：
  - 课程模型与去重逻辑
  - 网课识别与独立展示
  - HTML + payload 合并导入策略
  - 成绩页 HTML 解析
  - Excel / ICS / JSON / CSV 多源导入整合

说明：

- 当前"教务成绩页 HTML 解析"属于本仓库在 NWPU 页面样本基础上的扩展实现，不是对上游某个现成成绩解析器的直接搬运。

## 合规要求

1. 本仓库采用 MIT 许可证，与上游 MIT 许可证兼容。
2. 如果后续继续引入第三方代码或参考实现，必须在本文件追加：
   - 来源仓库
   - 许可证
   - 检查日期
   - 受影响文件
   - 改写说明
3. 发布时应保留：
   - 根目录 `LICENSE`
   - 本文件 `docs/UPSTREAM_ATTRIBUTION.md`
4. 不得把带有敏感信息的抓包、页面源码、Cookie 或 Token 提交到仓库。
