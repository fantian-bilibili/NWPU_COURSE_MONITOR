import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../generated/version_info.g.dart';
import '../../../models/models.dart';
import '../../../state/app_state.dart';
import '../../widgets/frosted_panel.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static final Uri _githubUri = Uri.parse(
    'https://github.com/fantian-bilibili',
  );

  late final TextEditingController _maxPeriodsController;
  final List<TextEditingController> _periodControllers =
      <TextEditingController>[];
  final List<TextEditingController> _periodEndControllers =
      <TextEditingController>[];
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _maxPeriodsController = TextEditingController();
    _syncControllersFromState();
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllersFromState();
  }

  @override
  void dispose() {
    _maxPeriodsController.dispose();
    for (final TextEditingController controller in _periodControllers) {
      controller.dispose();
    }
    for (final TextEditingController controller in _periodEndControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllersFromState() {
    final AppSettings settings = widget.appState.settings;
    _maxPeriodsController.text = settings.maxPeriodsPerDay.toString();
    _rebuildPeriodControllers(
      count: settings.maxPeriodsPerDay,
      startValues: settings.periodStartTimes,
      endValues: settings.periodEndTimes,
    );
  }

  void _rebuildPeriodControllers({
    required int count,
    required List<String> startValues,
    required List<String> endValues,
  }) {
    for (final TextEditingController controller in _periodControllers) {
      controller.dispose();
    }
    _periodControllers.clear();
    for (final TextEditingController controller in _periodEndControllers) {
      controller.dispose();
    }
    _periodEndControllers.clear();

    final int maxCount = count.clamp(1, 24);
    for (int i = 0; i < maxCount; i++) {
      final String startValue = i < startValues.length ? startValues[i] : '';
      final String endValue = i < endValues.length ? endValues[i] : '';
      _periodControllers.add(TextEditingController(text: startValue));
      _periodEndControllers.add(TextEditingController(text: endValue));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = widget.appState;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 10, 16, _settingsBottomInset(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '系统设置',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _semesterPanel(context, appState),
          const SizedBox(height: 10),
          _schedulePanel(context, appState),
          const SizedBox(height: 10),
          _themeAndWidgetPanel(context, appState),
          const SizedBox(height: 10),
          _aboutPanel(context, appState),
        ],
      ),
    );
  }

  Widget _semesterPanel(BuildContext context, AppState appState) {
    final ThemeData theme = Theme.of(context);
    return FrostedPanel(
      enabled: appState.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('学期管理', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Text(
              '当前学期',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pickCurrentSemester(context, appState),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.74),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              appState.currentSemester.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '共 ${appState.semesters.length} 个学期 · 点按切换',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.unfold_more_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _InfoLine(
              label: '第一周周一',
              value: DateFormat(
                'yyyy-MM-dd',
              ).format(appState.currentSemester.termStartMonday),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: () => _createSemester(context),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('新建学期'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _editSemester(context, appState.currentSemester),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('编辑当前学期'),
                ),
                OutlinedButton.icon(
                  onPressed: appState.semesters.length <= 1
                      ? null
                      : () =>
                            _deleteSemester(context, appState.currentSemester),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除当前学期'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _schedulePanel(BuildContext context, AppState appState) {
    final AppSettings settings = appState.settings;
    final int maxPeriods =
        int.tryParse(_maxPeriodsController.text.trim()) ??
        settings.maxPeriodsPerDay;
    final int safeMaxPeriods = maxPeriods.clamp(1, 24);

    return FrostedPanel(
      enabled: settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('作息与提醒', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('上课提醒提前 ${settings.reminderMinutesBefore} 分钟'),
            Slider(
              min: 0,
              max: 60,
              divisions: 12,
              value: settings.reminderMinutesBefore.toDouble(),
              onChanged: (double value) async {
                await appState.setReminderMinutes(value.toInt());
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _maxPeriodsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '每天理论最大节数',
                hintText: '例如：12',
              ),
              onChanged: (String value) {
                final int parsed = int.tryParse(value.trim()) ?? 0;
                final int target = parsed.clamp(1, 24);
                if (_periodControllers.length == target) {
                  return;
                }
                final List<String> currentStarts = _periodControllers
                    .map((TextEditingController c) => c.text.trim())
                    .toList();
                final List<String> currentEnds = _periodEndControllers
                    .map((TextEditingController c) => c.text.trim())
                    .toList();
                final List<String> nextStarts = <String>[];
                final List<String> nextEnds = <String>[];
                for (int i = 0; i < target; i++) {
                  if (i < currentStarts.length) {
                    nextStarts.add(currentStarts[i]);
                  } else if (i < settings.periodStartTimes.length) {
                    nextStarts.add(settings.periodStartTimes[i]);
                  } else {
                    nextStarts.add('');
                  }

                  if (i < currentEnds.length) {
                    nextEnds.add(currentEnds[i]);
                  } else if (i < settings.periodEndTimes.length) {
                    nextEnds.add(settings.periodEndTimes[i]);
                  } else {
                    nextEnds.add('');
                  }
                }
                setState(() {
                  _rebuildPeriodControllers(
                    count: target,
                    startValues: nextStarts,
                    endValues: nextEnds,
                  );
                });
              },
            ),
            const SizedBox(height: 10),
            Text(
              '每节课使用“上课 / 下课”时间，点击时间块默认使用滚轮选择。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            FrostedPanel(
              enabled: settings.frostedCards,
              padding: EdgeInsets.zero,
              radius: 22,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Column(
                  children: <Widget>[
                    for (
                      int i = 0;
                      i < safeMaxPeriods && i < _periodControllers.length;
                      i++
                    )
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          key: PageStorageKey<String>('period-tile-$i'),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            6,
                            0,
                            6,
                            10,
                          ),
                          title: Text(
                            '第${i + 1}节',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _formatPeriodRange(i),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _buildTimeField(
                                    controller: _periodControllers[i],
                                    label: '上课',
                                    onWheelTap: () => _pickPeriodTimeWithWheel(
                                      index: i,
                                      isStart: true,
                                    ),
                                    onKeyboardTap: () =>
                                        _pickPeriodTimeWithKeyboard(
                                          index: i,
                                          isStart: true,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildTimeField(
                                    controller: _periodEndControllers[i],
                                    label: '下课',
                                    onWheelTap: () => _pickPeriodTimeWithWheel(
                                      index: i,
                                      isStart: false,
                                    ),
                                    onKeyboardTap: () =>
                                        _pickPeriodTimeWithKeyboard(
                                          index: i,
                                          isStart: false,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton.tonalIcon(
              onPressed: () => _saveMaxPeriods(appState),
              icon: const Icon(Icons.schedule_outlined),
              label: const Text('应用节次与时间'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async =>
                  appState.runWithBusy(appState.regenerateNotifications),
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('重建提醒'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeAndWidgetPanel(BuildContext context, AppState appState) {
    return FrostedPanel(
      enabled: appState.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('外观与组件', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _ThemeModeSelector(
              value: appState.settings.themeModeSetting,
              onChanged: (ThemeModeSetting value) async {
                await appState.setThemeMode(value);
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用磨砂卡片'),
              subtitle: const Text('课程卡片使用轻量磨砂效果。'),
              value: appState.settings.frostedCards,
              onChanged: (bool value) async => appState.setFrostedCard(value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('组件显示周统计'),
              value: appState.settings.showWeekSummaryInWidget,
              onChanged: (bool value) async =>
                  appState.setWidgetWeekSummary(value),
            ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
              FilledButton.tonalIcon(
                onPressed: appState.windowsMiniMode
                    ? null
                    : () async => appState.runWithBusy(
                        appState.launchWindowsMiniWindow,
                      ),
                icon: const Icon(Icons.picture_in_picture_alt_outlined),
                label: const Text('切换到小窗模式'),
              ),
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('开机自启动'),
                subtitle: const Text('Windows 登录后自动启动'),
                value: appState.settings.windowsAutoStart,
                onChanged: (bool value) async =>
                    appState.setWindowsAutoStart(value),
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async =>
                  appState.runWithBusy(appState.syncWidgetNow),
              icon: const Icon(Icons.widgets_outlined),
              label: const Text('立即同步组件'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutPanel(BuildContext context, AppState appState) {
    return FutureBuilder<PackageInfo>(
      future: _packageInfoFuture,
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        final PackageInfo? info = snapshot.data;
        final String versionText = kAppDisplayVersionWithBuild;

        return FrostedPanel(
          enabled: appState.settings.frostedCards,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showAboutSheet(context, info),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.secondaryContainer,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '关于',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '版本 $versionText / SanSuan',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '作者主页：fantian-bilibili',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAboutSheet(context, info),
                    icon: const Icon(Icons.arrow_outward_rounded),
                    label: const Text('查看'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAboutSheet(BuildContext context, PackageInfo? info) async {
    final ThemeData theme = Theme.of(context);
    final String versionText = kAppDisplayVersion;
    final String buildText = kAppBuildNumber;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: FrostedPanel(
            enabled: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              theme.colorScheme.primaryContainer,
                              theme.colorScheme.secondaryContainer,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.dashboard_customize_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '课表管家',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '现代化多端课表与成绩工具',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      _AboutChip(
                        icon: Icons.verified_outlined,
                        label: '版本 $versionText',
                      ),
                      _AboutChip(
                        icon: Icons.tag_outlined,
                        label: '构建 $buildText',
                      ),
                      const _AboutChip(
                        icon: Icons.person_outline_rounded,
                        label: 'SanSuan',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: theme.colorScheme.surface.withValues(alpha: 0.62),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.42,
                        ),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'GitHub 主页',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _githubUri.toString(),
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        FilledButton.tonalIcon(
                          onPressed: _openGithub,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('打开'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openGithub() async {
    final bool launched = await launchUrl(
      _githubUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted || launched) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开 GitHub 链接')));
  }

  Future<void> _createSemester(BuildContext context) async {
    final _SemesterDraft? draft = await _showSemesterEditorDialog(
      context,
      title: '新建学期',
      initialName: _suggestSemesterName(),
      initialTermStart: mondayOf(DateTime.now()),
      confirmText: '创建',
    );
    if (draft == null) {
      return;
    }
    await widget.appState.runWithBusy(
      () => widget.appState.createSemester(
        name: draft.name,
        termStartMonday: draft.termStartMonday,
      ),
    );
  }

  Future<void> _pickCurrentSemester(
    BuildContext context,
    AppState appState,
  ) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: FrostedPanel(
            enabled: appState.settings.frostedCards,
            padding: EdgeInsets.zero,
            radius: 28,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '选择当前学期',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: appState.semesters.length,
                      separatorBuilder: (_, int index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final SemesterInfo semester = appState.semesters[index];
                        final bool selected =
                            semester.id == appState.currentSemester.id;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(semester.id),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                12,
                                14,
                                12,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.12,
                                      )
                                    : theme.colorScheme.surface.withValues(
                                        alpha: 0.68,
                                      ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: selected
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: 0.42,
                                        )
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.72),
                                ),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          semester.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '第一周周一：${DateFormat('yyyy-MM-dd').format(semester.termStartMonday)}',
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || selected == appState.currentSemester.id) {
      return;
    }
    await appState.runWithBusy(() => appState.switchSemester(selected));
  }

  Future<void> _editSemester(
    BuildContext context,
    SemesterInfo semester,
  ) async {
    final _SemesterDraft? draft = await _showSemesterEditorDialog(
      context,
      title: '编辑学期',
      initialName: semester.name,
      initialTermStart: semester.termStartMonday,
      confirmText: '保存',
    );
    if (draft == null) {
      return;
    }
    await widget.appState.runWithBusy(
      () => widget.appState.updateSemester(
        semesterId: semester.id,
        name: draft.name,
        termStartMonday: draft.termStartMonday,
      ),
    );
  }

  Future<void> _deleteSemester(
    BuildContext context,
    SemesterInfo semester,
  ) async {
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('删除学期'),
              content: Text('将删除“${semester.name}”以及该学期下的全部课程和成绩。此操作不可撤销。'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('删除'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed) {
      return;
    }

    await widget.appState.runWithBusy(
      () => widget.appState.deleteSemester(semester.id),
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onWheelTap,
    required VoidCallback onKeyboardTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final String value = controller.text.trim().isEmpty
        ? '--:--'
        : controller.text.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onWheelTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:
                theme.inputDecorationTheme.fillColor ??
                theme.colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: '滚轮选择',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                onPressed: onWheelTap,
                icon: const Icon(Icons.schedule_outlined, size: 16),
              ),
              IconButton(
                tooltip: '键盘输入',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                onPressed: onKeyboardTap,
                icon: const Icon(Icons.keyboard_outlined, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPeriodTimeWithWheel({
    required int index,
    required bool isStart,
  }) async {
    final TextEditingController controller = isStart
        ? _periodControllers[index]
        : _periodEndControllers[index];
    final String initial = normalizeTimeText(
      controller.text.trim(),
      fallback: isStart ? '08:00' : '08:50',
    );
    final String? picked = await _showWheelTimePicker(
      title: isStart ? '选择第${index + 1}节上课时间' : '选择第${index + 1}节下课时间',
      initialText: initial,
    );
    if (picked == null || picked.trim().isEmpty) {
      return;
    }
    setState(() => controller.text = picked);
  }

  Future<void> _pickPeriodTimeWithKeyboard({
    required int index,
    required bool isStart,
  }) async {
    final TextEditingController controller = isStart
        ? _periodControllers[index]
        : _periodEndControllers[index];
    final String initial = normalizeTimeText(
      controller.text.trim(),
      fallback: isStart ? '08:00' : '08:50',
    );
    final String? picked = await _showKeyboardTimeDialog(
      title: isStart ? '编辑第${index + 1}节上课时间' : '编辑第${index + 1}节下课时间',
      initialText: initial,
    );
    if (picked == null || picked.trim().isEmpty) {
      return;
    }
    setState(() => controller.text = picked);
  }

  Future<String?> _showWheelTimePicker({
    required String title,
    required String initialText,
  }) async {
    final DateTime now = DateTime.now();
    final int? minutes = timeTextToMinutes(initialText);
    DateTime selected = DateTime(
      now.year,
      now.month,
      now.day,
      (minutes ?? (8 * 60)) ~/ 60,
      (minutes ?? (8 * 60)) % 60,
    );

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: FrostedPanel(
            enabled: true,
            padding: EdgeInsets.zero,
            radius: 28,
            child: SizedBox(
              height: 290,
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        FilledButton.tonal(
                          onPressed: () =>
                              Navigator.of(context).pop(_formatTime(selected)),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoTheme(
                      data: CupertinoThemeData(
                        brightness: Theme.of(context).brightness,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        backgroundColor: Colors.transparent,
                        mode: CupertinoDatePickerMode.time,
                        use24hFormat: true,
                        initialDateTime: selected,
                        minuteInterval: 1,
                        onDateTimeChanged: (DateTime value) {
                          selected = value;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatPeriodRange(int index) {
    final String start = index < _periodControllers.length
        ? _periodControllers[index].text.trim()
        : '';
    final String end = index < _periodEndControllers.length
        ? _periodEndControllers[index].text.trim()
        : '';
    final String safeStart = start.isEmpty ? '--:--' : start;
    final String safeEnd = end.isEmpty ? '--:--' : end;
    return '$safeStart - $safeEnd';
  }

  Future<String?> _showKeyboardTimeDialog({
    required String title,
    required String initialText,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: initialText,
    );
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.datetime,
            decoration: const InputDecoration(
              labelText: '时间（HH:mm）',
              hintText: '08:30',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final String normalized = normalizeTimeText(
                  controller.text.trim(),
                  fallback: '',
                );
                if (normalized.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(normalized);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  String _formatTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _saveMaxPeriods(AppState appState) async {
    final int maxPeriods =
        int.tryParse(_maxPeriodsController.text.trim()) ?? 12;
    final int safeMaxPeriods = maxPeriods.clamp(1, 24);
    final List<String> periodStarts = <String>[];
    final List<String> periodEnds = <String>[];
    for (int i = 0; i < safeMaxPeriods && i < _periodControllers.length; i++) {
      periodStarts.add(_periodControllers[i].text.trim());
      periodEnds.add(_periodEndControllers[i].text.trim());
    }

    await appState.runWithBusy(
      () => appState.setSchedulePeriods(
        maxPeriodsPerDay: safeMaxPeriods,
        periodStartTimes: periodStarts,
        periodEndTimes: periodEnds,
      ),
    );
    if (!mounted) {
      return;
    }
    _syncControllersFromState();
    setState(() {});
  }

  Future<_SemesterDraft?> _showSemesterEditorDialog(
    BuildContext context, {
    required String title,
    required String initialName,
    required DateTime initialTermStart,
    required String confirmText,
  }) async {
    final TextEditingController nameController = TextEditingController(
      text: initialName,
    );
    DateTime selectedDate = mondayOf(initialTermStart);

    final _SemesterDraft? result = await showDialog<_SemesterDraft>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return AlertDialog(
                  title: Text(title),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: '学期名称',
                          hintText: '2026 春季学期',
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('第一周周一日期'),
                        subtitle: Text(
                          DateFormat('yyyy-MM-dd').format(selectedDate),
                        ),
                        trailing: TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2036),
                            );
                            if (picked == null) {
                              return;
                            }
                            setState(() => selectedDate = mondayOf(picked));
                          },
                          child: const Text('选择'),
                        ),
                      ),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final String name = nameController.text.trim();
                        if (name.isEmpty) {
                          return;
                        }
                        Navigator.of(context).pop(
                          _SemesterDraft(
                            name: name,
                            termStartMonday: mondayOf(selectedDate),
                          ),
                        );
                      },
                      child: Text(confirmText),
                    ),
                  ],
                );
              },
        );
      },
    );
    nameController.dispose();
    return result;
  }

  String _suggestSemesterName() {
    final DateTime now = DateTime.now();
    final bool autumn = now.month >= 8 || now.month <= 1;
    return '${now.year} ${autumn ? '秋季学期' : '春季学期'}';
  }
}

double _settingsBottomInset(BuildContext context) {
  final bool mobile = MediaQuery.sizeOf(context).width < 720;
  if (!mobile) {
    return 12;
  }
  return MediaQuery.paddingOf(context).bottom + 108;
}

class _ThemeModeSelector extends StatelessWidget {
  const _ThemeModeSelector({required this.value, required this.onChanged});

  final ThemeModeSetting value;
  final ValueChanged<ThemeModeSetting> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final (ThemeModeSetting value, String label) item
            in const <(ThemeModeSetting, String)>[
              (ThemeModeSetting.system, '跟随系统'),
              (ThemeModeSetting.light, '浅色'),
              (ThemeModeSetting.dark, '深色'),
            ])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: item.$1 == ThemeModeSetting.dark ? 0 : 8,
              ),
              child: _ThemeModeOption(
                label: item.$2,
                selected: item.$1 == value,
                onTap: () => onChanged(item.$1),
              ),
            ),
          ),
      ],
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  const _ThemeModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected ? scheme.primary : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(width: 84, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    );
  }
}

class _AboutChip extends StatelessWidget {
  const _AboutChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SemesterDraft {
  const _SemesterDraft({required this.name, required this.termStartMonday});

  final String name;
  final DateTime termStartMonday;
}
