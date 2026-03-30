import 'package:uuid/uuid.dart';

const Uuid _uuidGrade = Uuid();

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
  }) : id = id ?? _uuidGrade.v4();

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
