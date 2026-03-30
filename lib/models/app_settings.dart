import 'package:flutter/material.dart';

import 'schedule_utils.dart';

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
    final List<String> normalizedStarts = normalizeTimeList(
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
    final List<String> normalizedEnds = normalizeEndTimeList(
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
