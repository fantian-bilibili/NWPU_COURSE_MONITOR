import 'course_session.dart';
import 'app_settings.dart';

DateTime mondayOf(DateTime date) {
  final DateTime normalized = DateTime(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

String weekdayLabel(int weekday) => switch (weekday) {
  DateTime.monday => '周一',
  DateTime.tuesday => '周二',
  DateTime.wednesday => '周三',
  DateTime.thursday => '周四',
  DateTime.friday => '周五',
  DateTime.saturday => '周六',
  DateTime.sunday => '周日',
  _ => '未知',
};

String weekTypeLabel(WeekType weekType) => switch (weekType) {
  WeekType.all => '每周',
  WeekType.odd => '单周',
  WeekType.even => '双周',
};

String firstTeacher(String teacher) {
  final String normalized = teacher.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final List<String> parts = normalized
      .split(RegExp(r'[、,，/;；\s]+'))
      .where((String item) => item.trim().isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return normalized;
  }
  return parts.first.trim();
}

List<String> buildPeriodStartTimes({
  required String dayStartTime,
  required int periodDurationMinutes,
  required int maxPeriodsPerDay,
}) {
  final String startText = normalizeTimeText(dayStartTime, fallback: '08:00');
  final int duration = periodDurationMinutes.clamp(30, 180);
  final int maxPeriods = maxPeriodsPerDay.clamp(1, 24);

  final int? startMinutes = _timeTextToMinutes(startText);
  if (startMinutes == null) {
    return AppSettings.defaults().periodStartTimes;
  }

  return List<String>.generate(maxPeriods, (int index) {
    final int total = startMinutes + index * duration;
    return _minutesToTimeText(total);
  });
}

List<String> buildPeriodEndTimes({
  required List<String> periodStartTimes,
  required int periodDurationMinutes,
  required String dayEndTime,
}) {
  final int duration = periodDurationMinutes.clamp(30, 180);
  final int? dayEnd = _timeTextToMinutes(
    normalizeTimeText(dayEndTime, fallback: '22:00'),
  );
  final List<String> result = <String>[];
  for (int i = 0; i < periodStartTimes.length; i++) {
    final int? start = _timeTextToMinutes(periodStartTimes[i]);
    if (start == null) {
      result.add('08:50');
      continue;
    }
    final int? nextStart = i + 1 < periodStartTimes.length
        ? _timeTextToMinutes(periodStartTimes[i + 1])
        : null;
    int endMinutes = start + duration;
    if (nextStart != null) {
      endMinutes = nextStart;
    } else if (dayEnd != null && dayEnd > start) {
      endMinutes = dayEnd;
    }
    if (endMinutes <= start) {
      endMinutes = start + duration;
    }
    result.add(_minutesToTimeText(endMinutes));
  }
  return result;
}

int? periodStartMinutesAt(AppSettings settings, int period) {
  if (period <= 0) {
    return null;
  }
  if (period - 1 < settings.periodStartTimes.length) {
    final int? fromSetting = _timeTextToMinutes(
      settings.periodStartTimes[period - 1],
    );
    if (fromSetting != null) {
      return fromSetting;
    }
  }
  final int? dayStart = _timeTextToMinutes(settings.dayStartTime);
  if (dayStart == null) {
    return null;
  }
  return dayStart + (period - 1) * settings.periodDurationMinutes;
}

int? periodEndMinutesAt(AppSettings settings, int period) {
  if (period <= 0) {
    return null;
  }

  final int? periodStart = periodStartMinutesAt(settings, period);
  if (period - 1 < settings.periodEndTimes.length) {
    final int? configured = _timeTextToMinutes(
      settings.periodEndTimes[period - 1],
    );
    if (configured != null) {
      if (periodStart == null || configured > periodStart) {
        return configured;
      }
    }
  }

  final int? nextStart = periodStartMinutesAt(settings, period + 1);
  if (nextStart != null) {
    return nextStart;
  }
  if (periodStart == null) {
    return null;
  }
  return periodStart + settings.periodDurationMinutes;
}

DateTime? sessionStartAt({
  required DateTime date,
  required CourseSession session,
  required AppSettings settings,
}) {
  final int? minutes = periodStartMinutesAt(settings, session.startPeriod);
  if (minutes == null) {
    return null;
  }
  final int safe = minutes.clamp(0, 24 * 60 - 1);
  return DateTime(date.year, date.month, date.day, safe ~/ 60, safe % 60);
}

DateTime? sessionEndAt({
  required DateTime date,
  required CourseSession session,
  required AppSettings settings,
}) {
  final int? minutes = periodEndMinutesAt(settings, session.endPeriod);
  if (minutes == null) {
    return null;
  }
  final int safe = minutes.clamp(0, 24 * 60 - 1);
  return DateTime(date.year, date.month, date.day, safe ~/ 60, safe % 60);
}

String normalizeTimeText(String? value, {String fallback = '08:00'}) {
  final String raw = (value ?? '').trim();
  final RegExp format = RegExp(r'^(\d{1,2}):(\d{1,2})$');
  final RegExpMatch? match = format.firstMatch(raw);
  if (match == null) {
    return fallback;
  }
  final int? hour = int.tryParse(match.group(1)!);
  final int? minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) {
    return fallback;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return fallback;
  }
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

int? timeTextToMinutes(String text) => _timeTextToMinutes(text);

List<String> normalizeTimeList({
  required List<String> source,
  required List<String> fallback,
  required int count,
  required String fallbackValue,
}) {
  final List<String> normalized = <String>[];
  for (final String value in source) {
    final String safe = normalizeTimeText(value, fallback: '');
    if (safe.isEmpty) {
      continue;
    }
    normalized.add(safe);
    if (normalized.length >= count) {
      return normalized.take(count).toList();
    }
  }

  for (final String value in fallback) {
    if (normalized.length >= count) {
      break;
    }
    final String safe = normalizeTimeText(value, fallback: '');
    if (safe.isNotEmpty) {
      normalized.add(safe);
    }
  }

  while (normalized.length < count) {
    normalized.add(fallbackValue);
  }
  return normalized.take(count).toList();
}

List<String> normalizeEndTimeList({
  required List<String> source,
  required List<String> fallback,
  required List<String> startTimes,
  required int periodDurationMinutes,
}) {
  final int count = startTimes.length;
  final List<String> normalized = normalizeTimeList(
    source: source,
    fallback: fallback,
    count: count,
    fallbackValue: '08:50',
  );
  for (int i = 0; i < count; i++) {
    final int? start = _timeTextToMinutes(startTimes[i]);
    final int? end = _timeTextToMinutes(normalized[i]);
    if (start == null || end == null || end <= start) {
      normalized[i] = _minutesToTimeText(
        (start ?? 8 * 60) + periodDurationMinutes.clamp(30, 180),
      );
    }
  }
  return normalized;
}

String _minutesToTimeText(int totalMinutes) {
  final int normalized = totalMinutes.clamp(0, 24 * 60 - 1);
  final int hour = normalized ~/ 60;
  final int minute = normalized % 60;
  return '${hour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')}';
}

int? _timeTextToMinutes(String text) {
  final List<String> parts = text.split(':');
  if (parts.length != 2) {
    return null;
  }
  final int? hour = int.tryParse(parts[0]);
  final int? minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) {
    return null;
  }
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    return null;
  }
  return hour * 60 + minute;
}
