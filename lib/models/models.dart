import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

enum WeekType { all, odd, even }

extension WeekTypeCodec on WeekType {
  String get jsonValue => switch (this) {
    WeekType.all => 'all',
    WeekType.odd => 'odd',
    WeekType.even => 'even',
  };

  static WeekType fromJson(String? value) => switch (value) {
    'odd' => WeekType.odd,
    'even' => WeekType.even,
    _ => WeekType.all,
  };
}

class CourseSession {
  const CourseSession({
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.startWeek,
    required this.endWeek,
    this.weekType = WeekType.all,
  });

  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final int startWeek;
  final int endWeek;
  final WeekType weekType;

  CourseSession copyWith({
    int? weekday,
    int? startPeriod,
    int? endPeriod,
    int? startWeek,
    int? endWeek,
    WeekType? weekType,
  }) {
    return CourseSession(
      weekday: weekday ?? this.weekday,
      startPeriod: startPeriod ?? this.startPeriod,
      endPeriod: endPeriod ?? this.endPeriod,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      weekType: weekType ?? this.weekType,
    );
  }

  bool occursOn(DateTime date, DateTime termStartMonday) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    final DateTime start = DateTime(
      termStartMonday.year,
      termStartMonday.month,
      termStartMonday.day,
    );
    if (day.isBefore(start)) {
      return false;
    }
    if (date.weekday != weekday) {
      return false;
    }
    final int weekIndex = weekOfTerm(day, start);
    if (weekIndex < startWeek || weekIndex > endWeek) {
      return false;
    }
    return switch (weekType) {
      WeekType.all => true,
      WeekType.odd => weekIndex.isOdd,
      WeekType.even => weekIndex.isEven,
    };
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'weekday': weekday,
    'startPeriod': startPeriod,
    'endPeriod': endPeriod,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'weekType': weekType.jsonValue,
  };

  factory CourseSession.fromJson(Map<String, dynamic> json) {
    return CourseSession(
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
      startPeriod: (json['startPeriod'] as num?)?.toInt() ?? 1,
      endPeriod: (json['endPeriod'] as num?)?.toInt() ?? 2,
      startWeek: (json['startWeek'] as num?)?.toInt() ?? 1,
      endWeek: (json['endWeek'] as num?)?.toInt() ?? 20,
      weekType: WeekTypeCodec.fromJson(json['weekType'] as String?),
    );
  }
}

class Course {
  Course({
    String? id,
    required this.name,
    this.semesterId = '',
    this.code = '',
    this.teacher = '',
    this.location = '',
    this.credit = 0,
    this.colorValue = 0xFF4A90E2,
    required this.sessions,
  }) : id = id ?? _uuid.v4();

  final String id;
  final String name;
  final String semesterId;
  final String code;
  final String teacher;
  final String location;
  final double credit;
  final int colorValue;
  final List<CourseSession> sessions;

  Color get color => Color(colorValue);

  Course copyWith({
    String? id,
    String? name,
    String? semesterId,
    String? code,
    String? teacher,
    String? location,
    double? credit,
    int? colorValue,
    List<CourseSession>? sessions,
  }) {
    return Course(
      id: id ?? this.id,
      name: name ?? this.name,
      semesterId: semesterId ?? this.semesterId,
      code: code ?? this.code,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      credit: credit ?? this.credit,
      colorValue: colorValue ?? this.colorValue,
      sessions: sessions ?? this.sessions,
    );
  }

  String signature() {
    final CourseSession base = sessions.first;
    return '${semesterId.trim()}|${name.trim()}|${code.trim()}|${teacher.trim()}|${location.trim()}|'
        '${base.weekday}|${base.startPeriod}|${base.endPeriod}|'
        '${base.startWeek}|${base.endWeek}|${base.weekType.jsonValue}';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'semesterId': semesterId,
    'code': code,
    'teacher': teacher,
    'location': location,
    'credit': credit,
    'colorValue': colorValue,
    'sessions': sessions.map((CourseSession e) => e.toJson()).toList(),
  };

  factory Course.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawSessions =
        (json['sessions'] as List<dynamic>?) ?? <dynamic>[];
    return Course(
      id: json['id'] as String?,
      name: (json['name'] as String?)?.trim() ?? '未命名课程',
      semesterId: (json['semesterId'] as String?)?.trim() ?? '',
      code: (json['code'] as String?)?.trim() ?? '',
      teacher: (json['teacher'] as String?)?.trim() ?? '',
      location: (json['location'] as String?)?.trim() ?? '',
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF4A90E2,
      sessions: rawSessions
          .whereType<Map<String, dynamic>>()
          .map(CourseSession.fromJson)
          .toList(),
    );
  }
}

enum GradeResultType { gpa, pass, noPass }

extension GradeResultTypeCodec on GradeResultType {
  String get jsonValue => switch (this) {
    GradeResultType.gpa => 'gpa',
    GradeResultType.pass => 'pass',
    GradeResultType.noPass => 'no_pass',
  };

  String get shortLabel => switch (this) {
    GradeResultType.gpa => '绩点',
    GradeResultType.pass => 'P',
    GradeResultType.noPass => 'NP',
  };

  String get displayLabel => switch (this) {
    GradeResultType.gpa => '绩点课',
    GradeResultType.pass => '通过',
    GradeResultType.noPass => '未通过',
  };

  static GradeResultType fromJson(String? value) => switch (value) {
    'pass' => GradeResultType.pass,
    'no_pass' || 'np' => GradeResultType.noPass,
    _ => GradeResultType.gpa,
  };
}

class GradeEntry {
  GradeEntry({
    String? id,
    this.courseId,
    this.semesterId = '',
    required this.courseName,
    required this.credit,
    this.score,
    this.gradePoint,
    this.resultType = GradeResultType.gpa,
    this.counted = true,
  }) : id = id ?? _uuid.v4();

  final String id;
  final String? courseId;
  final String semesterId;
  final String courseName;
  final double credit;
  final double? score;
  final double? gradePoint;
  final GradeResultType resultType;
  final bool counted;

  bool get isReleased => switch (resultType) {
    GradeResultType.gpa => score != null || gradePoint != null,
    GradeResultType.pass || GradeResultType.noPass => true,
  };

  bool get countsTowardGpa => counted && resultType == GradeResultType.gpa;

  double? get finalGradePoint => resultType == GradeResultType.gpa
      ? gradePoint ?? (score == null ? null : scoreToGpa(score!))
      : null;

  String get resultSummary => switch (resultType) {
    GradeResultType.gpa => finalGradePoint?.toStringAsFixed(2) ?? '未出分',
    GradeResultType.pass => 'P',
    GradeResultType.noPass => 'NP',
  };

  GradeEntry copyWith({
    String? id,
    String? courseId,
    String? semesterId,
    String? courseName,
    double? credit,
    double? score,
    double? gradePoint,
    GradeResultType? resultType,
    bool? counted,
  }) {
    return GradeEntry(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      semesterId: semesterId ?? this.semesterId,
      courseName: courseName ?? this.courseName,
      credit: credit ?? this.credit,
      score: score ?? this.score,
      gradePoint: gradePoint ?? this.gradePoint,
      resultType: resultType ?? this.resultType,
      counted: counted ?? this.counted,
    );
  }

  String signature() {
    return '${semesterId.trim()}|${courseName.trim()}|$credit|${score ?? ''}|'
        '${gradePoint ?? ''}|${resultType.jsonValue}|$counted';
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'courseId': courseId,
    'semesterId': semesterId,
    'courseName': courseName,
    'credit': credit,
    'score': score,
    'gradePoint': gradePoint,
    'resultType': resultType.jsonValue,
    'counted': counted,
  };

  factory GradeEntry.fromJson(Map<String, dynamic> json) {
    return GradeEntry(
      id: json['id'] as String?,
      courseId: json['courseId'] as String?,
      semesterId: (json['semesterId'] as String?)?.trim() ?? '',
      courseName: (json['courseName'] as String?)?.trim() ?? '未知课程',
      credit: (json['credit'] as num?)?.toDouble() ?? 0,
      score: (json['score'] as num?)?.toDouble(),
      gradePoint: (json['gradePoint'] as num?)?.toDouble(),
      resultType: GradeResultTypeCodec.fromJson(json['resultType'] as String?),
      counted: json['counted'] as bool? ?? true,
    );
  }
}

double scoreToGpa(double score) {
  if (score >= 90) return 4.0;
  if (score >= 85) return 3.7;
  if (score >= 82) return 3.3;
  if (score >= 78) return 3.0;
  if (score >= 75) return 2.7;
  if (score >= 72) return 2.3;
  if (score >= 68) return 2.0;
  if (score >= 64) return 1.5;
  if (score >= 60) return 1.0;
  return 0;
}

enum ThemeModeSetting { system, light, dark }

extension ThemeModeSettingCodec on ThemeModeSetting {
  ThemeMode toThemeMode() => switch (this) {
    ThemeModeSetting.system => ThemeMode.system,
    ThemeModeSetting.light => ThemeMode.light,
    ThemeModeSetting.dark => ThemeMode.dark,
  };

  String get jsonValue => switch (this) {
    ThemeModeSetting.system => 'system',
    ThemeModeSetting.light => 'light',
    ThemeModeSetting.dark => 'dark',
  };

  static ThemeModeSetting fromJson(String? value) => switch (value) {
    'light' => ThemeModeSetting.light,
    'dark' => ThemeModeSetting.dark,
    _ => ThemeModeSetting.system,
  };
}

class AppSettings {
  AppSettings({
    required this.themeModeSetting,
    required this.reminderMinutesBefore,
    required this.termStartMonday,
    required this.periodStartTimes,
    required this.periodEndTimes,
    required this.dayStartTime,
    required this.dayEndTime,
    required this.periodDurationMinutes,
    required this.maxPeriodsPerDay,
    required this.frostedCards,
    required this.showWeekSummaryInWidget,
    required this.windowsDesktopPinned,
    required this.windowsAutoStart,
    required this.windowsAutoStartMiniMode,
  });

  final ThemeModeSetting themeModeSetting;
  final int reminderMinutesBefore;
  final DateTime termStartMonday;
  final List<String> periodStartTimes;
  final List<String> periodEndTimes;
  final String dayStartTime;
  final String dayEndTime;
  final int periodDurationMinutes;
  final int maxPeriodsPerDay;
  final bool frostedCards;
  final bool showWeekSummaryInWidget;
  final bool windowsDesktopPinned;
  final bool windowsAutoStart;
  final bool windowsAutoStartMiniMode;

  static AppSettings defaults() {
    const String startTime = '08:00';
    const String endTime = '22:00';
    const int periodMinutes = 50;
    const int maxPeriods = 12;
    final List<String> starts = buildPeriodStartTimes(
      dayStartTime: startTime,
      periodDurationMinutes: periodMinutes,
      maxPeriodsPerDay: maxPeriods,
    );
    final List<String> ends = buildPeriodEndTimes(
      periodStartTimes: starts,
      periodDurationMinutes: periodMinutes,
      dayEndTime: endTime,
    );
    return AppSettings(
      themeModeSetting: ThemeModeSetting.system,
      reminderMinutesBefore: 15,
      termStartMonday: mondayOf(DateTime.now()),
      periodStartTimes: starts,
      periodEndTimes: ends,
      dayStartTime: startTime,
      dayEndTime: endTime,
      periodDurationMinutes: periodMinutes,
      maxPeriodsPerDay: maxPeriods,
      frostedCards: true,
      showWeekSummaryInWidget: true,
      windowsDesktopPinned: false,
      windowsAutoStart: false,
      windowsAutoStartMiniMode: false,
    );
  }

  AppSettings copyWith({
    ThemeModeSetting? themeModeSetting,
    int? reminderMinutesBefore,
    DateTime? termStartMonday,
    List<String>? periodStartTimes,
    List<String>? periodEndTimes,
    String? dayStartTime,
    String? dayEndTime,
    int? periodDurationMinutes,
    int? maxPeriodsPerDay,
    bool? frostedCards,
    bool? showWeekSummaryInWidget,
    bool? windowsDesktopPinned,
    bool? windowsAutoStart,
    bool? windowsAutoStartMiniMode,
  }) {
    return AppSettings(
      themeModeSetting: themeModeSetting ?? this.themeModeSetting,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      termStartMonday: termStartMonday ?? this.termStartMonday,
      periodStartTimes: periodStartTimes ?? this.periodStartTimes,
      periodEndTimes: periodEndTimes ?? this.periodEndTimes,
      dayStartTime: dayStartTime ?? this.dayStartTime,
      dayEndTime: dayEndTime ?? this.dayEndTime,
      periodDurationMinutes:
          periodDurationMinutes ?? this.periodDurationMinutes,
      maxPeriodsPerDay: maxPeriodsPerDay ?? this.maxPeriodsPerDay,
      frostedCards: frostedCards ?? this.frostedCards,
      showWeekSummaryInWidget:
          showWeekSummaryInWidget ?? this.showWeekSummaryInWidget,
      windowsDesktopPinned: windowsDesktopPinned ?? this.windowsDesktopPinned,
      windowsAutoStart: windowsAutoStart ?? this.windowsAutoStart,
      windowsAutoStartMiniMode:
          windowsAutoStartMiniMode ?? this.windowsAutoStartMiniMode,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'themeModeSetting': themeModeSetting.jsonValue,
    'reminderMinutesBefore': reminderMinutesBefore,
    'termStartMonday': termStartMonday.toIso8601String(),
    'periodStartTimes': periodStartTimes,
    'periodEndTimes': periodEndTimes,
    'dayStartTime': dayStartTime,
    'dayEndTime': dayEndTime,
    'periodDurationMinutes': periodDurationMinutes,
    'maxPeriodsPerDay': maxPeriodsPerDay,
    'frostedCards': frostedCards,
    'showWeekSummaryInWidget': showWeekSummaryInWidget,
    'windowsDesktopPinned': windowsDesktopPinned,
    'windowsAutoStart': windowsAutoStart,
    'windowsAutoStartMiniMode': windowsAutoStartMiniMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final List<dynamic> periodList =
        (json['periodStartTimes'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> periodEndList =
        (json['periodEndTimes'] as List<dynamic>?) ?? <dynamic>[];
    final String parsedStartTime = normalizeTimeText(
      json['dayStartTime'] as String?,
      fallback: defaults().dayStartTime,
    );
    final String parsedEndTime = normalizeTimeText(
      json['dayEndTime'] as String?,
      fallback: defaults().dayEndTime,
    );
    final int parsedDuration =
        (json['periodDurationMinutes'] as num?)?.toInt() ??
        defaults().periodDurationMinutes;
    final int parsedMaxPeriods =
        (json['maxPeriodsPerDay'] as num?)?.toInt() ??
        defaults().maxPeriodsPerDay;

    final List<String> generatedStarts = buildPeriodStartTimes(
      dayStartTime: parsedStartTime,
      periodDurationMinutes: parsedDuration,
      maxPeriodsPerDay: parsedMaxPeriods,
    );

    final List<String> storedStarts = periodList
        .whereType<String>()
        .map((String e) => normalizeTimeText(e, fallback: ''))
        .where((String e) => e.isNotEmpty)
        .toList();
    final int safeMaxPeriods = parsedMaxPeriods.clamp(1, 24);
    final List<String> normalizedStarts = _normalizeTimeList(
      source: storedStarts,
      fallback: generatedStarts,
      count: safeMaxPeriods,
      fallbackValue: '08:00',
    );

    final List<String> generatedEnds = buildPeriodEndTimes(
      periodStartTimes: normalizedStarts,
      periodDurationMinutes: parsedDuration,
      dayEndTime: parsedEndTime,
    );
    final List<String> storedEnds = periodEndList
        .whereType<String>()
        .map((String e) => normalizeTimeText(e, fallback: ''))
        .where((String e) => e.isNotEmpty)
        .toList();
    final List<String> normalizedEnds = _normalizeEndTimeList(
      source: storedEnds,
      fallback: generatedEnds,
      startTimes: normalizedStarts,
      periodDurationMinutes: parsedDuration.clamp(30, 180),
    );

    return AppSettings(
      themeModeSetting: ThemeModeSettingCodec.fromJson(
        json['themeModeSetting'] as String?,
      ),
      reminderMinutesBefore:
          (json['reminderMinutesBefore'] as num?)?.toInt() ?? 15,
      termStartMonday:
          DateTime.tryParse(json['termStartMonday'] as String? ?? '') ??
          mondayOf(DateTime.now()),
      periodStartTimes: normalizedStarts,
      periodEndTimes: normalizedEnds,
      dayStartTime: parsedStartTime,
      dayEndTime: parsedEndTime,
      periodDurationMinutes: parsedDuration.clamp(30, 180),
      maxPeriodsPerDay: safeMaxPeriods,
      frostedCards: json['frostedCards'] as bool? ?? true,
      showWeekSummaryInWidget: json['showWeekSummaryInWidget'] as bool? ?? true,
      windowsDesktopPinned: json['windowsDesktopPinned'] as bool? ?? false,
      windowsAutoStart: json['windowsAutoStart'] as bool? ?? false,
      windowsAutoStartMiniMode:
          json['windowsAutoStartMiniMode'] as bool? ?? false,
    );
  }
}

class SemesterInfo {
  SemesterInfo({String? id, required this.name, DateTime? termStartMonday})
    : id = id ?? _uuid.v4(),
      termStartMonday = mondayOf(termStartMonday ?? DateTime.now());

  final String id;
  final String name;
  final DateTime termStartMonday;

  SemesterInfo copyWith({String? id, String? name, DateTime? termStartMonday}) {
    return SemesterInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      termStartMonday: termStartMonday ?? this.termStartMonday,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'termStartMonday': termStartMonday.toIso8601String(),
  };

  factory SemesterInfo.fromJson(Map<String, dynamic> json) {
    final DateTime parsedTermStart =
        DateTime.tryParse(json['termStartMonday'] as String? ?? '') ??
        mondayOf(DateTime.now());
    return SemesterInfo(
      id: json['id'] as String?,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : '未命名学期',
      termStartMonday: parsedTermStart,
    );
  }
}

class ImportBundle {
  const ImportBundle({
    required this.courses,
    required this.grades,
    this.semesters = const <SemesterInfo>[],
    this.currentSemesterId,
    this.allSemesters = false,
    this.settings,
  });

  final List<Course> courses;
  final List<GradeEntry> grades;
  final List<SemesterInfo> semesters;
  final String? currentSemesterId;
  final bool allSemesters;
  final AppSettings? settings;
}

class TeachingSystemConfig {
  const TeachingSystemConfig({
    required this.timetableUrl,
    required this.gradeUrl,
    required this.cookie,
    required this.extraHeaders,
  });

  final String timetableUrl;
  final String gradeUrl;
  final String cookie;
  final Map<String, String> extraHeaders;
}

class AutoImportResult {
  const AutoImportResult({
    required this.courses,
    required this.grades,
    required this.messages,
  });

  final List<Course> courses;
  final List<GradeEntry> grades;
  final List<String> messages;
}

DateTime mondayOf(DateTime date) {
  final DateTime normalized = DateTime(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

int weekOfTerm(DateTime date, DateTime termStartMonday) {
  final DateTime day = DateTime(date.year, date.month, date.day);
  final DateTime start = DateTime(
    termStartMonday.year,
    termStartMonday.month,
    termStartMonday.day,
  );
  final int days = day.difference(start).inDays;
  return (days / 7).floor() + 1;
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

List<String> _normalizeTimeList({
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

List<String> _normalizeEndTimeList({
  required List<String> source,
  required List<String> fallback,
  required List<String> startTimes,
  required int periodDurationMinutes,
}) {
  final int count = startTimes.length;
  final List<String> normalized = _normalizeTimeList(
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
