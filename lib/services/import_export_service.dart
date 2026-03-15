import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xls;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

class ImportExportService {
  Future<File> exportToJson(ImportBundle bundle) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final File file = File('${dir.path}\\course_monitor_$stamp.json');

    final Map<String, dynamic> payload = <String, dynamic>{
      'allSemesters': bundle.allSemesters,
      'currentSemesterId': bundle.currentSemesterId,
      'semesters': bundle.semesters
          .map((SemesterInfo e) => e.toJson())
          .toList(),
      'courses': bundle.courses.map((Course e) => e.toJson()).toList(),
      'grades': bundle.grades.map((GradeEntry e) => e.toJson()).toList(),
      if (bundle.settings != null) 'settings': bundle.settings!.toJson(),
      'exportedAt': DateTime.now().toIso8601String(),
    };

    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    return file;
  }

  Future<File> exportAllSemestersToJson({
    required List<SemesterInfo> semesters,
    required String currentSemesterId,
    required List<Course> courses,
    required List<GradeEntry> grades,
    AppSettings? settings,
  }) async {
    final ImportBundle bundle = ImportBundle(
      courses: courses,
      grades: grades,
      semesters: semesters,
      currentSemesterId: currentSemesterId,
      allSemesters: true,
      settings: settings,
    );
    return exportToJson(bundle);
  }

  Future<File> exportToCsv(ImportBundle bundle) async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final String stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final File file = File('${dir.path}\\course_monitor_$stamp.csv');

    final List<List<dynamic>> rows = <List<dynamic>>[
      <String>[
        'type',
        'semesterId',
        'id',
        'name',
        'code',
        'teacher',
        'location',
        'credit',
        'weekday',
        'startPeriod',
        'endPeriod',
        'startWeek',
        'endWeek',
        'weekType',
        'colorValue',
        'courseType',
        'courseId',
        'score',
        'gradePoint',
        'resultType',
        'counted',
      ],
    ];

    for (final Course course in bundle.courses) {
      if (course.isOnline || course.sessions.isEmpty) {
        rows.add(<dynamic>[
          'course',
          course.semesterId,
          course.id,
          course.name,
          course.code,
          course.teacher,
          course.location,
          course.credit,
          '',
          '',
          '',
          '',
          '',
          '',
          course.colorValue,
          course.courseType.jsonValue,
          '',
          '',
          '',
          '',
        ]);
        continue;
      }
      for (final CourseSession session in course.sessions) {
        rows.add(<dynamic>[
          'course',
          course.semesterId,
          course.id,
          course.name,
          course.code,
          course.teacher,
          course.location,
          course.credit,
          session.weekday,
          session.startPeriod,
          session.endPeriod,
          session.startWeek,
          session.endWeek,
          session.weekType.jsonValue,
          course.colorValue,
          course.courseType.jsonValue,
          '',
          '',
          '',
          '',
        ]);
      }
    }

    for (final GradeEntry grade in bundle.grades) {
      rows.add(<dynamic>[
        'grade',
        grade.semesterId,
        grade.id,
        grade.courseName,
        '',
        '',
        '',
        grade.credit,
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        grade.courseId ?? '',
        grade.score ?? '',
        grade.gradePoint ?? '',
        grade.resultType.jsonValue,
        grade.counted,
      ]);
    }

    await file.writeAsString(const CsvEncoder().convert(rows));
    return file;
  }

  Future<ImportBundle> importFromPath(
    String path, {
    AppSettings? settings,
  }) async {
    final File file = File(path);
    if (!await file.exists()) {
      throw Exception('文件不存在：$path');
    }

    final String ext = path.split('.').last.toLowerCase();
    final String content = await file.readAsString();

    if (ext == 'json') {
      return _parseJson(content);
    }
    if (ext == 'csv') {
      return _parseCsv(content);
    }
    if (ext == 'ics') {
      return _parseIcs(content, settings: settings ?? AppSettings.defaults());
    }
    throw Exception('不支持的文件扩展名：.$ext');
  }

  ImportBundle _parseJson(String content) {
    final dynamic decoded = jsonDecode(content);

    if (decoded is List<dynamic>) {
      final List<Course> courses = decoded
          .whereType<Map<String, dynamic>>()
          .map(Course.fromJson)
          .toList();
      return ImportBundle(courses: courses, grades: const <GradeEntry>[]);
    }

    if (decoded is Map<String, dynamic>) {
      final bool allSemesters = decoded['allSemesters'] == true;
      final String? currentSemesterId =
          (decoded['currentSemesterId'] as String?)?.trim();
      final dynamic rawSettings = decoded['settings'];
      final AppSettings? settings = rawSettings is Map<String, dynamic>
          ? AppSettings.fromJson(rawSettings)
          : null;

      final List<dynamic> rawSemesters =
          (decoded['semesters'] as List<dynamic>?) ?? <dynamic>[];
      final List<SemesterInfo> semesters = rawSemesters
          .whereType<Map<String, dynamic>>()
          .map(SemesterInfo.fromJson)
          .toList();

      final List<dynamic> rawCourses =
          (decoded['courses'] as List<dynamic>?) ?? <dynamic>[];
      final List<dynamic> rawGrades =
          (decoded['grades'] as List<dynamic>?) ?? <dynamic>[];

      final List<Course> courses = rawCourses
          .whereType<Map<String, dynamic>>()
          .map(Course.fromJson)
          .toList();
      final List<GradeEntry> grades = rawGrades
          .whereType<Map<String, dynamic>>()
          .map(GradeEntry.fromJson)
          .toList();

      return ImportBundle(
        courses: courses,
        grades: grades,
        semesters: semesters,
        currentSemesterId: currentSemesterId,
        allSemesters: allSemesters,
        settings: settings,
      );
    }

    throw Exception('JSON 内容格式无法识别');
  }

  ImportBundle _parseCsv(String content) {
    final List<List<dynamic>> rows = const CsvDecoder(
      dynamicTyping: false,
    ).convert(content).where((List<dynamic> row) => row.isNotEmpty).toList();

    if (rows.isEmpty) {
      return const ImportBundle(courses: <Course>[], grades: <GradeEntry>[]);
    }

    final List<String> headers = rows.first.map((dynamic e) => '$e').toList();
    final Map<String, Course> coursesByKey = <String, Course>{};
    final List<GradeEntry> grades = <GradeEntry>[];

    for (final List<dynamic> raw in rows.skip(1)) {
      final Map<String, String> row = <String, String>{};
      for (int i = 0; i < headers.length; i++) {
        if (i < raw.length) {
          row[headers[i]] = '${raw[i]}'.trim();
        }
      }

      final String type = (row['type'] ?? '').toLowerCase();
      if (type == 'course') {
        final String courseKey = _csvCourseKey(row);
        final Course? existing = coursesByKey[courseKey];
        final CourseType courseType = CourseTypeCodec.fromJson(
          row['courseType'],
        );
        final bool hasSchedule =
            _toInt(row['weekday']) != null &&
            _toInt(row['startPeriod']) != null &&
            _toInt(row['endPeriod']) != null;
        if (existing == null) {
          final List<CourseSession> sessions = hasSchedule
              ? <CourseSession>[
                  CourseSession(
                    weekday: _toInt(row['weekday']) ?? 1,
                    startPeriod: _toInt(row['startPeriod']) ?? 1,
                    endPeriod: _toInt(row['endPeriod']) ?? 2,
                    startWeek: _toInt(row['startWeek']) ?? 1,
                    endWeek: _toInt(row['endWeek']) ?? 20,
                    weekType: WeekTypeCodec.fromJson(row['weekType']),
                  ),
                ]
              : const <CourseSession>[];
          coursesByKey[courseKey] = Course(
            id: _optionalString(row['id']),
            semesterId: _safeString(row['semesterId']),
            name: _safeString(row['name'], fallback: '未命名课程'),
            code: _safeString(row['code']),
            teacher: _safeString(row['teacher']),
            location: _safeString(row['location']),
            credit: _toDouble(row['credit']) ?? 0,
            colorValue: _toInt(row['colorValue']) ?? 0xFF4A90E2,
            courseType: courseType,
            sessions: sessions,
          );
        } else if (hasSchedule) {
          final CourseSession session = CourseSession(
            weekday: _toInt(row['weekday']) ?? 1,
            startPeriod: _toInt(row['startPeriod']) ?? 1,
            endPeriod: _toInt(row['endPeriod']) ?? 2,
            startWeek: _toInt(row['startWeek']) ?? 1,
            endWeek: _toInt(row['endWeek']) ?? 20,
            weekType: WeekTypeCodec.fromJson(row['weekType']),
          );
          final bool sessionExists = existing.sessions.any(
            (CourseSession item) =>
                item.weekday == session.weekday &&
                item.startPeriod == session.startPeriod &&
                item.endPeriod == session.endPeriod &&
                item.startWeek == session.startWeek &&
                item.endWeek == session.endWeek &&
                item.weekType == session.weekType,
          );
          if (!sessionExists) {
            coursesByKey[courseKey] = existing.copyWith(
              sessions: <CourseSession>[...existing.sessions, session],
            );
          }
        }
      } else if (type == 'grade') {
        grades.add(
          GradeEntry(
            id: _optionalString(row['id']),
            semesterId: _safeString(row['semesterId']),
            courseId: _optionalString(row['courseId']),
            courseName: _safeString(row['name'], fallback: '未知课程'),
            credit: _toDouble(row['credit']) ?? 0,
            score: _toDouble(row['score']),
            gradePoint: _toDouble(row['gradePoint']),
            resultType: GradeResultTypeCodec.fromJson(row['resultType']),
            counted: (row['counted'] ?? '').toLowerCase() != 'false',
          ),
        );
      }
    }

    return ImportBundle(courses: coursesByKey.values.toList(), grades: grades);
  }

  Future<ExcelGradeParseResult> parseGradeExcel(String path) async {
    final File file = File(path);
    if (!await file.exists()) {
      throw Exception('文件不存在：$path');
    }

    final List<int> bytes = await file.readAsBytes();
    final xls.Excel workbook;
    try {
      workbook = xls.Excel.decodeBytes(bytes);
    } catch (_) {
      throw Exception('无法解析 Excel 文件，请优先使用 .xlsx 格式。');
    }

    final List<ExcelGradeRow> rows = <ExcelGradeRow>[];
    final Set<String> sourceSemesters = <String>{};

    for (final MapEntry<String, xls.Sheet> entry in workbook.tables.entries) {
      final xls.Sheet sheet = entry.value;
      final List<List<xls.Data?>> sheetRows = sheet.rows;
      if (sheetRows.isEmpty) {
        continue;
      }

      final int headerRowIndex = _findExcelHeaderRow(sheetRows);
      if (headerRowIndex < 0) {
        continue;
      }

      final Map<String, int> columns = _buildExcelColumnMap(
        sheetRows[headerRowIndex],
      );
      for (
        int rowIndex = headerRowIndex + 1;
        rowIndex < sheetRows.length;
        rowIndex++
      ) {
        final List<xls.Data?> row = sheetRows[rowIndex];
        final String courseName = _excelCellTextAt(row, columns['courseName']);
        final String courseCode = _excelCellTextAt(row, columns['courseCode']);
        final String semesterName = _excelCellTextAt(row, columns['semester']);
        final String resultText = _excelCellTextAt(row, columns['result']);
        final String gradePointText = _excelCellTextAt(
          row,
          columns['gradePoint'],
        );
        final String creditText = _excelCellTextAt(row, columns['credit']);

        if (_isExcelGradeRowEmpty(row)) {
          continue;
        }
        if (courseName.isEmpty || semesterName.isEmpty) {
          continue;
        }

        final GradeResultType? resultType = _parseExcelResultType(
          resultText,
          gradePointText,
        );
        if (resultType == null) {
          continue;
        }

        rows.add(
          ExcelGradeRow(
            sheetName: entry.key,
            sourceSemesterName: semesterName,
            courseName: courseName,
            courseCode: courseCode,
            credit: _toDouble(creditText) ?? 0,
            rawResult: resultText.isNotEmpty ? resultText : gradePointText,
            resultType: resultType,
            score: resultType == GradeResultType.gpa
                ? _toDouble(resultText)
                : null,
            gradePoint: resultType == GradeResultType.gpa
                ? _toDouble(gradePointText)
                : null,
          ),
        );
        sourceSemesters.add(semesterName);
      }
    }

    if (rows.isEmpty) {
      throw Exception('未识别到可导入的成绩数据，请确认 Excel 包含“课程名称、成绩、学期”等列。');
    }

    final List<String> semesters = sourceSemesters.toList()..sort();
    return ExcelGradeParseResult(rows: rows, sourceSemesters: semesters);
  }

  ImportBundle _parseIcs(String content, {required AppSettings settings}) {
    final List<String> lines = _unfoldIcsLines(content);
    final List<Map<String, String>> events = <Map<String, String>>[];
    Map<String, String>? current;

    for (final String rawLine in lines) {
      final String line = rawLine.trimRight();
      if (line == 'BEGIN:VEVENT') {
        current = <String, String>{};
        continue;
      }
      if (line == 'END:VEVENT') {
        if (current != null) {
          events.add(current);
        }
        current = null;
        continue;
      }
      if (current == null) {
        continue;
      }

      final int separator = line.indexOf(':');
      if (separator <= 0) {
        continue;
      }
      final String key = line.substring(0, separator).trim();
      final String value = line.substring(separator + 1).trim();
      current[key] = value;
    }

    final Map<String, _IcsAggregate> aggregates = <String, _IcsAggregate>{};

    for (final Map<String, String> event in events) {
      final String summary = _unescapeIcsText(
        _propertyValue(event, 'SUMMARY') ?? '',
      ).trim();
      if (summary.isEmpty) {
        continue;
      }

      final DateTime? start = _parseIcsDateTime(
        _propertyValue(event, 'DTSTART'),
      );
      final DateTime? end = _parseIcsDateTime(_propertyValue(event, 'DTEND'));
      if (start == null || end == null || !end.isAfter(start)) {
        continue;
      }

      final ({int startPeriod, int endPeriod})? periods =
          _mapTimeRangeToPeriods(
            startMinutes: start.hour * 60 + start.minute,
            endMinutes: end.hour * 60 + end.minute,
            settings: settings,
          );
      if (periods == null) {
        continue;
      }

      final String locationRaw = _unescapeIcsText(
        _propertyValue(event, 'LOCATION') ?? '',
      );
      final String descriptionRaw = _unescapeIcsText(
        _propertyValue(event, 'DESCRIPTION') ?? '',
      );
      final String location = _deriveLocation(
        locationRaw: locationRaw,
        description: descriptionRaw,
      );
      final String teacher = _deriveTeacher(
        locationRaw: locationRaw,
        description: descriptionRaw,
      );
      final String code = _extractCourseCodeFromIcs(
        summary: summary,
        description: descriptionRaw,
      );

      final Map<String, String> rrule = _parseRRule(
        _propertyValue(event, 'RRULE'),
      );
      final List<DateTime> starts = _expandWeeklyOccurrences(
        start: start,
        rrule: rrule,
      );

      for (final DateTime occurrence in starts) {
        final DateTime day = DateTime(
          occurrence.year,
          occurrence.month,
          occurrence.day,
        );
        final int week = weekOfTerm(day, settings.termStartMonday);
        if (week < 1 || week > 60) {
          continue;
        }

        final String key =
            '${summary.toLowerCase()}|${code.toLowerCase()}|${location.toLowerCase()}|'
            '${occurrence.weekday}|${periods.startPeriod}|${periods.endPeriod}';
        final _IcsAggregate aggregate = aggregates.putIfAbsent(
          key,
          () => _IcsAggregate(
            name: summary,
            code: code,
            location: location,
            weekday: occurrence.weekday,
            startPeriod: periods.startPeriod,
            endPeriod: periods.endPeriod,
            colorValue: _stableCourseColor(summary),
          ),
        );
        aggregate.weeks.add(week);
        if (teacher.isNotEmpty) {
          aggregate.teachers.add(teacher);
        }
      }
    }

    final List<Course> courses = <Course>[];
    for (final _IcsAggregate aggregate in aggregates.values) {
      final List<CourseSession> sessions = _buildSessionsFromWeeks(
        aggregate.weeks,
        weekday: aggregate.weekday,
        startPeriod: aggregate.startPeriod,
        endPeriod: aggregate.endPeriod,
      );
      if (sessions.isEmpty) {
        continue;
      }
      courses.add(
        Course(
          name: aggregate.name,
          code: aggregate.code,
          teacher: aggregate.teachers.join(' / '),
          location: aggregate.location,
          credit: 0,
          colorValue: aggregate.colorValue,
          sessions: sessions,
        ),
      );
    }

    courses.sort((Course a, Course b) {
      final CourseSession sa = a.sessions.first;
      final CourseSession sb = b.sessions.first;
      if (sa.weekday != sb.weekday) {
        return sa.weekday.compareTo(sb.weekday);
      }
      if (sa.startPeriod != sb.startPeriod) {
        return sa.startPeriod.compareTo(sb.startPeriod);
      }
      return a.name.compareTo(b.name);
    });

    return ImportBundle(courses: courses, grades: const <GradeEntry>[]);
  }

  List<String> _unfoldIcsLines(String content) {
    final List<String> raw = content.split(RegExp(r'\r?\n'));
    final List<String> unfolded = <String>[];
    for (final String line in raw) {
      if (line.startsWith(' ') || line.startsWith('\t')) {
        if (unfolded.isNotEmpty) {
          unfolded[unfolded.length - 1] += line.substring(1);
        }
      } else {
        unfolded.add(line);
      }
    }
    return unfolded;
  }

  String? _propertyValue(Map<String, String> event, String name) {
    for (final MapEntry<String, String> entry in event.entries) {
      final String base = entry.key.split(';').first.trim().toUpperCase();
      if (base == name.toUpperCase()) {
        return entry.value;
      }
    }
    return null;
  }

  DateTime? _parseIcsDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final String text = raw.trim();

    final RegExp dateTimePattern = RegExp(r'^(\d{8})T(\d{6})(Z)?$');
    final RegExp datePattern = RegExp(r'^(\d{8})$');

    final RegExpMatch? dateTimeMatch = dateTimePattern.firstMatch(text);
    if (dateTimeMatch != null) {
      final String datePart = dateTimeMatch.group(1)!;
      final String timePart = dateTimeMatch.group(2)!;
      final bool utc = dateTimeMatch.group(3) == 'Z';

      final int year = int.parse(datePart.substring(0, 4));
      final int month = int.parse(datePart.substring(4, 6));
      final int day = int.parse(datePart.substring(6, 8));
      final int hour = int.parse(timePart.substring(0, 2));
      final int minute = int.parse(timePart.substring(2, 4));
      final int second = int.parse(timePart.substring(4, 6));
      final DateTime value = utc
          ? DateTime.utc(year, month, day, hour, minute, second).toLocal()
          : DateTime(year, month, day, hour, minute, second);
      return value;
    }

    final RegExpMatch? dateMatch = datePattern.firstMatch(text);
    if (dateMatch != null) {
      final String datePart = dateMatch.group(1)!;
      final int year = int.parse(datePart.substring(0, 4));
      final int month = int.parse(datePart.substring(4, 6));
      final int day = int.parse(datePart.substring(6, 8));
      return DateTime(year, month, day);
    }
    return null;
  }

  Map<String, String> _parseRRule(String? raw) {
    final Map<String, String> result = <String, String>{};
    if (raw == null || raw.trim().isEmpty) {
      return result;
    }
    for (final String part in raw.split(';')) {
      final int eq = part.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      final String key = part.substring(0, eq).trim().toUpperCase();
      final String value = part.substring(eq + 1).trim();
      if (key.isEmpty || value.isEmpty) {
        continue;
      }
      result[key] = value;
    }
    return result;
  }

  List<DateTime> _expandWeeklyOccurrences({
    required DateTime start,
    required Map<String, String> rrule,
  }) {
    if (rrule.isEmpty) {
      return <DateTime>[start];
    }
    if ((rrule['FREQ'] ?? '').toUpperCase() != 'WEEKLY') {
      return <DateTime>[start];
    }

    final int interval =
        int.tryParse(rrule['INTERVAL'] ?? '1')?.clamp(1, 12) ?? 1;
    final int? count = int.tryParse(rrule['COUNT'] ?? '');
    final DateTime? until = _parseIcsDateTime(rrule['UNTIL']);

    final List<DateTime> result = <DateTime>[];
    DateTime cursor = start;
    for (int i = 0; i < 120; i++) {
      if (count != null && result.length >= count) {
        break;
      }
      if (until != null && cursor.isAfter(until)) {
        break;
      }
      result.add(cursor);
      cursor = cursor.add(Duration(days: 7 * interval));
    }
    if (result.isEmpty) {
      result.add(start);
    }
    return result;
  }

  ({int startPeriod, int endPeriod})? _mapTimeRangeToPeriods({
    required int startMinutes,
    required int endMinutes,
    required AppSettings settings,
  }) {
    if (endMinutes <= startMinutes) {
      return null;
    }

    final List<int> overlaps = <int>[];
    for (int period = 1; period <= settings.maxPeriodsPerDay; period++) {
      final int? periodStart = periodStartMinutesAt(settings, period);
      final int? periodEnd = periodEndMinutesAt(settings, period);
      if (periodStart == null ||
          periodEnd == null ||
          periodEnd <= periodStart) {
        continue;
      }
      if (startMinutes < periodEnd && endMinutes > periodStart) {
        overlaps.add(period);
      }
    }

    if (overlaps.isNotEmpty) {
      return (startPeriod: overlaps.first, endPeriod: overlaps.last);
    }

    int nearestPeriod = 1;
    int nearestDelta = 1 << 30;
    for (int period = 1; period <= settings.maxPeriodsPerDay; period++) {
      final int? periodStart = periodStartMinutesAt(settings, period);
      if (periodStart == null) {
        continue;
      }
      final int delta = (periodStart - startMinutes).abs();
      if (delta < nearestDelta) {
        nearestDelta = delta;
        nearestPeriod = period;
      }
    }

    int endPeriod = nearestPeriod;
    for (
      int period = nearestPeriod;
      period <= settings.maxPeriodsPerDay;
      period++
    ) {
      final int? periodEnd = periodEndMinutesAt(settings, period);
      if (periodEnd == null) {
        continue;
      }
      endPeriod = period;
      if (periodEnd >= endMinutes) {
        break;
      }
    }
    return (startPeriod: nearestPeriod, endPeriod: endPeriod);
  }

  String _unescapeIcsText(String value) {
    return value
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\N', '\n')
        .replaceAll(r'\\', '\\')
        .replaceAll(r'\,', ',')
        .replaceAll(r'\;', ';')
        .trim();
  }

  String _deriveLocation({
    required String locationRaw,
    required String description,
  }) {
    final List<String> lines = description
        .split('\n')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) {
      return lines.first;
    }
    return locationRaw.trim();
  }

  String _deriveTeacher({
    required String locationRaw,
    required String description,
  }) {
    final List<String> lines = description
        .split('\n')
        .map((String e) => e.trim())
        .where((String e) => e.isNotEmpty)
        .toList();
    if (lines.length >= 2) {
      return lines[1];
    }

    final List<String> tokens = locationRaw
        .split(RegExp(r'\s+'))
        .where((String e) => e.trim().isNotEmpty)
        .toList();
    if (tokens.length >= 2) {
      final String candidate = tokens.last.trim();
      if (_looksLikeTeacher(candidate)) {
        return candidate;
      }
    }
    return '';
  }

  bool _looksLikeTeacher(String value) {
    final String text = value.trim();
    if (text.length < 2 || text.length > 10) {
      return false;
    }
    return RegExp(r'^[\u4e00-\u9fa5A-Za-z·]+$').hasMatch(text);
  }

  String _extractCourseCodeFromIcs({
    required String summary,
    required String description,
  }) {
    final RegExpMatch? bracket = RegExp(r'\[([^\]]+)\]').firstMatch(summary);
    if (bracket != null) {
      return bracket.group(1)!.trim();
    }

    final RegExpMatch? byDesc = RegExp(
      r'(?:课程代码|course\s*code)\s*[:：]\s*([A-Za-z0-9_-]+)',
      caseSensitive: false,
    ).firstMatch(description);
    if (byDesc != null) {
      return byDesc.group(1)!.trim();
    }
    return '';
  }

  int _stableCourseColor(String key) {
    const List<int> palette = <int>[
      0xFF4A90E2,
      0xFF3EA66E,
      0xFF8A7DEB,
      0xFF2F9FB3,
      0xFFCF5C9B,
      0xFFE08A42,
      0xFF5E88C7,
      0xFF6CA676,
    ];
    final int index = key.hashCode.abs() % palette.length;
    return palette[index];
  }

  List<CourseSession> _buildSessionsFromWeeks(
    Set<int> weeks, {
    required int weekday,
    required int startPeriod,
    required int endPeriod,
  }) {
    final List<int> sorted = weeks.toList()..sort();
    if (sorted.isEmpty) {
      return const <CourseSession>[];
    }

    final List<CourseSession> sessions = <CourseSession>[];
    int startWeek = sorted.first;
    int lastWeek = sorted.first;
    for (int i = 1; i < sorted.length; i++) {
      final int week = sorted[i];
      if (week == lastWeek + 1) {
        lastWeek = week;
        continue;
      }
      sessions.add(
        CourseSession(
          weekday: weekday,
          startPeriod: startPeriod,
          endPeriod: endPeriod,
          startWeek: startWeek,
          endWeek: lastWeek,
        ),
      );
      startWeek = week;
      lastWeek = week;
    }
    sessions.add(
      CourseSession(
        weekday: weekday,
        startPeriod: startPeriod,
        endPeriod: endPeriod,
        startWeek: startWeek,
        endWeek: lastWeek,
      ),
    );
    return sessions;
  }

  int _findExcelHeaderRow(List<List<xls.Data?>> rows) {
    final int limit = rows.length < 16 ? rows.length : 16;
    for (int i = 0; i < limit; i++) {
      final Map<String, int> columns = _buildExcelColumnMap(rows[i]);
      if (columns['courseName'] != null &&
          columns['semester'] != null &&
          (columns['result'] != null || columns['gradePoint'] != null)) {
        return i;
      }
    }
    return -1;
  }

  Map<String, int> _buildExcelColumnMap(List<xls.Data?> row) {
    final Map<String, int> mapping = <String, int>{};
    for (int index = 0; index < row.length; index++) {
      final String header = _normalizeExcelHeader(_excelCellText(row[index]));
      if (header.isEmpty) {
        continue;
      }
      if (!_hasColumn(mapping, 'courseName') &&
          <String>{'课程名称', '课程名'}.contains(header)) {
        mapping['courseName'] = index;
      } else if (!_hasColumn(mapping, 'courseCode') &&
          <String>{'课程代码', '课程序号', '课程编号'}.contains(header)) {
        mapping['courseCode'] = index;
      } else if (!_hasColumn(mapping, 'credit') &&
          <String>{'学分'}.contains(header)) {
        mapping['credit'] = index;
      } else if (!_hasColumn(mapping, 'result') &&
          <String>{'成绩', '总评成绩', '最终成绩'}.contains(header)) {
        mapping['result'] = index;
      } else if (!_hasColumn(mapping, 'gradePoint') &&
          <String>{'绩点', '学分绩'}.contains(header)) {
        mapping['gradePoint'] = index;
      } else if (!_hasColumn(mapping, 'semester') &&
          <String>{'学期', '学年学期'}.contains(header)) {
        mapping['semester'] = index;
      }
    }
    return mapping;
  }

  bool _hasColumn(Map<String, int> mapping, String key) => mapping[key] != null;

  String _normalizeExcelHeader(String value) {
    return value
        .replaceAll(RegExp(r'[\s\r\n\t]'), '')
        .replaceAll('（', '(')
        .replaceAll('）', ')')
        .trim();
  }

  String _excelCellTextAt(List<xls.Data?> row, int? index) {
    if (index == null || index < 0 || index >= row.length) {
      return '';
    }
    return _excelCellText(row[index]);
  }

  String _excelCellText(xls.Data? cell) {
    final xls.CellValue? value = cell?.value;
    if (value == null) {
      return '';
    }
    return switch (value) {
      xls.TextCellValue() =>
        (value.value.text ?? value.value.toString()).trim(),
      xls.FormulaCellValue() => value.formula.trim(),
      xls.IntCellValue() => value.value.toString(),
      xls.DoubleCellValue() => value.value.toString(),
      xls.BoolCellValue() => value.value.toString(),
      xls.DateCellValue() => value.asDateTimeLocal().toIso8601String(),
      xls.DateTimeCellValue() => value.asDateTimeLocal().toIso8601String(),
      xls.TimeCellValue() =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
    };
  }

  bool _isExcelGradeRowEmpty(List<xls.Data?> row) {
    return row.every((xls.Data? cell) => _excelCellText(cell).trim().isEmpty);
  }

  GradeResultType? _parseExcelResultType(
    String resultText,
    String gradePointText,
  ) {
    final String normalizedResult = resultText.trim().toUpperCase();
    final String normalizedGradePoint = gradePointText.trim().toUpperCase();
    if (<String>{'P', 'PASS', '通过', '合格'}.contains(normalizedResult)) {
      return GradeResultType.pass;
    }
    if (<String>{'NP', 'N/P', '未通过', '不合格', '不通过'}.contains(normalizedResult)) {
      return GradeResultType.noPass;
    }
    if (_toDouble(resultText) != null || _toDouble(gradePointText) != null) {
      return GradeResultType.gpa;
    }
    if (<String>{'P', 'PASS', '通过', '合格'}.contains(normalizedGradePoint)) {
      return GradeResultType.pass;
    }
    if (<String>{
      'NP',
      'N/P',
      '未通过',
      '不合格',
      '不通过',
    }.contains(normalizedGradePoint)) {
      return GradeResultType.noPass;
    }
    return null;
  }

  int? _toInt(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return int.tryParse(value.trim());
  }

  double? _toDouble(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value.trim());
  }

  String _safeString(String? value, {String fallback = ''}) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _optionalString(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String _csvCourseKey(Map<String, String> row) {
    final String id = _safeString(row['id']);
    if (id.isNotEmpty) {
      return 'id|$id';
    }
    return 'sig|'
        '${_safeString(row['semesterId']).toLowerCase()}|'
        '${_safeString(row['name']).toLowerCase()}|'
        '${_safeString(row['code']).toLowerCase()}|'
        '${_safeString(row['teacher']).toLowerCase()}|'
        '${_safeString(row['location']).toLowerCase()}|'
        '${_safeString(row['courseType'], fallback: 'scheduled').toLowerCase()}|'
        '${(_toDouble(row['credit']) ?? 0).toStringAsFixed(2)}|'
        '${_toInt(row['colorValue']) ?? 0xFF4A90E2}';
  }
}

class _IcsAggregate {
  _IcsAggregate({
    required this.name,
    required this.code,
    required this.location,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.colorValue,
  });

  final String name;
  final String code;
  final String location;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final int colorValue;
  final Set<int> weeks = <int>{};
  final Set<String> teachers = <String>{};
}
