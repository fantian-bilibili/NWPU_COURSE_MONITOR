import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/models.dart';
import '../../../state/app_state.dart';

class WindowsMiniSchedulePage extends StatefulWidget {
  const WindowsMiniSchedulePage({
    super.key,
    required this.appState,
    required this.onExitMiniMode,
  });

  final AppState appState;
  final Future<void> Function() onExitMiniMode;

  @override
  State<WindowsMiniSchedulePage> createState() =>
      _WindowsMiniSchedulePageState();
}

class _WindowsMiniSchedulePageState extends State<WindowsMiniSchedulePage> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool? _lastDarkMode;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) {
        return;
      }
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (_lastDarkMode == dark) {
      return;
    }
    _lastDarkMode = dark;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.appState.syncWindowsMiniTheme(dark);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final AppState state = widget.appState;
    final DateTime today = DateTime(_now.year, _now.month, _now.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));

    final List<_MiniCourseItem> todayItems = _coursesForDate(
      state: state,
      day: today,
    );
    final List<_MiniCourseItem> tomorrowItems = _coursesForDate(
      state: state,
      day: tomorrow,
    );

    final int remaining = todayItems
        .where((item) => item.status != _MiniCourseStatus.done)
        .length;
    final bool allTodayDone = todayItems.isNotEmpty && remaining == 0;
    final bool showTodayList = todayItems.isNotEmpty && !allTodayDone;
    final int weekIndex = weekOfTerm(today, state.currentTermStartMonday);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => state.startWindowsMiniDrag(),
              child: _GlassPanel(
                blur: 22,
                radius: 16,
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${DateFormat('M.d EEEE', 'zh_CN').format(today)} · 第$weekIndex周',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: dark ? const Color(0xFFF4F7FB) : null,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            showTodayList
                                ? '今日剩余 $remaining 节课（按住此区域可拖动）'
                                : (allTodayDone
                                      ? '今日课程已结束（按住此区域可拖动）'
                                      : '今日无课（按住此区域可拖动）'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: dark ? const Color(0xCDD7E5F1) : null,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: '返回完整模式',
                      style: IconButton.styleFrom(
                        backgroundColor: dark ? const Color(0xCC314555) : null,
                        foregroundColor: dark ? const Color(0xFFF4F7FB) : null,
                      ),
                      onPressed: () async => widget.onExitMiniMode(),
                      icon: const Icon(Icons.open_in_full, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _GlassPanel(
                blur: 24,
                radius: 18,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (showTodayList) ...<Widget>[
                        const _SectionTitle(title: '今日课程', subtitle: '按时间排序'),
                        const SizedBox(height: 6),
                        _VerticalCapsules(
                          items: todayItems,
                          showStatus: true,
                          maxVisible: 8,
                        ),
                      ] else ...<Widget>[
                        _SectionTitle(
                          title: '今日课程',
                          subtitle: allTodayDone ? '今日课程已全部完成' : '今天没有课程安排',
                        ),
                        const SizedBox(height: 8),
                        _CapsuleCard(
                          tone: const Color(0xFF7A8A9F),
                          title: allTodayDone ? '今日课程已结束' : '今日无课',
                          meta: allTodayDone ? '辛苦了，今天课程全部结束。' : '今天无课，祝你学习顺利。',
                          badge: null,
                        ),
                      ],
                      const SizedBox(height: 12),
                      const _SectionTitle(title: '明日课程', subtitle: '预览明天的排课'),
                      const SizedBox(height: 6),
                      _VerticalCapsules(
                        items: tomorrowItems,
                        showStatus: false,
                        maxVisible: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_MiniCourseItem> _coursesForDate({
    required AppState state,
    required DateTime day,
  }) {
    final List<_MiniCourseItem> result = <_MiniCourseItem>[];
    for (final Course course in state.courses) {
      for (final CourseSession session in course.sessions) {
        if (!session.occursOn(day, state.currentTermStartMonday)) {
          continue;
        }
        final DateTime? startAt = _sessionStartAt(
          date: day,
          session: session,
          settings: state.settings,
        );
        final DateTime? endAt = _sessionEndAt(
          date: day,
          session: session,
          settings: state.settings,
        );
        result.add(
          _MiniCourseItem(
            course: course,
            session: session,
            startAt: startAt,
            endAt: endAt,
            status: _resolveStatus(now: _now, startAt: startAt, endAt: endAt),
          ),
        );
      }
    }
    result.sort((a, b) {
      final int byPeriod = a.session.startPeriod.compareTo(
        b.session.startPeriod,
      );
      if (byPeriod != 0) {
        return byPeriod;
      }
      return a.course.name.compareTo(b.course.name);
    });
    return result;
  }

  _MiniCourseStatus _resolveStatus({
    required DateTime now,
    required DateTime? startAt,
    required DateTime? endAt,
  }) {
    if (startAt == null || endAt == null) {
      return _MiniCourseStatus.upcoming;
    }
    if (now.isBefore(startAt)) {
      return _MiniCourseStatus.upcoming;
    }
    if (now.isAtSameMomentAs(endAt) || now.isAfter(endAt)) {
      return _MiniCourseStatus.done;
    }
    return _MiniCourseStatus.live;
  }

  DateTime? _sessionStartAt({
    required DateTime date,
    required CourseSession session,
    required AppSettings settings,
  }) {
    return sessionStartAt(date: date, session: session, settings: settings);
  }

  DateTime? _sessionEndAt({
    required DateTime date,
    required CourseSession session,
    required AppSettings settings,
  }) {
    return sessionEndAt(date: date, session: session, settings: settings);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: dark ? const Color(0xFFF2F5FA) : null,
          ),
        ),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: dark ? const Color(0xB8C7D4E2) : null,
          ),
        ),
      ],
    );
  }
}

class _VerticalCapsules extends StatelessWidget {
  const _VerticalCapsules({
    required this.items,
    required this.showStatus,
    required this.maxVisible,
  });

  final List<_MiniCourseItem> items;
  final bool showStatus;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _GlassPanel(
        blur: 16,
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: const Text('暂无课程'),
      );
    }

    final int visible = items.length > maxVisible ? maxVisible : items.length;
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < visible; i++) {
      final _MiniCourseItem item = items[i];
      final Color tone = switch (item.status) {
        _MiniCourseStatus.done => const Color(0xFF8A96A8),
        _MiniCourseStatus.live => const Color(0xFF2074DB),
        _MiniCourseStatus.upcoming => const Color(0xFFCC4E79),
      };
      children.add(
        _CapsuleCard(
          tone: tone,
          title: _truncate(item.course.name, 20),
          meta:
              '${_formatRange(item)}  ${_truncate(item.course.location.isEmpty ? '地点待定' : item.course.location, 16)}'
              '${item.course.teacher.trim().isEmpty ? '' : '  ${_truncate(firstTeacher(item.course.teacher), 8)}'}',
          badge: showStatus ? _statusLabel(item.status) : null,
        ),
      );
      if (i != visible - 1) {
        children.add(const SizedBox(height: 7));
      }
    }

    if (items.length > visible) {
      children.add(const SizedBox(height: 7));
      children.add(
        Text(
          '等${items.length - visible}节课',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return Column(children: children);
  }

  String _formatRange(_MiniCourseItem item) {
    if (item.startAt != null && item.endAt != null) {
      return '${_hm(item.startAt!)}-${_hm(item.endAt!)}';
    }
    return '${item.session.startPeriod}-${item.session.endPeriod}节';
  }

  String _hm(DateTime value) {
    final String h = value.hour.toString().padLeft(2, '0');
    final String m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _statusLabel(_MiniCourseStatus status) => switch (status) {
    _MiniCourseStatus.done => '已下课',
    _MiniCourseStatus.live => '上课中',
    _MiniCourseStatus.upcoming => '未上课',
  };

  String _truncate(String text, int maxChars) {
    final String v = text.trim();
    if (v.length <= maxChars) {
      return v;
    }
    return '${v.substring(0, maxChars)}...';
  }
}

class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard({
    required this.tone,
    required this.title,
    required this.meta,
    required this.badge,
  });

  final Color tone;
  final String title;
  final String meta;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return _GlassPanel(
      blur: 18,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: dark ? const Color(0xFFF3F7FB) : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: dark ? const Color(0xD5DDE8F3) : null,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 58),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: dark ? 0.22 : 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.padding,
    required this.radius,
    required this.blur,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: dark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0x7A111925), Color(0x661A2331)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0x2AFFFFFF), Color(0x1EFFFFFF)],
                  ),
            color: dark ? const Color(0x5A111925) : const Color(0x24FFFFFF),
            border: Border.all(
              color: dark ? const Color(0x22F4F8FF) : const Color(0x70FFFFFF),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: dark ? const Color(0x24000000) : const Color(0x12A0B4C8),
                blurRadius: dark ? 24 : 18,
                offset: const Offset(0, 10),
              ),
            ],
            borderRadius: BorderRadius.circular(radius),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _MiniCourseItem {
  const _MiniCourseItem({
    required this.course,
    required this.session,
    required this.startAt,
    required this.endAt,
    required this.status,
  });

  final Course course;
  final CourseSession session;
  final DateTime? startAt;
  final DateTime? endAt;
  final _MiniCourseStatus status;
}

enum _MiniCourseStatus { done, live, upcoming }
