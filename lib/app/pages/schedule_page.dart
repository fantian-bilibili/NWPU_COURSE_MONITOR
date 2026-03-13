import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/course_editor_dialog.dart';
import '../widgets/frosted_panel.dart';

enum _ScheduleMode { dayList, weekList, weekGrid }

enum _CourseGradeMode { pending, gpa, pass, noPass }

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.appState});

  final AppState appState;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _weekAnchor;
  late int _selectedWeekday;
  _ScheduleMode _mode = _ScheduleMode.dayList;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _weekAnchor = now;
    _selectedWeekday = now.weekday;
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = widget.appState;
    final DateTime weekStart = mondayOf(_weekAnchor);
    final DateTime selectedDate = weekStart.add(
      Duration(days: _selectedWeekday - DateTime.monday),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _header(context, state, selectedDate, weekStart),
          const SizedBox(height: 8),
          _modeBar(state.settings.frostedCards),
          const SizedBox(height: 8),
          _weekNavigator(state.settings.frostedCards, weekStart),
          if (_mode == _ScheduleMode.dayList) ...<Widget>[
            const SizedBox(height: 8),
            _weekdaySelector(state.settings.frostedCards, weekStart),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (_mode) {
                _ScheduleMode.dayList => _DayListBody(
                  key: const ValueKey<String>('day'),
                  appState: state,
                  date: selectedDate,
                  courses: state.coursesForDate(selectedDate),
                  onEdit: (Course c) =>
                      _createOrEditCourse(context, state, existing: c),
                ),
                _ScheduleMode.weekList => _WeekListBody(
                  key: const ValueKey<String>('weeklist'),
                  appState: state,
                  weekStart: weekStart,
                  onEdit: (Course c) =>
                      _createOrEditCourse(context, state, existing: c),
                ),
                _ScheduleMode.weekGrid => _WeekGridBody(
                  key: const ValueKey<String>('weekgrid'),
                  appState: state,
                  weekStart: weekStart,
                  onEdit: (Course c) =>
                      _createOrEditCourse(context, state, existing: c),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    AppState state,
    DateTime selectedDate,
    DateTime weekStart,
  ) {
    final DateTime titleDate = _mode == _ScheduleMode.dayList
        ? selectedDate
        : weekStart;
    final bool compact = MediaQuery.sizeOf(context).width < 430;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    '课程总览',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: compact ? 24 : null,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: compact ? 8 : 10),
                  Expanded(
                    child: Text(
                      state.currentSemester.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: compact
                          ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            )
                          : Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(DateFormat('yyyy年M月d日 EEEE', 'zh_CN').format(titleDate)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        compact
            ? FilledButton(
                onPressed: () => _createOrEditCourse(context, state),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(46, 46),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.add),
              )
            : FilledButton.icon(
                onPressed: () => _createOrEditCourse(context, state),
                icon: const Icon(Icons.add),
                label: const Text('新增课程'),
              ),
      ],
    );
  }

  Widget _modeBar(bool frosted) {
    return FrostedPanel(
      enabled: frosted,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: _ModeButton(
                label: '日列表',
                selected: _mode == _ScheduleMode.dayList,
                icon: Icons.view_day_outlined,
                onTap: () => setState(() => _mode = _ScheduleMode.dayList),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeButton(
                label: '周列表',
                selected: _mode == _ScheduleMode.weekList,
                icon: Icons.view_week_outlined,
                onTap: () => setState(() => _mode = _ScheduleMode.weekList),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeButton(
                label: '周视图',
                selected: _mode == _ScheduleMode.weekGrid,
                icon: Icons.grid_view_outlined,
                onTap: () => setState(() => _mode = _ScheduleMode.weekGrid),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekNavigator(bool frosted, DateTime weekStart) {
    final DateTime weekEnd = weekStart.add(const Duration(days: 6));
    return FrostedPanel(
      enabled: frosted,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: () => setState(
                () =>
                    _weekAnchor = _weekAnchor.subtract(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                '${DateFormat('M月d日').format(weekStart)} - '
                '${DateFormat('M月d日').format(weekEnd)}',
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: () => setState(
                () => _weekAnchor = _weekAnchor.add(const Duration(days: 7)),
              ),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
            OutlinedButton(
              onPressed: () => setState(() => _weekAnchor = DateTime.now()),
              child: const Text('本周'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekdaySelector(bool frosted, DateTime weekStart) {
    return FrostedPanel(
      enabled: frosted,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: <Widget>[
            for (int day = DateTime.monday; day <= DateTime.sunday; day++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _WeekDayButton(
                    selected: _selectedWeekday == day,
                    label:
                        '${weekdayLabel(day)}\n'
                        '${weekStart.add(Duration(days: day - 1)).day}',
                    onTap: () => setState(() => _selectedWeekday = day),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createOrEditCourse(
    BuildContext context,
    AppState state, {
    Course? existing,
  }) async {
    final Course? edited = await showDialog<Course>(
      context: context,
      builder: (BuildContext context) => CourseEditorDialog(
        existing: existing,
        maxPeriodsPerDay: state.settings.maxPeriodsPerDay,
      ),
    );
    if (edited == null) {
      return;
    }
    await state.runWithBusy(() => state.upsertCourse(edited));
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.92)
              : scheme.surface.withValues(alpha: 0.55),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.4)
                : scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _WeekDayButton extends StatelessWidget {
  const _WeekDayButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? scheme.primaryContainer.withValues(alpha: 0.9)
              : scheme.surface.withValues(alpha: 0.5),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _DayListBody extends StatelessWidget {
  const _DayListBody({
    super.key,
    required this.appState,
    required this.date,
    required this.courses,
    required this.onEdit,
  });

  final AppState appState;
  final DateTime date;
  final List<Course> courses;
  final ValueChanged<Course> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        _CourseSectionCard(
          appState: appState,
          date: date,
          title: DateFormat('M月d日 EEEE', 'zh_CN').format(date),
          courses: courses,
          onEdit: onEdit,
        ),
      ],
    );
  }
}

class _WeekListBody extends StatelessWidget {
  const _WeekListBody({
    super.key,
    required this.appState,
    required this.weekStart,
    required this.onEdit,
  });

  final AppState appState;
  final DateTime weekStart;
  final ValueChanged<Course> onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        for (int day = DateTime.monday; day <= DateTime.sunday; day++)
          _CourseSectionCard(
            appState: appState,
            date: weekStart.add(Duration(days: day - DateTime.monday)),
            title:
                '${weekdayLabel(day)} · '
                '${DateFormat('M月d日').format(weekStart.add(Duration(days: day - DateTime.monday)))}',
            courses: appState.coursesForDate(
              weekStart.add(Duration(days: day - DateTime.monday)),
            ),
            onEdit: onEdit,
          ),
      ],
    );
  }
}

class _CourseSectionCard extends StatelessWidget {
  const _CourseSectionCard({
    required this.appState,
    required this.date,
    required this.title,
    required this.courses,
    required this.onEdit,
  });

  final AppState appState;
  final DateTime date;
  final String title;
  final List<Course> courses;
  final ValueChanged<Course> onEdit;

  @override
  Widget build(BuildContext context) {
    return FrostedPanel(
      enabled: appState.settings.frostedCards,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (courses.isEmpty)
              const Text('暂无课程')
            else
              ...courses.map(
                (Course course) => _CourseExpansionCard(
                  appState: appState,
                  course: course,
                  date: date,
                  onEdit: () => onEdit(course),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CourseExpansionCard extends StatefulWidget {
  const _CourseExpansionCard({
    required this.appState,
    required this.course,
    required this.date,
    required this.onEdit,
  });

  final AppState appState;
  final Course course;
  final DateTime date;
  final VoidCallback onEdit;

  @override
  State<_CourseExpansionCard> createState() => _CourseExpansionCardState();
}

class _CourseExpansionCardState extends State<_CourseExpansionCard> {
  bool _expanded = false;
  late final TextEditingController _gpaController;
  _CourseGradeMode _gradeMode = _CourseGradeMode.pending;

  @override
  void initState() {
    super.initState();
    _gpaController = TextEditingController();
    _refreshGradeText();
  }

  @override
  void didUpdateWidget(covariant _CourseExpansionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshGradeText();
  }

  void _refreshGradeText() {
    final GradeEntry? grade = widget.appState.gradeForCourse(widget.course);
    _gradeMode = switch (grade?.resultType) {
      GradeResultType.gpa => _CourseGradeMode.gpa,
      GradeResultType.pass => _CourseGradeMode.pass,
      GradeResultType.noPass => _CourseGradeMode.noPass,
      null => _CourseGradeMode.pending,
    };
    _gpaController.text =
        grade?.resultType == GradeResultType.gpa &&
            grade?.finalGradePoint != null
        ? grade!.finalGradePoint!.toStringAsFixed(2)
        : '';
  }

  @override
  void dispose() {
    _gpaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CourseSession session = _bestSessionForDate(
      widget.course,
      widget.date,
      widget.appState.currentTermStartMonday,
    );
    final String teacher = firstTeacher(widget.course.teacher);
    final String location = widget.course.location.isEmpty
        ? '地点待补充'
        : widget.course.location;
    final String fullWeekText =
        '${session.startWeek}-${session.endWeek}周 ${weekTypeLabel(session.weekType)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.course.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: widget.course.color.withValues(alpha: 0.32)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        onExpansionChanged: (bool value) => setState(() => _expanded = value),
        initiallyExpanded: _expanded,
        title: Text(
          widget.course.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${session.startPeriod}-${session.endPeriod} 节'),
            Text(location, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              teacher.isEmpty ? '教师待补充' : teacher,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        children: <Widget>[
          _DetailLine(
            label: '上课节次',
            value: '${session.startPeriod}-${session.endPeriod} 节',
          ),
          _DetailLine(label: '周次范围', value: fullWeekText),
          _DetailLine(label: '上课地点', value: location),
          _DetailLine(
            label: '任课教师',
            value: widget.course.teacher.isEmpty ? '-' : widget.course.teacher,
          ),
          _DetailLine(
            label: '课程代码',
            value: widget.course.code.isEmpty ? '-' : widget.course.code,
          ),
          _DetailLine(
            label: '学分',
            value: widget.course.credit.toStringAsFixed(1),
          ),
          const SizedBox(height: 8),
          Text('成绩录入', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _CourseGradeModeSelector(
            mode: _gradeMode,
            onChanged: (_CourseGradeMode value) {
              setState(() {
                _gradeMode = value;
                if (value != _CourseGradeMode.gpa) {
                  _gpaController.clear();
                }
              });
            },
          ),
          if (_gradeMode == _CourseGradeMode.gpa) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _gpaController,
                    decoration: const InputDecoration(
                      labelText: '绩点',
                      hintText: '留空表示删除成绩',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _saveGrade,
                  child: const Text('保存'),
                ),
              ],
            ),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _saveGrade,
                child: const Text('保存'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  CourseSession _bestSessionForDate(
    Course course,
    DateTime date,
    DateTime termStartMonday,
  ) {
    final List<CourseSession> matched =
        course.sessions
            .where((CourseSession s) => s.occursOn(date, termStartMonday))
            .toList()
          ..sort((CourseSession a, CourseSession b) {
            if (a.startPeriod != b.startPeriod) {
              return a.startPeriod.compareTo(b.startPeriod);
            }
            return a.endPeriod.compareTo(b.endPeriod);
          });
    if (matched.isNotEmpty) {
      return matched.first;
    }
    return course.sessions.first;
  }

  Future<void> _saveGrade() async {
    final String text = _gpaController.text.trim();
    double? gpa;
    if (_gradeMode == _CourseGradeMode.gpa) {
      gpa = text.isEmpty ? null : double.tryParse(text);
      if (text.isNotEmpty && gpa == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('绩点格式错误')));
        return;
      }
    }

    await widget.appState.runWithBusy(() {
      return widget.appState.setCourseGradeResult(
        course: widget.course,
        resultType: _gradeMode.toGradeResultType(),
        gradePoint: gpa,
      );
    });
  }

  Future<void> _delete() async {
    await widget.appState.runWithBusy(
      () => widget.appState.deleteCourse(widget.course.id),
    );
  }
}

extension on _CourseGradeMode {
  GradeResultType? toGradeResultType() => switch (this) {
    _CourseGradeMode.pending => null,
    _CourseGradeMode.gpa => GradeResultType.gpa,
    _CourseGradeMode.pass => GradeResultType.pass,
    _CourseGradeMode.noPass => GradeResultType.noPass,
  };
}

class _CourseGradeModeSelector extends StatelessWidget {
  const _CourseGradeModeSelector({required this.mode, required this.onChanged});

  final _CourseGradeMode mode;
  final ValueChanged<_CourseGradeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final (_CourseGradeMode value, String label) option
            in const <(_CourseGradeMode, String)>[
              (_CourseGradeMode.pending, '未出分'),
              (_CourseGradeMode.gpa, '绩点'),
              (_CourseGradeMode.pass, 'P'),
              (_CourseGradeMode.noPass, 'NP'),
            ])
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: option.$1 == _CourseGradeMode.noPass ? 0 : 6,
              ),
              child: _CourseGradeModeButton(
                label: option.$2,
                selected: option.$1 == mode,
                onTap: () => onChanged(option.$1),
              ),
            ),
          ),
      ],
    );
  }
}

class _CourseGradeModeButton extends StatelessWidget {
  const _CourseGradeModeButton({
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
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
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

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 72,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _WeekGridBody extends StatelessWidget {
  const _WeekGridBody({
    super.key,
    required this.appState,
    required this.weekStart,
    required this.onEdit,
  });

  final AppState appState;
  final DateTime weekStart;
  final ValueChanged<Course> onEdit;

  @override
  Widget build(BuildContext context) {
    final int maxPeriod = math.max(
      appState.settings.maxPeriodsPerDay,
      _maxPeriod(appState.courses),
    );
    final List<DateTime> days = List<DateTime>.generate(
      7,
      (int i) => weekStart.add(Duration(days: i)),
    );

    const double leftW = 56;
    const double dayW = 122;
    const double headH = 54;
    const double rowH = 56;

    final double width = leftW + dayW * 7;
    final double height = headH + rowH * maxPeriod;

    return FrostedPanel(
      enabled: appState.settings.frostedCards,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double viewportHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : 520;

          return SizedBox(
            height: viewportHeight,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    children: <Widget>[
                      _WeekGridBackground(
                        days: days,
                        maxPeriod: maxPeriod,
                        leftW: leftW,
                        dayW: dayW,
                        headH: headH,
                        rowH: rowH,
                      ),
                      for (int dayIndex = 0; dayIndex < 7; dayIndex++)
                        ..._dayBlocks(
                          date: days[dayIndex],
                          dayIndex: dayIndex,
                          leftW: leftW,
                          dayW: dayW,
                          headH: headH,
                          rowH: rowH,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _dayBlocks({
    required DateTime date,
    required int dayIndex,
    required double leftW,
    required double dayW,
    required double headH,
    required double rowH,
  }) {
    final List<_GridPlacement> placements = _layoutBlocks(date);
    return placements.map((_GridPlacement placement) {
      const double sidePadding = 4;
      const double laneGap = 3;
      final double contentLeft = leftW + dayIndex * dayW + sidePadding;
      final double contentWidth = dayW - sidePadding * 2;
      final double width =
          (contentWidth -
              laneGap *
                  (placement.laneCount > 0 ? placement.laneCount - 1 : 0)) /
          placement.laneCount;
      final double left = contentLeft + placement.laneIndex * (width + laneGap);
      final _GridBlock block = placement.block;
      return Positioned(
        left: left,
        top: headH + (block.start - 1) * rowH + 4,
        width: width,
        height: (block.end - block.start + 1) * rowH - 8,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onEdit(block.course),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: block.course.color.withValues(alpha: 0.26),
              border: Border.all(
                color: block.course.color.withValues(alpha: 0.6),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  block.course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('${block.start}-${block.end} 节', maxLines: 1),
                Text(
                  block.course.location.isEmpty
                      ? '地点待补充'
                      : block.course.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<_GridPlacement> _layoutBlocks(DateTime date) {
    final List<_GridBlock> blocks = _buildMergedBlocks(date);
    if (blocks.isEmpty) {
      return const <_GridPlacement>[];
    }

    blocks.sort((a, b) {
      final int byStart = a.start.compareTo(b.start);
      if (byStart != 0) {
        return byStart;
      }
      final int byEnd = a.end.compareTo(b.end);
      if (byEnd != 0) {
        return byEnd;
      }
      return a.course.name.compareTo(b.course.name);
    });

    final List<_GridPlacement> placements = <_GridPlacement>[];
    List<_GridBlock> currentGroup = <_GridBlock>[];
    int groupEnd = -1;

    for (final _GridBlock block in blocks) {
      if (currentGroup.isEmpty) {
        currentGroup = <_GridBlock>[block];
        groupEnd = block.end;
        continue;
      }
      if (block.start <= groupEnd) {
        currentGroup.add(block);
        groupEnd = math.max(groupEnd, block.end);
        continue;
      }
      placements.addAll(_layoutConflictGroup(currentGroup));
      currentGroup = <_GridBlock>[block];
      groupEnd = block.end;
    }

    if (currentGroup.isNotEmpty) {
      placements.addAll(_layoutConflictGroup(currentGroup));
    }
    return placements;
  }

  List<_GridPlacement> _layoutConflictGroup(List<_GridBlock> group) {
    if (group.length == 1) {
      return <_GridPlacement>[
        _GridPlacement(block: group.first, laneIndex: 0, laneCount: 1),
      ];
    }

    final List<_GridBlock> sorted = List<_GridBlock>.from(group)
      ..sort((a, b) {
        final int byStart = a.start.compareTo(b.start);
        if (byStart != 0) {
          return byStart;
        }
        return a.end.compareTo(b.end);
      });

    final List<int> laneEnds = <int>[];
    final List<({int laneIndex, _GridBlock block})> indexed =
        <({int laneIndex, _GridBlock block})>[];

    for (final _GridBlock block in sorted) {
      int laneIndex = -1;
      for (int i = 0; i < laneEnds.length; i++) {
        if (block.start > laneEnds[i]) {
          laneIndex = i;
          break;
        }
      }
      if (laneIndex == -1) {
        laneEnds.add(block.end);
        laneIndex = laneEnds.length - 1;
      } else {
        laneEnds[laneIndex] = block.end;
      }
      indexed.add((laneIndex: laneIndex, block: block));
    }

    final int laneCount = laneEnds.length;
    return indexed
        .map(
          (({int laneIndex, _GridBlock block}) item) => _GridPlacement(
            block: item.block,
            laneIndex: item.laneIndex,
            laneCount: laneCount,
          ),
        )
        .toList();
  }

  List<_GridBlock> _buildMergedBlocks(DateTime date) {
    final List<_GridBlock> raw = <_GridBlock>[];
    for (final Course course in appState.courses) {
      for (final CourseSession session in course.sessions) {
        if (!session.occursOn(date, appState.currentTermStartMonday)) {
          continue;
        }
        raw.add(
          _GridBlock(
            course: course,
            start: session.startPeriod,
            end: session.endPeriod,
          ),
        );
      }
    }

    raw.sort((a, b) {
      if (a.course.id != b.course.id) {
        return a.course.id.compareTo(b.course.id);
      }
      return a.start.compareTo(b.start);
    });

    final List<_GridBlock> merged = <_GridBlock>[];
    for (final _GridBlock item in raw) {
      if (merged.isEmpty) {
        merged.add(item);
        continue;
      }
      final _GridBlock last = merged.last;
      if (last.course.id == item.course.id && item.start <= last.end + 1) {
        merged[merged.length - 1] = last.copyWith(
          end: math.max(last.end, item.end),
        );
      } else {
        merged.add(item);
      }
    }
    merged.sort((a, b) => a.start.compareTo(b.start));
    return merged;
  }

  int _maxPeriod(List<Course> courses) {
    int value = 1;
    for (final Course c in courses) {
      for (final CourseSession s in c.sessions) {
        if (s.endPeriod > value) {
          value = s.endPeriod;
        }
      }
    }
    return value;
  }
}

class _WeekGridBackground extends StatelessWidget {
  const _WeekGridBackground({
    required this.days,
    required this.maxPeriod,
    required this.leftW,
    required this.dayW,
    required this.headH,
    required this.rowH,
  });

  final List<DateTime> days;
  final int maxPeriod;
  final double leftW;
  final double dayW;
  final double headH;
  final double rowH;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = Theme.of(context).colorScheme.outlineVariant;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: leftW,
              height: headH,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: const Text('节次'),
            ),
            for (int i = 0; i < 7; i++)
              Container(
                width: dayW,
                height: headH,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: borderColor),
                    bottom: BorderSide(color: borderColor),
                  ),
                ),
                child: Text(
                  '${weekdayLabel(i + 1)}\n${DateFormat('M/d').format(days[i])}',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        for (int period = 1; period <= maxPeriod; period++)
          Row(
            children: <Widget>[
              Container(
                width: leftW,
                height: rowH,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Text('$period'),
              ),
              for (int i = 0; i < 7; i++)
                Container(
                  width: dayW,
                  height: rowH,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: borderColor),
                      bottom: BorderSide(color: borderColor),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _GridBlock {
  const _GridBlock({
    required this.course,
    required this.start,
    required this.end,
  });

  final Course course;
  final int start;
  final int end;

  _GridBlock copyWith({Course? course, int? start, int? end}) {
    return _GridBlock(
      course: course ?? this.course,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

class _GridPlacement {
  const _GridPlacement({
    required this.block,
    required this.laneIndex,
    required this.laneCount,
  });

  final _GridBlock block;
  final int laneIndex;
  final int laneCount;
}
