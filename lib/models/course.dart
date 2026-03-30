import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'course_session.dart';

const Uuid _uuid = Uuid();

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
    this.courseType = CourseType.scheduled,
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
  final CourseType courseType;
  final List<CourseSession> sessions;

  Color get color => Color(colorValue);
  bool get isOnline => courseType == CourseType.online;
  bool get hasSchedule => sessions.isNotEmpty;

  Course copyWith({
    String? id,
    String? name,
    String? semesterId,
    String? code,
    String? teacher,
    String? location,
    double? credit,
    int? colorValue,
    CourseType? courseType,
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
      courseType: courseType ?? this.courseType,
      sessions: sessions ?? this.sessions,
    );
  }

  String signature() {
    final List<String> sessionKeys =
        sessions
            .map(
              (CourseSession session) =>
                  '${session.weekday}|${session.startPeriod}|${session.endPeriod}|'
                  '${session.startWeek}|${session.endWeek}|${session.weekType.jsonValue}',
            )
            .toList()
          ..sort();
    return '${semesterId.trim()}|${name.trim()}|${code.trim()}|${teacher.trim()}|'
        '${location.trim()}|${courseType.jsonValue}|${sessionKeys.join(";")}';
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
    'courseType': courseType.jsonValue,
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
      courseType: CourseTypeCodec.fromJson(json['courseType'] as String?),
      sessions: rawSessions
          .whereType<Map<String, dynamic>>()
          .map(CourseSession.fromJson)
          .toList(),
    );
  }
}
