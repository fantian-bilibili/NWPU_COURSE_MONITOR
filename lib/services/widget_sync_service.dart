import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../models/models.dart';

class WidgetSyncService {
  static const String _qualifiedProviderName =
      'com.nwpu.nwpu_course_monitor.CourseTodayWidgetProvider';
  static const String _iosWidgetKind = 'CourseTodayWidget';
  static const int _maxCards = 4;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> sync({
    required List<Course> courses,
    required AppSettings settings,
    required DateTime now,
  }) async {
    if (!_supported) {
      return;
    }

    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));

    final List<_WidgetCourseItem> todayItems = _coursesForDate(
      courses: courses,
      settings: settings,
      day: today,
      now: now,
    );
    final List<_WidgetCourseItem> tomorrowItems = _coursesForDate(
      courses: courses,
      settings: settings,
      day: tomorrow,
      now: now,
    );

    final int weekIndex = max(1, weekOfTerm(today, settings.termStartMonday));
    final String weekPrefix =
        '${today.month}.${today.day} '
        '${_weekdayLabel(today.weekday)}';
    final String headerLeft = settings.showWeekSummaryInWidget
        ? '$weekPrefix · 第$weekIndex周'
        : weekPrefix;
    await HomeWidget.saveWidgetData<String>('widget_header_left', headerLeft);

    final int remainingCount = todayItems
        .where((item) => item.status != _WidgetCourseStatus.done)
        .length;
    final bool allTodayDone = todayItems.isNotEmpty && remainingCount == 0;
    final bool showTodayMode = todayItems.isNotEmpty && !allTodayDone;

    if (showTodayMode) {
      await HomeWidget.saveWidgetData<String>('widget_mode', 'today');
      await HomeWidget.saveWidgetData<String>(
        'widget_header_right',
        '还有 $remainingCount 节课',
      );
      await _saveTodayCards(todayItems);
    } else {
      await HomeWidget.saveWidgetData<String>('widget_mode', 'empty');
      await HomeWidget.saveWidgetData<String>(
        'widget_header_right',
        allTodayDone ? '今日课程已结束' : '今日无课',
      );
      await _saveTodayCards(const <_WidgetCourseItem>[]);

      final List<String> blessings = allTodayDone
          ? <String>[
              '今天课程已经全部结束，辛苦了。',
              '今日课程任务完成，记得休息一下。',
              '课程都上完了，适合做个简短复盘。',
              '今天的课已经结束，保持好状态。',
              '辛苦一天，别忘了补水和活动。',
              '今日课程全部完成，晚上也要稳步推进。',
              '今天课堂部分收官，继续保持节奏。',
            ]
          : <String>[
              '今天没有课程，祝你状态在线。',
              '无课日也别忘了安排运动和休息。',
              '今天适合推进计划中的重点任务。',
              '今天没课，适合做一次高质量自习。',
              '愿你今天专注顺利，事事有回响。',
              '今天课程清空，给自己一点正反馈。',
              '没有课程的一天，也能很有收获。',
            ];
      final int idx = Random(
        now.millisecondsSinceEpoch,
      ).nextInt(blessings.length);

      await HomeWidget.saveWidgetData<String>(
        'widget_empty_left_title',
        allTodayDone ? '今日课程已结束' : '今日无课',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_empty_left_body',
        blessings[idx],
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_empty_right_title',
        '明日课程',
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_empty_right_body',
        tomorrowItems.isEmpty
            ? '明日也无课'
            : _buildTomorrowLines(
                tomorrowItems,
                maxLines: 3,
                showOverflowSummary: true,
              ),
      );
    }

    bool? updated;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      updated = await HomeWidget.updateWidget(
        iOSName: _iosWidgetKind,
        name: _iosWidgetKind,
      );
    } else {
      updated = await HomeWidget.updateWidget(
        qualifiedAndroidName: _qualifiedProviderName,
        androidName: 'CourseTodayWidgetProvider',
      );
      updated ??= await HomeWidget.updateWidget(
        androidName: 'CourseTodayWidgetProvider',
      );
      updated ??= await HomeWidget.updateWidget(
        name: 'CourseTodayWidgetProvider',
      );
    }
    if (updated != true) {
      throw Exception('组件更新失败，请检查桌面组件是否已添加。');
    }
  }

  Future<void> _saveTodayCards(List<_WidgetCourseItem> items) async {
    final int visibleCount = min(items.length, _maxCards);

    for (int i = 0; i < _maxCards; i++) {
      final bool visible = i < visibleCount;
      await HomeWidget.saveWidgetData<bool>(
        'widget_card_${i}_visible',
        visible,
      );
      if (!visible) {
        await HomeWidget.saveWidgetData<String>('widget_card_${i}_title', '');
        await HomeWidget.saveWidgetData<String>('widget_card_${i}_meta', '');
        await HomeWidget.saveWidgetData<String>('widget_card_${i}_status', '');
        await HomeWidget.saveWidgetData<String>('widget_card_${i}_tone', '');
        continue;
      }

      final _WidgetCourseItem item = items[i];
      await HomeWidget.saveWidgetData<String>(
        'widget_card_${i}_title',
        _truncate(item.course.name, maxChars: 12),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_card_${i}_meta',
        _buildMetaLine(item),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_card_${i}_status',
        _statusLabel(item.status),
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_card_${i}_tone',
        _toneLabel(item.status),
      );
    }

    final int overflow = items.length - _maxCards;
    final bool hasOverflow = overflow > 0;
    await HomeWidget.saveWidgetData<bool>(
      'widget_overflow_visible',
      hasOverflow,
    );
    await HomeWidget.saveWidgetData<String>(
      'widget_overflow_text',
      hasOverflow ? '等 $overflow 节课' : '',
    );
  }

  List<_WidgetCourseItem> _coursesForDate({
    required List<Course> courses,
    required AppSettings settings,
    required DateTime day,
    required DateTime now,
  }) {
    final List<_WidgetCourseItem> result = <_WidgetCourseItem>[];
    for (final Course course in courses) {
      for (final CourseSession session in course.sessions) {
        if (!session.occursOn(day, settings.termStartMonday)) {
          continue;
        }
        final DateTime? startAt = _sessionStartAt(
          date: day,
          session: session,
          settings: settings,
        );
        final DateTime? endAt = _sessionEndAt(
          date: day,
          session: session,
          settings: settings,
        );
        result.add(
          _WidgetCourseItem(
            course: course,
            session: session,
            startAt: startAt,
            endAt: endAt,
            status: _resolveStatus(now: now, startAt: startAt, endAt: endAt),
          ),
        );
      }
    }

    result.sort((a, b) {
      final int byStart = a.session.startPeriod.compareTo(
        b.session.startPeriod,
      );
      if (byStart != 0) {
        return byStart;
      }
      return a.course.name.compareTo(b.course.name);
    });
    return result;
  }

  _WidgetCourseStatus _resolveStatus({
    required DateTime now,
    required DateTime? startAt,
    required DateTime? endAt,
  }) {
    if (startAt == null || endAt == null) {
      return _WidgetCourseStatus.upcoming;
    }
    if (now.isBefore(startAt)) {
      return _WidgetCourseStatus.upcoming;
    }
    if (now.isAtSameMomentAs(endAt) || now.isAfter(endAt)) {
      return _WidgetCourseStatus.done;
    }
    return _WidgetCourseStatus.live;
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

  String _buildMetaLine(_WidgetCourseItem item) {
    final String time = _formatTimeRange(item);
    final String location = item.course.location.trim().isEmpty
        ? '地点待定'
        : _truncate(item.course.location.trim(), maxChars: 12);
    return '$time  $location';
  }

  String _formatTimeRange(_WidgetCourseItem item) {
    if (item.startAt != null && item.endAt != null) {
      return '${_formatHm(item.startAt!)}-${_formatHm(item.endAt!)}';
    }
    return '${item.session.startPeriod}-${item.session.endPeriod}节';
  }

  String _formatHm(DateTime value) {
    final String h = value.hour.toString().padLeft(2, '0');
    final String m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _buildTomorrowLines(
    List<_WidgetCourseItem> items, {
    required int maxLines,
    required bool showOverflowSummary,
  }) {
    if (items.isEmpty) {
      return '';
    }
    final int safeMaxLines = max(1, maxLines);
    final int total = items.length;
    final int reservedSummary = showOverflowSummary && total > safeMaxLines
        ? 1
        : 0;
    final int visibleLines = (safeMaxLines - reservedSummary).clamp(1, total);

    final List<String> lines = <String>[];
    for (int i = 0; i < visibleLines; i++) {
      final _WidgetCourseItem item = items[i];
      final String title = _truncate(item.course.name, maxChars: 8);
      lines.add('${_formatTimeRange(item)}  $title');
    }

    if (reservedSummary == 1) {
      lines.add('共$total节课');
    }
    return lines.join('\n');
  }

  String _statusLabel(_WidgetCourseStatus status) => switch (status) {
    _WidgetCourseStatus.done => '已下课',
    _WidgetCourseStatus.live => '上课中',
    _WidgetCourseStatus.upcoming => '未上课',
  };

  String _toneLabel(_WidgetCourseStatus status) => switch (status) {
    _WidgetCourseStatus.done => 'done',
    _WidgetCourseStatus.live => 'live',
    _WidgetCourseStatus.upcoming => 'upcoming',
  };

  String _weekdayLabel(int weekday) => switch (weekday) {
    DateTime.monday => '周一',
    DateTime.tuesday => '周二',
    DateTime.wednesday => '周三',
    DateTime.thursday => '周四',
    DateTime.friday => '周五',
    DateTime.saturday => '周六',
    DateTime.sunday => '周日',
    _ => '未知',
  };

  String _truncate(String text, {required int maxChars}) {
    final String trimmed = text.trim();
    if (trimmed.length <= maxChars) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxChars)}…';
  }
}

class _WidgetCourseItem {
  const _WidgetCourseItem({
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
  final _WidgetCourseStatus status;
}

enum _WidgetCourseStatus { done, live, upcoming }
