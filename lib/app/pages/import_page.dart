import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/frosted_panel.dart';
import 'jwxt_import_webview_page.dart';

enum _ImportMode { merge, replace }

class ImportPage extends StatefulWidget {
  const ImportPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  _ImportMode _importMode = _ImportMode.merge;
  bool _applySettingsOnImport = true;
  bool _includeSettingsInJsonExport = true;

  bool get _replaceExisting => _importMode == _ImportMode.replace;

  bool get _mobileWebImportSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final AppState state = widget.appState;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 10, 16, _pageBottomInset(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '导入与导出',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '当前学期：${state.currentSemester.name}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          _buildImportConfigPanel(state),
          const SizedBox(height: 10),
          _buildTimetableImportPanel(state),
          const SizedBox(height: 10),
          _buildGradeImportPanel(state),
          const SizedBox(height: 10),
          _buildBackupPanel(state),
        ],
      ),
    );
  }

  Widget _buildImportConfigPanel(AppState state) {
    return FrostedPanel(
      enabled: state.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('导入设置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<_ImportMode>(
              segments: const <ButtonSegment<_ImportMode>>[
                ButtonSegment<_ImportMode>(
                  value: _ImportMode.merge,
                  icon: Icon(Icons.merge_type_outlined),
                  label: Text('合并去重'),
                ),
                ButtonSegment<_ImportMode>(
                  value: _ImportMode.replace,
                  icon: Icon(Icons.content_cut_outlined),
                  label: Text('覆盖替换'),
                ),
              ],
              selected: <_ImportMode>{_importMode},
              onSelectionChanged: (Set<_ImportMode> value) {
                setState(() => _importMode = value.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _replaceExisting
                  ? '当前导入模式：使用新数据完整替换目标学期内容。'
                  : '当前导入模式：在保留原数据的基础上合并去重。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('导入时同步作息与提醒设置'),
              subtitle: const Text('当 JSON 包含设置项时，将作息和提醒策略一起恢复。'),
              value: _applySettingsOnImport,
              onChanged: (bool value) {
                setState(() => _applySettingsOnImport = value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimetableImportPanel(AppState state) {
    return FrostedPanel(
      enabled: state.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('课表导入', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '这里只处理课程表。手机端教务导入、ICS、JSON、CSV 都归在这一组。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            if (_mobileWebImportSupported)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _startWebViewImport,
                  icon: const Icon(Icons.language_outlined),
                  label: const Text('手机端一键教务导入'),
                ),
              ),
            if (_mobileWebImportSupported) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _pickAndImportCurrentSemesterFile,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('导入当前学期文件（JSON / CSV / ICS）'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickAndImportAllSemestersFile,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('导入全部学期备份（JSON）'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeImportPanel(AppState state) {
    return FrostedPanel(
      enabled: state.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('成绩导入', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '当前先支持 Excel 成绩单导入。后续接教务成绩导入时，也会放在这里。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _pickAndImportGradeExcel,
                icon: const Icon(Icons.table_view_rounded),
                label: const Text('导入成绩 Excel（XLSX）'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupPanel(AppState state) {
    return FrostedPanel(
      enabled: state.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('备份与迁移', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '整包迁移和导出都放在这里。推荐整机迁移时优先使用 JSON 备份。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickAndImportAllSemestersFile,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('导入全部学期备份（JSON）'),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('JSON 导出包含作息与提醒设置'),
              subtitle: const Text('CSV 仅包含课程和成绩，不包含设置项。'),
              value: _includeSettingsInJsonExport,
              onChanged: (bool value) {
                setState(() => _includeSettingsInJsonExport = value);
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _exportCurrentSemester(json: true),
                    icon: const Icon(Icons.data_object_outlined),
                    label: const Text('导出当前学期 JSON'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _exportCurrentSemester(json: false),
                    icon: const Icon(Icons.table_rows_outlined),
                    label: const Text('导出当前学期 CSV'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _exportAllSemestersJson,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('一键导出全部学期（JSON）'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndImportCurrentSemesterFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['json', 'csv', 'ics'],
    );
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.single.path == null) {
      return;
    }

    final String path = picked.files.single.path!;
    try {
      await widget.appState.runWithBusy(() async {
        final ({int courses, int grades}) result = await widget.appState
            .importByFile(
              path: path,
              replaceExisting: _replaceExisting,
              applySettings: _applySettingsOnImport,
            );
        _showMessage('导入完成：${result.courses} 门课程，${result.grades} 条成绩。');
      });
    } catch (error) {
      _showMessage('导入失败：${_friendlyError(error)}');
    }
  }

  Future<void> _pickAndImportGradeExcel() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['xlsx', 'xls'],
    );
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.single.path == null) {
      return;
    }

    final String path = picked.files.single.path!;
    try {
      final ExcelGradeParseResult preview = await widget.appState
          .previewGradeExcel(path);
      if (!mounted) {
        return;
      }

      final Map<String, String>? semesterMapping =
          await _showExcelSemesterMappingDialog(preview);
      if (semesterMapping == null) {
        return;
      }

      final ExcelGradeImportResult result = await widget.appState.runWithBusy(
        () => widget.appState.importGradesFromExcel(
          rows: preview.rows,
          semesterMapping: semesterMapping,
        ),
      );
      _showMessage(
        '成绩导入完成：写入 ${result.appliedCount} 条，跳过 ${result.skippedMissingCourses.length} 条。',
      );
      if (result.skippedMissingCourses.isNotEmpty && mounted) {
        await _showSkippedCourseDialog(result);
      }
    } catch (error) {
      _showMessage('Excel 导入失败：${_friendlyError(error)}');
    }
  }

  Future<void> _pickAndImportAllSemestersFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['json'],
    );
    if (picked == null ||
        picked.files.isEmpty ||
        picked.files.single.path == null) {
      return;
    }

    final String path = picked.files.single.path!;
    try {
      await widget.appState.runWithBusy(() async {
        final ({int courses, int grades, int semesters}) result = await widget
            .appState
            .importAllSemestersByFile(
              path: path,
              replaceExisting: _replaceExisting,
              applySettings: _applySettingsOnImport,
            );
        _showMessage(
          '全学期导入完成：'
          '${result.semesters} 个学期，'
          '${result.courses} 门课程，'
          '${result.grades} 条成绩。',
        );
      });
    } catch (error) {
      _showMessage('导入失败：${_friendlyError(error)}');
    }
  }

  Future<void> _exportCurrentSemester({required bool json}) async {
    try {
      await widget.appState.runWithBusy(() async {
        final File file = json
            ? await widget.appState.exportJson(
                includeSettings: _includeSettingsInJsonExport,
              )
            : await widget.appState.exportCsv();
        await _shareOrShowPath(
          file,
          fallbackPrefix: json ? '已导出当前学期 JSON' : '已导出当前学期 CSV',
        );
      });
    } catch (error) {
      _showMessage('导出失败：${_friendlyError(error)}');
    }
  }

  Future<void> _exportAllSemestersJson() async {
    try {
      await widget.appState.runWithBusy(() async {
        final File file = await widget.appState.exportAllSemestersJson(
          includeSettings: _includeSettingsInJsonExport,
        );
        await _shareOrShowPath(file, fallbackPrefix: '已导出全部学期 JSON');
      });
    } catch (error) {
      _showMessage('导出失败：${_friendlyError(error)}');
    }
  }

  Future<void> _shareOrShowPath(
    File file, {
    required String fallbackPrefix,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path)], text: '课表备份文件'),
      );
    } catch (_) {
      _showMessage('$fallbackPrefix：${file.path}');
    }
  }

  Future<void> _startWebViewImport() async {
    if (!_mobileWebImportSupported) {
      return;
    }

    final Map<String, dynamic>? payload = await Navigator.of(context)
        .push<Map<String, dynamic>>(
          MaterialPageRoute<Map<String, dynamic>>(
            builder: (_) => const JwxtImportWebViewPage(),
            fullscreenDialog: true,
          ),
        );
    if (payload == null) {
      return;
    }

    try {
      await widget.appState.runWithBusy(() async {
        final AutoImportResult result = await widget.appState
            .importFromJwxtCapture(
              payload: payload,
              replaceExisting: _replaceExisting,
            );
        _showMessage(result.messages.join(' '));
      });
    } catch (error) {
      _showMessage('导入失败：${_friendlyError(error)}');
    }
  }

  String _friendlyError(Object error) {
    final String text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<Map<String, String>?> _showExcelSemesterMappingDialog(
    ExcelGradeParseResult preview,
  ) {
    final AppState state = widget.appState;
    final Map<String, String> mapping = <String, String>{
      for (final String semester in preview.sourceSemesters)
        semester: _guessSemesterMapping(state, semester),
    };

    return showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, void Function(void Function()) setState) {
            return AlertDialog(
              title: const Text('匹配 Excel 学期'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '识别到 ${preview.rows.length} 条成绩，涉及 ${preview.sourceSemesters.length} 个学期。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      for (final String sourceSemester
                          in preview.sourceSemesters) ...<Widget>[
                        Text(
                          sourceSemester,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '导入到哪个课表学期',
                            isDense: true,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: mapping[sourceSemester],
                              isExpanded: true,
                              items: state.semesters
                                  .map(
                                    (SemesterInfo semester) =>
                                        DropdownMenuItem<String>(
                                          value: semester.id,
                                          child: Text(
                                            semester.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                  )
                                  .toList(),
                              onChanged: (String? value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() => mapping[sourceSemester] = value);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed:
                      mapping.values.any((String value) => value.trim().isEmpty)
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(Map<String, String>.from(mapping)),
                  child: const Text('开始导入'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _guessSemesterMapping(AppState state, String sourceSemester) {
    final String normalizedSource = sourceSemester.trim().toLowerCase();
    for (final SemesterInfo semester in state.semesters) {
      if (semester.name.trim().toLowerCase() == normalizedSource) {
        return semester.id;
      }
    }
    for (final SemesterInfo semester in state.semesters) {
      final String target = semester.name.trim().toLowerCase();
      if (target.contains(normalizedSource) ||
          normalizedSource.contains(target)) {
        return semester.id;
      }
    }
    return state.currentSemester.id;
  }

  Future<void> _showSkippedCourseDialog(ExcelGradeImportResult result) {
    final List<String> preview = result.skippedMissingCourses.take(12).toList();
    final int more = result.skippedMissingCourses.length - preview.length;
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('以下成绩已跳过'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('这些课程在对应学期中不存在，因此无法绑定成绩：'),
                  const SizedBox(height: 10),
                  for (final String item in preview)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $item'),
                    ),
                  if (more > 0) Text('……以及另外 $more 条'),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
  }
}

double _pageBottomInset(BuildContext context) {
  final bool mobile = MediaQuery.sizeOf(context).width < 720;
  if (!mobile) {
    return 12;
  }
  return MediaQuery.paddingOf(context).bottom + 108;
}
