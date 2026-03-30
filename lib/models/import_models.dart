import 'course.dart';
import 'grade_entry.dart';
import 'semester_info.dart';
import 'app_settings.dart';

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

class ExcelGradeRow {
  const ExcelGradeRow({
    required this.sheetName,
    required this.sourceSemesterName,
    required this.courseName,
    required this.courseCode,
    required this.credit,
    required this.rawResult,
    required this.resultType,
    this.score,
    this.gradePoint,
  });

  final String sheetName;
  final String sourceSemesterName;
  final String courseName;
  final String courseCode;
  final double credit;
  final String rawResult;
  final GradeResultType resultType;
  final double? score;
  final double? gradePoint;
}

class ExcelGradeParseResult {
  const ExcelGradeParseResult({
    required this.rows,
    required this.sourceSemesters,
  });

  final List<ExcelGradeRow> rows;
  final List<String> sourceSemesters;
}

class ExcelGradeImportResult {
  const ExcelGradeImportResult({
    required this.appliedCount,
    required this.skippedMissingCourses,
  });

  final int appliedCount;
  final List<String> skippedMissingCourses;
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
