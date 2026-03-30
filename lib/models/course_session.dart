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

enum CourseType { scheduled, online }

extension CourseTypeCodec on CourseType {
  String get jsonValue => switch (this) {
    CourseType.scheduled => 'scheduled',
    CourseType.online => 'online',
  };

  static CourseType fromJson(String? value) => switch (value) {
    'online' => CourseType.online,
    _ => CourseType.scheduled,
  };
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
