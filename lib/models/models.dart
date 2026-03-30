// Models barrel file - re-exports all domain models for backward compatibility.
// New code is encouraged to import specific model files directly.
//
// Split structure:
//   course_session.dart  - WeekType, CourseType, CourseSession + codecs, weekOfTerm
//   course.dart          - Course
//   grade_entry.dart     - GradeResultType, GradeEntry, scoreToGpa
//   app_settings.dart    - ThemeModeSetting, AppSettings
//   semester_info.dart   - SemesterInfo
//   import_models.dart    - ImportBundle, ExcelGradeRow, ExcelGradeParseResult,
//                          ExcelGradeImportResult, TeachingSystemConfig, AutoImportResult
//   schedule_utils.dart  - mondayOf, weekdayLabel, weekTypeLabel, firstTeacher,
//                          buildPeriodStartTimes, buildPeriodEndTimes,
//                          periodStartMinutesAt, periodEndMinutesAt,
//                          sessionStartAt, sessionEndAt, normalizeTimeText,
//                          timeTextToMinutes

export 'course_session.dart';
export 'course.dart';
export 'grade_entry.dart';
export 'app_settings.dart';
export 'semester_info.dart';
export 'import_models.dart';
export 'schedule_utils.dart';
