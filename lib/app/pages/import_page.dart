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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          _buildImportActionPanel(state),
          const SizedBox(height: 10),
          _buildExportActionPanel(state),
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

  Widget _buildImportActionPanel(AppState state) {
    return FrostedPanel(
      enabled: state.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('导入', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '推荐顺序：先用「导入当前学期文件」，完整迁移再用「导入全部学期」。',
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

  Widget _buildExportActionPanel(AppState state) {
    return FrostedPanel(
      enabled: state.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('导出', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
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
        final String pageHtml = (payload['pageHtml'] as String? ?? '').trim();
        AutoImportResult result;
        if (pageHtml.isNotEmpty) {
          result = await widget.appState.importFromTimetableHtmlSnapshot(
            html: pageHtml,
            replaceExisting: _replaceExisting,
          );
          if (result.courses.isEmpty) {
            result = await widget.appState.importFromExtractedPayload(
              payload: payload,
              replaceExisting: _replaceExisting,
            );
          }
        } else {
          result = await widget.appState.importFromExtractedPayload(
            payload: payload,
            replaceExisting: _replaceExisting,
          );
        }
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
}
