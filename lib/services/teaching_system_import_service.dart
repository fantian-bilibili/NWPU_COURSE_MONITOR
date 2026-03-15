import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class TeachingSystemImportService {
  TeachingSystemImportService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<AutoImportResult> importFromTeachingSystem(
    TeachingSystemConfig config,
  ) async {
    final List<Course> courses = <Course>[];
    final List<GradeEntry> grades = <GradeEntry>[];
    final List<String> messages = <String>[];

    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json, text/plain, */*',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      ...config.extraHeaders,
    };
    if (config.cookie.trim().isNotEmpty) {
      headers['Cookie'] = config.cookie.trim();
    }

    if (config.timetableUrl.trim().isNotEmpty) {
      final http.Response response = await _client.get(
        Uri.parse(config.timetableUrl.trim()),
        headers: headers,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('课表页面访问失败，状态码 ${response.statusCode}');
      }

      final String body = utf8.decode(response.bodyBytes);
      final List<Course> parsedCourses = _parseTimetable(body);
      courses.addAll(parsedCourses);
      messages.add('自动导入课表 ${parsedCourses.length} 门课程。');
    } else {
      messages.add('未填写课表 URL，已跳过课表导入。');
    }

    if (config.gradeUrl.trim().isNotEmpty) {
      try {
        final http.Response response = await _client.get(
          Uri.parse(config.gradeUrl.trim()),
          headers: headers,
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          messages.add('成绩页面访问失败，状态码 ${response.statusCode}。');
        } else {
          final String body = utf8.decode(response.bodyBytes);
          final List<GradeEntry> parsedGrades = _parseGrades(body);
          grades.addAll(parsedGrades);
          if (parsedGrades.isEmpty) {
            messages.add('成绩页面已访问，但未识别到可导入成绩。可在页面查看后手动录入。');
          } else {
            messages.add('自动导入成绩 ${parsedGrades.length} 条。');
          }
        }
      } catch (_) {
        messages.add('成绩链接访问失败，可先手动录入成绩。');
      }
    } else {
      messages.add('未填写成绩链接，已跳过成绩导入。');
    }

    if (courses.isEmpty && grades.isEmpty) {
      messages.add('未提取到有效数据，请检查教务系统链接和登录 Cookie。');
    }

    return AutoImportResult(
      courses: courses,
      grades: grades,
      messages: messages,
    );
  }

  AutoImportResult importFromExtractedPayload(Map<String, dynamic> payload) {
    final List<dynamic> rawList =
        (payload['courses'] as List<dynamic>?) ?? <dynamic>[];
    final List<_RawNwpuCourse> rawCourses = <_RawNwpuCourse>[];

    for (final dynamic item in rawList) {
      if (item is! Map) {
        continue;
      }
      final Map<String, dynamic> row = Map<String, dynamic>.from(item);
      final String name = _firstString(row, <String>[
        'name',
        'courseName',
        'title',
      ]);
      final String code = _firstString(row, <String>['code', 'courseCode']);
      String scheduleText = _firstString(row, <String>[
        'scheduleText',
        'schedule',
        'timeText',
        'timeDesc',
      ]);
      if (scheduleText.isEmpty) {
        scheduleText = _firstString(row, <String>['rowText', 'arrangeText']);
      }
      if (name.isEmpty) {
        continue;
      }

      final String teacher = _normalizeTeacher(
        _firstString(row, <String>['teacher', 'teacherName', 'jsxm']),
      );
      final bool isOnline = _isOnlineCourse(name, teacher, scheduleText);
      if (scheduleText.isEmpty && !isOnline) {
        continue;
      }

      String location = _firstString(row, <String>[
        'location',
        'classroom',
        'room',
      ]);
      // Location quality differs by source: prefer explicit fields, then row/schedule text fallback.
      location = _sanitizeLocationCandidate(location, courseCode: code);
      if (location.isEmpty) {
        location = _sanitizeLocationCandidate(
          _extractLocationFromScheduleText(
            _firstString(row, <String>['rowText']),
          ),
          courseCode: code,
        );
      }
      if (location.isEmpty) {
        location = _sanitizeLocationCandidate(
          _extractLocationFromScheduleText(scheduleText),
          courseCode: code,
        );
      }

      rawCourses.add(
        _RawNwpuCourse(
          name: name,
          code: code,
          credits:
              _parseDouble(
                _firstValue(row, <String>['credits', 'credit', 'xf']),
              ) ??
              0,
          teacher: teacher,
          location: location,
          scheduleText: scheduleText,
          dataSemester: _firstString(row, <String>['dataSemester', 'semester']),
          isOnline: isOnline,
        ),
      );
    }

    final List<Course> courses = _buildCoursesFromRaw(rawCourses);
    final int onlineCount = courses
        .where((Course course) => course.isOnline)
        .length;
    final List<dynamic> semesterList =
        (payload['semesters'] as List<dynamic>?) ?? <dynamic>[];
    final int semesterCount = semesterList
        .whereType<Map<dynamic, dynamic>>()
        .map(
          (Map<dynamic, dynamic> item) =>
              (item['dataSemester'] ?? item['name'] ?? '').toString().trim(),
        )
        .where((String value) => value.isNotEmpty)
        .toSet()
        .length;

    final List<String> messages = <String>[
      if (semesterCount > 0) '识别到 $semesterCount 个学期数据。',
      '页面提取到 ${rawCourses.length} 条课程，成功导入 ${courses.length} 门课程'
          '${onlineCount > 0 ? '（含 $onlineCount 门网课）' : ''}。',
      if (courses.isEmpty) '未识别到可导入课程，请确认当前页面是“我的课表-全部课程”。',
    ];

    return AutoImportResult(
      courses: courses,
      grades: const <GradeEntry>[],
      messages: messages,
    );
  }

  AutoImportResult importFromTimetableHtmlSnapshot(String html) {
    final List<Course> courses = _parseTimetable(html);
    return AutoImportResult(
      courses: courses,
      grades: const <GradeEntry>[],
      messages: <String>[
        '已解析本地课表页面，识别到 ${courses.length} 门课程。',
        if (courses.isEmpty) '未识别到课程，请确认导入的是“我的课表-全部课程”页面源码。',
      ],
    );
  }

  List<Course> _parseTimetable(String body) {
    // Prefer structured API JSON first; fallback to HTML scraping for JWXT pages.
    final List<Course> byJson = _parseTimetableFromJson(body);
    if (byJson.isNotEmpty) {
      return byJson;
    }

    final List<Course> byNwpuHtml = _parseNwpuJwxtHtml(body);
    if (byNwpuHtml.isNotEmpty) {
      return byNwpuHtml;
    }
    return <Course>[];
  }

  List<Course> _parseTimetableFromJson(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      final List<Map<String, dynamic>> rows = _extractRows(decoded);
      if (rows.isEmpty) {
        return <Course>[];
      }

      final List<Course> courses = <Course>[];
      for (final Map<String, dynamic> row in rows) {
        final Course? parsed = _parseCourseFromJson(row);
        if (parsed != null) {
          courses.add(parsed);
        }
      }
      return courses;
    } catch (_) {
      return <Course>[];
    }
  }

  List<Course> _parseNwpuJwxtHtml(String html) {
    final RegExp rowRegex = RegExp(
      r'<tr[^>]*class="[^"]*\blessonInfo\b[^"]*"[^>]*>[\s\S]*?</tr>',
      caseSensitive: false,
    );
    final RegExp tdRegex = RegExp(
      r'<td[^>]*>([\s\S]*?)</td>',
      caseSensitive: false,
    );

    final List<_RawNwpuCourse> rawCourses = <_RawNwpuCourse>[];
    for (final RegExpMatch rowMatch in rowRegex.allMatches(html)) {
      final String rowHtml = rowMatch.group(0) ?? '';
      if (rowHtml.isEmpty) {
        continue;
      }

      final String dataSemester =
          RegExp(
            r'data-semester="([^"]+)"',
            caseSensitive: false,
          ).firstMatch(rowHtml)?.group(1)?.trim() ??
          '';

      final String courseInfoHtml =
          RegExp(
            r'<td[^>]*class="[^"]*\bcourseInfo\b[^"]*"[^>]*>[\s\S]*?</td>',
            caseSensitive: false,
          ).firstMatch(rowHtml)?.group(0) ??
          '';
      final String courseFullName =
          RegExp(
            r'data-course="([^"]+)"',
            caseSensitive: false,
          ).firstMatch(courseInfoHtml)?.group(1)?.trim() ??
          '';
      final String code = _extractCourseCode(courseFullName);

      String courseName = _stripHtml(
        RegExp(
              r'<p[^>]*class="[^"]*\bshowSchedules\b[^"]*"[^>]*>([\s\S]*?)</p>',
              caseSensitive: false,
            ).firstMatch(courseInfoHtml)?.group(1) ??
            '',
      );
      if (courseName.isEmpty) {
        courseName = _stripHtml(
          RegExp(
                r'<p[^>]*>([\s\S]*?)</p>',
                caseSensitive: false,
              ).firstMatch(courseInfoHtml)?.group(1) ??
              '',
        );
      }
      if (courseName.isEmpty) {
        continue;
      }

      final String teacherRaw = _stripHtml(
        RegExp(
              r'(?:授课教师|教师)\s*[：:]\s*([^<\n]+)',
            ).firstMatch(rowHtml)?.group(1) ??
            '',
      );
      final double credits =
          double.tryParse(
            RegExp(r'学分\(([\d.]+)\)').firstMatch(rowHtml)?.group(1) ?? '',
          ) ??
          0;

      String scheduleText = '';
      String location = '';
      // JWXT table columns are not stable across semesters, so we scan all cells heuristically.
      for (final RegExpMatch cellMatch in tdRegex.allMatches(rowHtml)) {
        final String cellHtml = cellMatch.group(1) ?? '';
        final String cellText = _stripHtml(cellHtml);
        if (cellText.isEmpty) {
          continue;
        }
        if (scheduleText.isEmpty && _looksLikeScheduleText(cellText)) {
          scheduleText = cellText;
        }
        if (location.isEmpty && _looksLikeLocationText(cellText)) {
          location = _sanitizeLocationCandidate(
            _extractLocationFromScheduleText(cellText),
            courseCode: code,
          );
        }
      }

      if (scheduleText.isEmpty) {
        final String rowText = _stripHtml(rowHtml);
        if (_looksLikeScheduleText(rowText)) {
          scheduleText = rowText;
        }
      }
      if (scheduleText.isEmpty) {
        continue;
      }

      if (location.isEmpty) {
        location = _sanitizeLocationCandidate(
          _extractLocationFromScheduleText(scheduleText),
          courseCode: code,
        );
      }
      if (location.isEmpty) {
        location = _sanitizeLocationCandidate(
          _extractLocationFromScheduleText(_stripHtml(rowHtml)),
          courseCode: code,
        );
      }

      final String teacher = _normalizeTeacher(teacherRaw);
      final bool isOnline = _isOnlineCourse(courseName, teacher, scheduleText);

      rawCourses.add(
        _RawNwpuCourse(
          name: courseName,
          code: code,
          credits: credits,
          teacher: teacher,
          location: location,
          scheduleText: scheduleText,
          dataSemester: dataSemester,
          isOnline: isOnline,
        ),
      );
    }
    return _buildCoursesFromRaw(rawCourses);
  }

  List<Course> _buildCoursesFromRaw(List<_RawNwpuCourse> rawCourses) {
    if (rawCourses.isEmpty) {
      return <Course>[];
    }

    final Map<String, Course> merged = <String, Course>{};
    for (final _RawNwpuCourse raw in rawCourses) {
      final String normalizedLocation = _sanitizeLocationCandidate(
        raw.location,
        courseCode: raw.code,
      );
      if (raw.isOnline) {
        final String key =
            '${raw.name}|${raw.teacher}|${raw.code}|${raw.dataSemester}|online';
        merged[key] = Course(
          name: raw.name,
          semesterId: raw.dataSemester,
          code: raw.code,
          teacher: raw.teacher,
          location: normalizedLocation,
          credit: raw.credits,
          colorValue: _colorByName(raw.name),
          courseType: CourseType.online,
          sessions: const <CourseSession>[],
        );
        continue;
      }

      final List<_ParsedSlot> slots = _parseScheduleText(raw.scheduleText);
      if (slots.isEmpty) {
        continue;
      }

      final List<CourseSession> sessions = <CourseSession>[];
      for (final _ParsedSlot slot in slots) {
        final int safeStartWeek = slot.startWeek < 1 ? 1 : slot.startWeek;
        final int safeEndWeek = slot.endWeek < safeStartWeek
            ? safeStartWeek
            : slot.endWeek;
        final List<({int start, int end})> contiguousRanges =
            _toContinuousRanges(slot.classSections);
        for (final ({int start, int end}) range in contiguousRanges) {
          sessions.add(
            CourseSession(
              weekday: slot.dayOfWeek,
              startPeriod: range.start,
              endPeriod: range.end,
              startWeek: safeStartWeek,
              endWeek: safeEndWeek,
              weekType: slot.weekType,
            ),
          );
        }
      }

      if (sessions.isEmpty) {
        continue;
      }

      // Merge fragments of the same course (same identity fields, different time slots).
      final String key =
          '${raw.name}|${raw.teacher}|$normalizedLocation|${raw.credits.toStringAsFixed(2)}';
      if (!merged.containsKey(key)) {
        merged[key] = Course(
          name: raw.name,
          semesterId: raw.dataSemester,
          code: raw.code,
          teacher: raw.teacher,
          location: normalizedLocation,
          credit: raw.credits,
          colorValue: _colorByName(raw.name),
          courseType: CourseType.scheduled,
          sessions: sessions,
        );
      } else {
        final Course existing = merged[key]!;
        merged[key] = existing.copyWith(
          sessions: _mergeSessions(existing.sessions, sessions),
        );
      }
    }
    return merged.values.toList();
  }

  List<GradeEntry> _parseGrades(String body) {
    final List<GradeEntry> jsonGrades = _parseGradesFromJson(body);
    if (jsonGrades.isNotEmpty) {
      return jsonGrades;
    }
    return _parseGradesFromHtml(body);
  }

  List<GradeEntry> _parseGradesFromJson(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      final List<Map<String, dynamic>> rows = _extractRows(decoded);
      final List<GradeEntry> grades = <GradeEntry>[];
      for (final Map<String, dynamic> row in rows) {
        final GradeEntry? parsed = _parseGradeFromJson(row);
        if (parsed != null) {
          grades.add(parsed);
        }
      }
      return grades;
    } catch (_) {
      return <GradeEntry>[];
    }
  }

  List<GradeEntry> _parseGradesFromHtml(String html) {
    final RegExp trRegex = RegExp(
      r'<tr[^>]*>([\s\S]*?)</tr>',
      caseSensitive: false,
    );
    final RegExp cellRegex = RegExp(
      r'<t[dh][^>]*>([\s\S]*?)</t[dh]>',
      caseSensitive: false,
    );
    final List<List<String>> rows = <List<String>>[];

    for (final RegExpMatch rowMatch in trRegex.allMatches(html)) {
      final String rowHtml = rowMatch.group(1) ?? '';
      final List<String> cells = cellRegex
          .allMatches(rowHtml)
          .map((RegExpMatch m) => _stripHtml(m.group(1) ?? ''))
          .map((String text) => text.trim())
          .where((String text) => text.isNotEmpty)
          .toList();
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }

    if (rows.isEmpty) {
      return <GradeEntry>[];
    }

    int courseIdx = -1;
    int creditIdx = -1;
    int scoreIdx = -1;
    int gpaIdx = -1;

    final List<GradeEntry> grades = <GradeEntry>[];
    for (final List<String> row in rows) {
      // Header labels vary by school/year, so detect headers by semantic keywords.
      final bool isHeader = row.any(
        (String c) =>
            c.contains('课程') ||
            c.contains('科目') ||
            c.contains('学分') ||
            c.contains('成绩') ||
            c.contains('绩点'),
      );
      if (isHeader) {
        for (int i = 0; i < row.length; i++) {
          final String c = row[i];
          if (courseIdx == -1 && (c.contains('课程') || c.contains('科目'))) {
            courseIdx = i;
          }
          if (creditIdx == -1 && c.contains('学分')) {
            creditIdx = i;
          }
          if (scoreIdx == -1 &&
              (c.contains('成绩') || c.contains('总评') || c.contains('分数'))) {
            scoreIdx = i;
          }
          if (gpaIdx == -1 && c.contains('绩点')) {
            gpaIdx = i;
          }
        }
        continue;
      }

      String courseName = '';
      if (courseIdx >= 0 && courseIdx < row.length) {
        courseName = row[courseIdx].trim();
      }
      if (courseName.isEmpty) {
        courseName = row.firstWhere(
          (String c) =>
              RegExp(r'[\u4e00-\u9fa5A-Za-z]').hasMatch(c) && c.length >= 2,
          orElse: () => '',
        );
      }
      if (courseName.isEmpty) {
        continue;
      }

      double? credit;
      if (creditIdx >= 0 && creditIdx < row.length) {
        credit = _parseDouble(row[creditIdx]);
      }
      credit ??= row
          .map(_parseDouble)
          .whereType<double>()
          .firstWhere((double v) => v > 0 && v <= 20, orElse: () => 0);

      double? score;
      if (scoreIdx >= 0 && scoreIdx < row.length) {
        score = _parseDouble(row[scoreIdx]);
      }
      score ??= row
          .map(_parseDouble)
          .whereType<double>()
          .firstWhere((double v) => v >= 0 && v <= 100, orElse: () => -1);
      if (score < 0) {
        score = null;
      }

      double? gpa;
      if (gpaIdx >= 0 && gpaIdx < row.length) {
        gpa = _parseDouble(row[gpaIdx]);
      }
      gpa ??= row
          .map(_parseDouble)
          .whereType<double>()
          .firstWhere((double v) => v >= 0 && v <= 5, orElse: () => -1);
      if (gpa < 0) {
        gpa = null;
      }

      grades.add(
        GradeEntry(
          courseName: courseName,
          credit: credit,
          score: score,
          gradePoint: gpa,
        ),
      );
    }
    return grades;
  }

  List<_ParsedSlot> _parseScheduleText(String scheduleText) {
    final String cleanedText = scheduleText
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanedText.isEmpty) {
      return <_ParsedSlot>[];
    }

    final List<String> scheduleParts = <String>[];
    final List<String> semicolonParts = cleanedText
        .split(RegExp(r'[;；]'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();
    for (final String part in semicolonParts) {
      scheduleParts.addAll(_splitByWeekRanges(part));
    }
    if (scheduleParts.isEmpty) {
      scheduleParts.addAll(_splitByWeekRanges(cleanedText));
    }

    final List<_ParsedSlot> slots = <_ParsedSlot>[];
    for (final String rawPart in scheduleParts) {
      final String part = rawPart.trim();
      if (part.isEmpty || part.contains('网课')) {
        continue;
      }

      final ({int start, int end}) weekRange =
          _parseWeekRange(part) ?? (start: 1, end: 20);

      final int? dayOfWeek = _parseWeekday(part);
      if (dayOfWeek == null) {
        continue;
      }

      final List<int> sections = _parseSectionsFromText(part);
      if (sections.isEmpty) {
        continue;
      }

      WeekType weekType = WeekType.all;
      if (part.contains('单周') || part.contains('(单)')) {
        weekType = WeekType.odd;
      } else if (part.contains('双周') || part.contains('(双)')) {
        weekType = WeekType.even;
      }

      slots.add(
        _ParsedSlot(
          startWeek: weekRange.start,
          endWeek: weekRange.end,
          dayOfWeek: dayOfWeek,
          classSections: sections,
          weekType: weekType,
        ),
      );
    }

    return _mergeSlots(slots);
  }

  List<String> _splitByWeekRanges(String text) {
    final RegExp dayPattern = RegExp(
      r'(周一|周二|周三|周四|周五|周六|周日|周天|星期一|星期二|星期三|星期四|星期五|星期六|星期日|星期天)',
    );
    final List<RegExpMatch> dayMatches = dayPattern.allMatches(text).toList();
    if (dayMatches.isEmpty) {
      return <String>[text];
    }

    if (dayMatches.length == 1) {
      final int dayPos = dayMatches.first.start;
      final String beforeDay = text.substring(0, dayPos).trim();
      final String afterDay = text.substring(dayPos).trim();
      final List<String> weekParts = beforeDay
          .split(RegExp(r'[,，]'))
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
      if (weekParts.isEmpty) {
        return <String>[text];
      }
      return weekParts.map((String p) => '$p $afterDay'.trim()).toList();
    }

    final String globalWeekPrefix = _extractWeekPrefix(
      text.substring(0, dayMatches.first.start).trim(),
    );

    final List<String> result = <String>[];
    for (int i = 0; i < dayMatches.length; i++) {
      final int start = dayMatches[i].start;
      final int end = i == dayMatches.length - 1
          ? text.length
          : dayMatches[i + 1].start;
      String segment = text.substring(start, end).trim();
      segment = segment.replaceFirst(RegExp(r'^[,，;；]\s*'), '');
      if (segment.isEmpty) {
        continue;
      }
      if (!_containsWeekRange(segment) && globalWeekPrefix.isNotEmpty) {
        segment = '$globalWeekPrefix $segment';
      }
      result.add(segment.trim());
    }
    return result.isEmpty ? <String>[text] : result;
  }

  ({int start, int end})? _parseWeekRange(String text) {
    final RegExp explicitRange = RegExp(
      r'(\d{1,3})\s*[~至\-—～]\s*(\d{1,3})\s*周',
    );
    for (final RegExpMatch match in explicitRange.allMatches(text)) {
      final ({int start, int end})? parsed = _parseWeekMatch(match);
      if (parsed != null) {
        return parsed;
      }
    }

    final RegExp explicitSingle = RegExp(r'(?<!\d)(\d{1,3})\s*周');
    for (final RegExpMatch match in explicitSingle.allMatches(text)) {
      final int week = int.parse(match.group(1)!);
      if (week >= 1 && week <= 53) {
        return (start: week, end: week);
      }
    }

    // 兼容极个别没有“周”字的格式，但要避开“7-8节”这类节次信息。
    final RegExp genericRange = RegExp(r'(\d{1,3})\s*[~至\-—～]\s*(\d{1,3})');
    for (final RegExpMatch match in genericRange.allMatches(text)) {
      if (_containsSectionMarkerNearby(text, match)) {
        continue;
      }
      final ({int start, int end})? parsed = _parseWeekMatch(match);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  List<int> _parseSectionsFromText(String text) {
    final RegExp chineseRange = RegExp(
      r'第(二十|十九|十八|十七|十六|十五|十四|十三|十二|十一|一|二|三|四|五|六|七|八|九|十)'
      r'[节~至\-—～至到]*(?:第)?(二十|十九|十八|十七|十六|十五|十四|十三|十二|十一|一|二|三|四|五|六|七|八|九|十)节?',
    );
    final RegExp withDiRange = RegExp(
      r'第(\d+)\s*节?\s*[~至\-—～到]\s*(?:第)?(\d+)\s*节?',
    );
    final RegExp plainRange = RegExp(r'(\d+)\s*节?\s*[~至\-—～到]\s*(\d+)\s*节');
    final RegExp withDiComma = RegExp(r'第((?:\d+[、,，]?)+)\s*节');
    final RegExp plainComma = RegExp(r'((?:\d+[、,，]?)+)\s*节');
    final RegExp chineseSingle = RegExp(
      r'第(二十|十九|十八|十七|十六|十五|十四|十三|十二|十一|一|二|三|四|五|六|七|八|九|十)节',
    );
    final RegExp withDiSingle = RegExp(r'第(\d+)节');
    final RegExp plainSingle = RegExp(r'(\d+)节');

    RegExpMatch? m = chineseRange.firstMatch(text);
    if (m != null) {
      final int start = _chineseNumToArabic(m.group(1)!);
      final int end = _chineseNumToArabic(m.group(2)!);
      return _rangeToList(start, end);
    }

    m = withDiRange.firstMatch(text);
    if (m != null) {
      return _rangeToList(int.parse(m.group(1)!), int.parse(m.group(2)!));
    }

    m = plainRange.firstMatch(text);
    if (m != null) {
      return _rangeToList(int.parse(m.group(1)!), int.parse(m.group(2)!));
    }

    m = withDiComma.firstMatch(text);
    if (m != null) {
      return m
          .group(1)!
          .split(RegExp(r'[、,，]'))
          .map((String s) => int.tryParse(s) ?? -1)
          .where((int x) => x > 0)
          .toList();
    }

    m = plainComma.firstMatch(text);
    if (m != null) {
      return m
          .group(1)!
          .split(RegExp(r'[、,，]'))
          .map((String s) => int.tryParse(s) ?? -1)
          .where((int x) => x > 0)
          .toList();
    }

    m = chineseSingle.firstMatch(text);
    if (m != null) {
      final int section = _chineseNumToArabic(m.group(1)!);
      return section > 0 ? <int>[section] : <int>[];
    }

    m = withDiSingle.firstMatch(text);
    if (m != null) {
      final int section = int.parse(m.group(1)!);
      return section > 0 ? <int>[section] : <int>[];
    }

    m = plainSingle.firstMatch(text);
    if (m != null) {
      final int section = int.parse(m.group(1)!);
      return section > 0 ? <int>[section] : <int>[];
    }

    // 兜底：有些页面会写成“周三 7-8”或“周三第7-8”，这里仅在“周几”之后解析节次，
    // 避免把“1-16周”误当成节次。
    final RegExp dayRegex = RegExp(
      r'(周一|周二|周三|周四|周五|周六|周日|周天|星期一|星期二|星期三|星期四|星期五|星期六|星期日|星期天)',
    );
    final RegExpMatch? dayMatch = dayRegex.firstMatch(text);
    if (dayMatch != null) {
      final String afterDay = text.substring(dayMatch.end);
      final RegExp fallbackRange = RegExp(r'(\d{1,2})\s*[~至\-—～到]\s*(\d{1,2})');
      final RegExpMatch? fallback = fallbackRange.firstMatch(afterDay);
      if (fallback != null) {
        final int start = int.parse(fallback.group(1)!);
        final int end = int.parse(fallback.group(2)!);
        if (start >= 1 && end >= start && end <= 24) {
          return _rangeToList(start, end);
        }
      }
      final RegExp fallbackSingle = RegExp(r'(\d{1,2})(?:\s*节)?');
      final RegExpMatch? single = fallbackSingle.firstMatch(afterDay);
      if (single != null) {
        final int value = int.parse(single.group(1)!);
        if (value >= 1 && value <= 24) {
          return <int>[value];
        }
      }
    }
    return <int>[];
  }

  String _extractWeekPrefix(String text) {
    if (text.isEmpty) {
      return '';
    }
    final RegExp weekToken = RegExp(
      r'(\d{1,2}\s*[~至\-—～]\s*\d{1,2}\s*周(?:\s*\((?:单|双)\))?|\d{1,2}\s*周(?:\s*\((?:单|双)\))?)',
    );
    final Iterable<RegExpMatch> matches = weekToken.allMatches(text);
    if (matches.isEmpty) {
      return '';
    }
    return matches.map((RegExpMatch m) => m.group(0)!.trim()).join(' ');
  }

  bool _containsWeekRange(String text) {
    return RegExp(r'\d{1,2}\s*(?:[~至\-—～]\s*\d{1,2})?\s*周').hasMatch(text);
  }

  ({int start, int end})? _parseWeekMatch(RegExpMatch match) {
    final int start = int.parse(match.group(1)!);
    final int end = int.parse(match.group(2)!);
    if (start < 1 || end < 1 || start > 53 || end > 53) {
      return null;
    }
    return (start: start, end: end < start ? start : end);
  }

  bool _containsSectionMarkerNearby(String text, RegExpMatch match) {
    final int start = match.start;
    final int end = match.end;
    final int from = start - 2 < 0 ? 0 : start - 2;
    final int to = end + 2 > text.length ? text.length : end + 2;
    final String around = text.substring(from, to);
    return around.contains('节');
  }

  List<_ParsedSlot> _mergeSlots(List<_ParsedSlot> slots) {
    if (slots.isEmpty) {
      return <_ParsedSlot>[];
    }

    final Map<String, List<_ParsedSlot>> grouped =
        <String, List<_ParsedSlot>>{};
    for (final _ParsedSlot slot in slots) {
      final List<int> sortedSections = List<int>.from(slot.classSections)
        ..sort();
      final String key =
          '${slot.dayOfWeek}|${sortedSections.join(",")}|${slot.weekType.name}';
      grouped.putIfAbsent(key, () => <_ParsedSlot>[]).add(slot);
    }

    final List<_ParsedSlot> merged = <_ParsedSlot>[];
    for (final List<_ParsedSlot> group in grouped.values) {
      group.sort((a, b) => a.startWeek.compareTo(b.startWeek));
      _ParsedSlot current = group.first;
      for (final _ParsedSlot next in group.skip(1)) {
        if (next.startWeek <= current.endWeek + 1) {
          current = current.copyWith(
            endWeek: next.endWeek > current.endWeek
                ? next.endWeek
                : current.endWeek,
          );
        } else {
          merged.add(current);
          current = next;
        }
      }
      merged.add(current);
    }
    return merged;
  }

  List<CourseSession> _mergeSessions(
    List<CourseSession> a,
    List<CourseSession> b,
  ) {
    final List<CourseSession> merged = <CourseSession>[...a];
    for (final CourseSession session in b) {
      final bool exists = merged.any(
        (CourseSession x) =>
            x.weekday == session.weekday &&
            x.startPeriod == session.startPeriod &&
            x.endPeriod == session.endPeriod &&
            x.startWeek == session.startWeek &&
            x.endWeek == session.endWeek &&
            x.weekType == session.weekType,
      );
      if (!exists) {
        merged.add(session);
      }
    }
    return merged;
  }

  List<({int start, int end})> _toContinuousRanges(List<int> sections) {
    final List<int> sorted = sections.where((int s) => s > 0).toSet().toList()
      ..sort();
    if (sorted.isEmpty) {
      return <({int start, int end})>[];
    }
    final List<({int start, int end})> ranges = <({int start, int end})>[];
    int start = sorted.first;
    int prev = sorted.first;
    for (final int value in sorted.skip(1)) {
      if (value == prev + 1) {
        prev = value;
      } else {
        ranges.add((start: start, end: prev));
        start = value;
        prev = value;
      }
    }
    ranges.add((start: start, end: prev));
    return ranges;
  }

  List<int> _rangeToList(int start, int end) {
    final int s = start < 1 ? 1 : start;
    final int e = end < s ? s : end;
    return List<int>.generate(e - s + 1, (int i) => s + i);
  }

  int _chineseNumToArabic(String chineseNum) {
    const Map<String, int> map = <String, int>{
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
      '十': 10,
      '十一': 11,
      '十二': 12,
      '十三': 13,
      '十四': 14,
      '十五': 15,
      '十六': 16,
      '十七': 17,
      '十八': 18,
      '十九': 19,
      '二十': 20,
    };
    return map[chineseNum] ?? 0;
  }

  String _normalizeTeacher(String raw) {
    final String teacher = raw.trim();
    if (teacher.isEmpty) {
      return '';
    }
    final List<String> separators = <String>['、', '，', ','];
    for (final String separator in separators) {
      if (teacher.contains(separator)) {
        final List<String> teachers = teacher
            .split(separator)
            .map((String t) => t.trim())
            .where((String t) => t.isNotEmpty)
            .toList();
        if (teachers.length > 15) {
          return '${teachers.take(15).join('、')} 等';
        }
        return teachers.join('、');
      }
    }
    return teacher;
  }

  String _extractLocationFromScheduleText(String text) {
    final String cleanText = text
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleanText.isEmpty) {
      return '';
    }

    final String withoutTime = cleanText
        .replaceAll(
          RegExp(r'\d{1,2}\s*[~至\-—～]\s*\d{1,2}\s*周(?:\([单双]\))?'),
          ' ',
        )
        .replaceAll(
          RegExp(r'(周一|周二|周三|周四|周五|周六|周日|周天|星期一|星期二|星期三|星期四|星期五|星期六|星期日|星期天)'),
          ' ',
        )
        .replaceAll(RegExp(r'第?\d{1,2}\s*[~至\-—～到]?\s*\d{0,2}\s*节'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final String sourceText = withoutTime.isEmpty ? cleanText : withoutTime;

    final List<RegExp> patterns = <RegExp>[
      RegExp(r'(长安校区|翠华校区|雁塔校区|未央校区|沣东校区|草堂校区|友谊校区|太白校区|曲江校区)\s*([^\s,;]+)'),
      RegExp(r'(长安|翠华|雁塔|未央|沣东|草堂|友谊|太白|曲江)\s*校区\s*([^\s,;]+)'),
      RegExp(r'(教东|教西|教南|教北|教学东楼|教学西楼|教学南楼|教学北楼)\s*([A-Za-z]?\d+(?:[-－]\d+)?)'),
      RegExp(r'([一二三四五六七八九十0-9]+号?教学楼)\s*([A-Za-z]?\d+(?:[-－]\d+)?)'),
      RegExp(r'(\S+楼)\s*([^\s,;]+)'),
      RegExp(r'(\S+教学楼)\s*([^\s,;]+)'),
      RegExp(r'(\S+实验楼)\s*([^\s,;]+)'),
      RegExp(r'([A-RT-Za-rt-z]{1,3}\d{2,4}(?:[-－]\d{1,4})?)'),
      RegExp(r'(教[东西南北]\s*[A-Za-z]?\d+(?:[-－]\d+)?)'),
      RegExp(r'(\d{3,4}[A-Za-z]?)\s*(教室|室)'),
      RegExp(r'(\d+室)'),
      RegExp(r'(\d+教室)'),
      RegExp(r'(教\w+\d+[-\d]*)'),
    ];

    for (final RegExp pattern in patterns) {
      final RegExpMatch? match = pattern.firstMatch(sourceText);
      if (match != null) {
        final String g1 = match.groupCount >= 1
            ? (match.group(1) ?? '').trim()
            : '';
        final String g2 = match.groupCount >= 2
            ? (match.group(2) ?? '').trim()
            : '';
        if (g1.isNotEmpty && g2.isNotEmpty) {
          return _sanitizeLocationCandidate('$g1 $g2');
        }
        if (g1.isNotEmpty) {
          return _sanitizeLocationCandidate(g1);
        }
      }
    }
    return '';
  }

  String _sanitizeLocationCandidate(String value, {String courseCode = ''}) {
    String normalized = value
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) {
      return '';
    }

    final String compact = normalized
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final String compactCode = courseCode
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();

    // 过滤明显不是地点、而是课程代码片段的值（如 "U8"）。
    if (RegExp(r'^[A-Z]\d$').hasMatch(compact)) {
      return '';
    }
    if (RegExp(r'^[U]\d[A-Z0-9]*$').hasMatch(compact)) {
      return '';
    }
    if (compactCode.isNotEmpty) {
      if (compact == compactCode) {
        return '';
      }
      if (compact.length <= 2 && compactCode.startsWith(compact)) {
        return '';
      }
    }

    if (normalized.length <= 2 &&
        !RegExp(r'(楼|室|教室|校区)').hasMatch(normalized)) {
      return '';
    }

    return normalized;
  }

  bool _looksLikeScheduleText(String text) {
    final bool hasWeekday = RegExp(
      r'(周一|周二|周三|周四|周五|周六|周日|周天|星期一|星期二|星期三|星期四|星期五|星期六|星期日|星期天)',
    ).hasMatch(text);
    final bool hasSections = RegExp(
      r'(第?\s*[一二三四五六七八九十\d]{1,2}\s*[~至\-—～到]?\s*[一二三四五六七八九十\d]{0,2}\s*节?)',
    ).hasMatch(text);
    final bool hasWeeks = RegExp(
      r'\d{1,2}\s*(?:[~至\-—～]\s*\d{1,2})?\s*周',
    ).hasMatch(text);
    return hasWeekday && (hasSections || hasWeeks);
  }

  bool _looksLikeLocationText(String text) {
    return RegExp(
      r'(校区|教学楼|实验楼|教东|教西|教南|教北|\d+教室|\d+室|[A-Za-z]{1,3}\d{2,4}(?:[-－]\d{1,4})?)',
    ).hasMatch(text);
  }

  bool _isOnlineCourse(String name, String teacher, String scheduleText) {
    const List<String> onlineKeywords = <String>[
      '网课',
      '在线开放课程',
      '在线',
      '网络课程',
      '网络',
      'mooc',
      '不排课',
    ];
    final String textToCheck = '$name $teacher $scheduleText'.toLowerCase();
    return onlineKeywords.any(
      (String keyword) => textToCheck.contains(keyword),
    );
  }

  String _extractCourseCode(String courseFullName) {
    final RegExpMatch? m = RegExp(r'\[([^\]]+)\]').firstMatch(courseFullName);
    return m == null ? '' : (m.group(1) ?? '');
  }

  String _stripHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&#160;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<Map<String, dynamic>> _extractRows(dynamic data) {
    if (data is List<dynamic>) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      const List<String> keys = <String>[
        'data',
        'rows',
        'list',
        'result',
        'items',
        'records',
      ];
      for (final String key in keys) {
        final dynamic value = data[key];
        if (value is List<dynamic>) {
          return value.whereType<Map<String, dynamic>>().toList();
        }
        if (value is Map<String, dynamic>) {
          for (final String nested in keys) {
            final dynamic nestedValue = value[nested];
            if (nestedValue is List<dynamic>) {
              return nestedValue.whereType<Map<String, dynamic>>().toList();
            }
          }
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  Course? _parseCourseFromJson(Map<String, dynamic> item) {
    final String name = _firstString(item, <String>[
      'courseName',
      'kcmc',
      'name',
      'title',
      'course',
    ]);
    if (name.isEmpty) {
      return null;
    }

    final String teacher = _firstString(item, <String>[
      'teacher',
      'xm',
      'jsxm',
      'teacherName',
    ]);
    final String code = _firstString(item, <String>[
      'courseCode',
      'kch',
      'code',
      'courseId',
    ]);
    final String semesterId = _firstString(item, <String>[
      'semesterId',
      'xnxq',
      'xq',
      'dataSemester',
    ]);
    final String location = _firstString(item, <String>[
      'location',
      'classroom',
      'jxcdmc',
      'room',
    ]);
    final String scheduleText = _firstString(item, <String>[
      'timeText',
      'timeDesc',
      'sjms',
      'scheduleText',
      'arrangeText',
    ]);
    final int? weekday = _parseWeekday(
      _firstValue(item, <String>[
        'weekday',
        'dayOfWeek',
        'xqj',
        'weekDay',
        'day',
      ]),
      fallbackText: _firstString(item, <String>[
        'timeText',
        'timeDesc',
        'sjms',
      ]),
    );
    final ({int start, int end}) section = _parseSections(item);
    final ({int startWeek, int endWeek, WeekType weekType}) weeks = _parseWeeks(
      item,
    );
    final double credit =
        _parseDouble(_firstValue(item, <String>['credit', 'xf'])) ?? 0;
    final bool isOnline = _isOnlineCourse(name, teacher, scheduleText);

    if (weekday == null && !isOnline) {
      return null;
    }

    return Course(
      name: name,
      semesterId: semesterId,
      code: code,
      teacher: teacher,
      location: location,
      credit: credit,
      colorValue: _colorByName(name),
      courseType: isOnline ? CourseType.online : CourseType.scheduled,
      sessions: isOnline
          ? const <CourseSession>[]
          : <CourseSession>[
              CourseSession(
                weekday: weekday!,
                startPeriod: section.start,
                endPeriod: section.end,
                startWeek: weeks.startWeek,
                endWeek: weeks.endWeek,
                weekType: weeks.weekType,
              ),
            ],
    );
  }

  GradeEntry? _parseGradeFromJson(Map<String, dynamic> item) {
    final String courseName = _firstString(item, <String>[
      'courseName',
      'kcmc',
      'name',
      'title',
      'course',
    ]);
    if (courseName.isEmpty) {
      return null;
    }

    final double credit =
        _parseDouble(_firstValue(item, <String>['credit', 'xf'])) ?? 0;
    final double? score = _parseDouble(
      _firstValue(item, <String>['score', 'cj', 'grade']),
    );
    final double? gradePoint = _parseDouble(
      _firstValue(item, <String>['gradePoint', 'jd', 'gpa']),
    );

    return GradeEntry(
      courseName: courseName,
      credit: credit,
      score: score,
      gradePoint: gradePoint,
    );
  }

  ({int start, int end}) _parseSections(Map<String, dynamic> item) {
    final int? start = _parseInt(
      _firstValue(item, <String>['startSection', 'ksjc', 'start']),
    );
    final int? end = _parseInt(
      _firstValue(item, <String>['endSection', 'jsjc', 'end']),
    );
    if (start != null && end != null) {
      return (start: start, end: end < start ? start : end);
    }

    final String sectionText = _firstString(item, <String>[
      'sectionText',
      'jc',
      'timeSection',
      'period',
      'timeText',
    ]);
    final RegExp range = RegExp(r'(\d+)\D+(\d+)');
    final RegExpMatch? matched = range.firstMatch(sectionText);
    if (matched != null) {
      final int s = int.parse(matched.group(1)!);
      final int e = int.parse(matched.group(2)!);
      return (start: s, end: e < s ? s : e);
    }

    final RegExp single = RegExp(r'(\d+)');
    final Iterable<RegExpMatch> all = single.allMatches(sectionText);
    if (all.isNotEmpty) {
      final List<int> numbers = all
          .map((RegExpMatch m) => int.parse(m.group(1)!))
          .toList();
      return (start: numbers.first, end: numbers.last);
    }
    return (start: 1, end: 2);
  }

  ({int startWeek, int endWeek, WeekType weekType}) _parseWeeks(
    Map<String, dynamic> item,
  ) {
    final int? startWeek = _parseInt(
      _firstValue(item, <String>['startWeek', 'ksz']),
    );
    final int? endWeek = _parseInt(
      _firstValue(item, <String>['endWeek', 'jsz']),
    );
    WeekType weekType = WeekTypeCodec.fromJson(
      _firstValue(item, <String>[
        'weekType',
        'weeksType',
        'weekPattern',
      ])?.toString(),
    );

    final String weekText = _firstString(item, <String>[
      'weekText',
      'zcd',
      'weekRange',
    ]);
    if (weekText.contains('单')) {
      weekType = WeekType.odd;
    } else if (weekText.contains('双')) {
      weekType = WeekType.even;
    }

    if (startWeek != null && endWeek != null) {
      return (startWeek: startWeek, endWeek: endWeek, weekType: weekType);
    }

    final RegExp range = RegExp(r'(\d+)\D+(\d+)');
    final RegExpMatch? matched = range.firstMatch(weekText);
    if (matched != null) {
      final int s = int.parse(matched.group(1)!);
      final int e = int.parse(matched.group(2)!);
      return (startWeek: s, endWeek: e < s ? s : e, weekType: weekType);
    }

    return (startWeek: 1, endWeek: 20, weekType: weekType);
  }

  int? _parseWeekday(dynamic value, {String fallbackText = ''}) {
    if (value is num) {
      final int weekday = value.toInt();
      return (weekday >= 1 && weekday <= 7) ? weekday : null;
    }
    final String text = (value?.toString() ?? fallbackText).trim();
    if (text.isEmpty) {
      return null;
    }
    if (text.contains('周一') ||
        text.contains('星期一') ||
        text.toLowerCase().contains('mon')) {
      return DateTime.monday;
    }
    if (text.contains('周二') ||
        text.contains('星期二') ||
        text.toLowerCase().contains('tue')) {
      return DateTime.tuesday;
    }
    if (text.contains('周三') ||
        text.contains('星期三') ||
        text.toLowerCase().contains('wed')) {
      return DateTime.wednesday;
    }
    if (text.contains('周四') ||
        text.contains('星期四') ||
        text.toLowerCase().contains('thu')) {
      return DateTime.thursday;
    }
    if (text.contains('周五') ||
        text.contains('星期五') ||
        text.toLowerCase().contains('fri')) {
      return DateTime.friday;
    }
    if (text.contains('周六') ||
        text.contains('星期六') ||
        text.toLowerCase().contains('sat')) {
      return DateTime.saturday;
    }
    if (text.contains('周日') ||
        text.contains('周天') ||
        text.contains('星期日') ||
        text.contains('星期天') ||
        text.toLowerCase().contains('sun')) {
      return DateTime.sunday;
    }
    return int.tryParse(text);
  }

  dynamic _firstValue(Map<String, dynamic> item, List<String> keys) {
    for (final String key in keys) {
      if (item.containsKey(key) && item[key] != null) {
        return item[key];
      }
    }
    return null;
  }

  String _firstString(Map<String, dynamic> item, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = item[key];
      if (value != null) {
        final String text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return '';
  }

  int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString().trim());
  }

  double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    final String text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    final RegExp firstNumber = RegExp(r'[-+]?\d+(\.\d+)?');
    final Match? match = firstNumber.firstMatch(text);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(0)!);
  }

  int _colorByName(String name) {
    final List<int> palette = <int>[
      0xFF4A90E2,
      0xFF00A38C,
      0xFF4E6AF3,
      0xFF2F855A,
      0xFFD97706,
      0xFF0E7490,
      0xFF334155,
      0xFF4F46E5,
      0xFF0F766E,
      0xFF1D4ED8,
    ];
    int hash = 0;
    for (final int code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return palette[hash % palette.length];
  }
}

class _RawNwpuCourse {
  const _RawNwpuCourse({
    required this.name,
    required this.code,
    required this.credits,
    required this.teacher,
    required this.location,
    required this.scheduleText,
    required this.dataSemester,
    required this.isOnline,
  });

  final String name;
  final String code;
  final double credits;
  final String teacher;
  final String location;
  final String scheduleText;
  final String dataSemester;
  final bool isOnline;
}

class _ParsedSlot {
  const _ParsedSlot({
    required this.startWeek,
    required this.endWeek,
    required this.dayOfWeek,
    required this.classSections,
    required this.weekType,
  });

  final int startWeek;
  final int endWeek;
  final int dayOfWeek;
  final List<int> classSections;
  final WeekType weekType;

  _ParsedSlot copyWith({
    int? startWeek,
    int? endWeek,
    int? dayOfWeek,
    List<int>? classSections,
    WeekType? weekType,
  }) {
    return _ParsedSlot(
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      classSections: classSections ?? this.classSections,
      weekType: weekType ?? this.weekType,
    );
  }
}
