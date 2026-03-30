import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/models.dart';
import '../../../state/app_state.dart';
import '../../widgets/frosted_panel.dart';

class GpaPage extends StatelessWidget {
  const GpaPage({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final NumberFormat formatter = NumberFormat('0.00');
    final List<GradeEntry> graded =
        appState.grades.where((GradeEntry grade) => grade.isReleased).toList()
          ..sort(
            (GradeEntry a, GradeEntry b) =>
                a.courseName.compareTo(b.courseName),
          );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, _gpaBottomInset(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FrostedPanel(
            enabled: appState.settings.frostedCards,
            padding: EdgeInsets.zero,
            radius: 28,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '绩点总览',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          appState.currentSemester.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SummaryCountCard(count: graded.length),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: MetricTile(
                  label: '当前学分绩',
                  value: formatter.format(appState.currentGpa),
                  icon: Icons.timeline_rounded,
                  accent: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: '已计入学分',
                  value: formatter.format(appState.earnedCredits),
                  icon: Icons.school_outlined,
                  accent: const Color(0xFF7D6AAF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FrostedPanel(
              enabled: appState.settings.frostedCards,
              padding: EdgeInsets.zero,
              radius: 28,
              child: graded.isEmpty
                  ? _EmptyGradesState(theme: theme)
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        _gpaBottomInset(context),
                      ),
                      itemCount: graded.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final GradeEntry grade = graded[index];
                        final Course? course = _findCourseByGrade(grade);
                        final String code = (course?.code ?? '').trim();
                        return _GradeCard(
                          courseName: grade.courseName,
                          credit: grade.credit,
                          resultLabel: grade.resultSummary,
                          resultCaption: grade.resultType == GradeResultType.gpa
                              ? '绩点'
                              : '结果',
                          code: code,
                          accent: course?.color ?? theme.colorScheme.primary,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Course? _findCourseByGrade(GradeEntry grade) {
    if (grade.courseId != null) {
      for (final Course course in appState.courses) {
        if (course.id == grade.courseId) {
          return course;
        }
      }
    }
    for (final Course course in appState.courses) {
      if (course.name.trim() == grade.courseName.trim()) {
        return course;
      }
    }
    return null;
  }
}

double _gpaBottomInset(BuildContext context) {
  final bool mobile = MediaQuery.sizeOf(context).width < 720;
  if (!mobile) {
    return 12;
  }
  return MediaQuery.paddingOf(context).bottom + 108;
}

class _SummaryCountCard extends StatelessWidget {
  const _SummaryCountCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '已出分课程',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: Text(
                    '$count',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Text(
                '门',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradeCard extends StatelessWidget {
  const _GradeCard({
    required this.courseName,
    required this.credit,
    required this.resultLabel,
    required this.resultCaption,
    required this.code,
    required this.accent,
  });

  final String courseName;
  final double credit;
  final String resultLabel;
  final String resultCaption;
  final String code;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String safeCode = code.isEmpty ? '未填写' : code;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.52 : 0.82,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 6,
            height: 56,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  courseName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _InfoChip(label: '学分 ${credit.toStringAsFixed(1)}'),
                    _InfoChip(label: '课程代码 $safeCode'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(resultCaption, style: theme.textTheme.bodySmall),
              const SizedBox(height: 4),
              Text(
                resultLabel,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}

class _EmptyGradesState extends StatelessWidget {
  const _EmptyGradesState({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.assignment_turned_in_outlined,
                size: 28,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '当前还没有已出分课程',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
