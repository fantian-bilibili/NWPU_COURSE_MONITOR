import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String _jwxtUrl = 'https://ecampus.nwpu.edu.cn/';
const String _desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

// Inject desktop-like viewport rules so JWXT table layouts remain usable in WebView.
const String _desktopViewportFixScript = r'''
(function () {
  try {
    var viewport = document.querySelector('meta[name="viewport"]');
    if (!viewport) {
      viewport = document.createElement('meta');
      viewport.setAttribute('name', 'viewport');
      document.head.appendChild(viewport);
    }
    viewport.setAttribute(
      'content',
      'width=device-width, initial-scale=1.0, minimum-scale=0.8, maximum-scale=3.0, user-scalable=yes, viewport-fit=cover'
    );

    var styleId = '__course_monitor_webview_fix__';
    var style = document.getElementById(styleId);
    if (!style) {
      style = document.createElement('style');
      style.id = styleId;
      document.head.appendChild(style);
    }
    style.textContent = ''
      + 'html, body {'
      + '  overflow: auto !important;'
      + '  height: auto !important;'
      + '  -webkit-overflow-scrolling: touch !important;'
      + '}'
      + 'body {'
      + '  min-width: 980px !important;'
      + '}'
      + '* {'
      + '  box-sizing: border-box;'
      + '}';

    if (document.body) {
      document.body.style.touchAction = 'auto';
    }
    if (document.documentElement) {
      document.documentElement.style.touchAction = 'auto';
    }
  } catch (_) {}
})();
''';

// Extract semester/course payload in page context and return it via JwxtImportChannel.
const String _extractDataScript = r'''
(function () {
  function post(message) {
    if (window.JwxtImportChannel && window.JwxtImportChannel.postMessage) {
      window.JwxtImportChannel.postMessage(message);
    }
  }

  function norm(value) {
    return String(value || '').replace(/\s+/g, ' ').trim();
  }

  function looksLikeLocation(text) {
    return /(校区|教学楼|实验楼|教东|教西|教南|教北|\d+教室|\d+室|[A-RT-Za-rt-z]{1,3}\d{2,}(?:[-－]\d{1,4})?|教[东西南北]\s*[A-Za-z]?\d+)/.test(text);
  }

  function looksLikeSchedule(text) {
    var hasWeekday = /(周[一二三四五六日天]|星期[一二三四五六日天])/.test(text);
    var hasSection = /(第?\s*[一二三四五六七八九十\d]{1,2}\s*[~至\-—～到]?\s*[一二三四五六七八九十\d]{0,2}\s*节?)/.test(text);
    var hasWeek = /(\d{1,2}\s*(?:[~至\-—～]\s*\d{1,2})?\s*周)/.test(text);
    return hasWeekday && (hasSection || hasWeek);
  }

  function extractLocation(value) {
    var text = norm(String(value || '').replace(/<[^>]+>/g, ' '));
    if (!text) {
      return '';
    }
    var patterns = [
      /(长安校区|翠华校区|雁塔校区|未央校区|沣东校区|草堂校区|友谊校区|太白校区|曲江校区)\s*([^\s,;]+)/,
      /(长安|翠华|雁塔|未央|沣东|草堂|友谊|太白|曲江)\s*校区\s*([^\s,;]+)/,
      /(教东|教西|教南|教北|教学东楼|教学西楼|教学南楼|教学北楼)\s*([A-Z]?\d+-?\d*)/,
      /([一二三四五六七八九十0-9]+号?教学楼)\s*([A-Za-z]?\d+(?:[-－]\d+)?)/,
      /(\S+教学楼)\s*([^\s,;]+)/,
      /(\S+实验楼)\s*([^\s,;]+)/,
      /([A-RT-Za-rt-z]{1,3}\d{2,4}(?:[-－]\d{1,4})?)/,
      /(教[东西南北]\s*[A-Za-z]?\d+(?:[-－]\d+)?)/,
      /(\d{3,4}[A-Za-z]?)\s*(教室|室)/,
      /(\d+教室)/,
      /(\d+室)/
    ];
    for (var i = 0; i < patterns.length; i++) {
      var match = text.match(patterns[i]);
      if (!match) {
        continue;
      }
      var g1 = norm(match[1] || '');
      var g2 = norm(match[2] || '');
      if (g1 && g2) {
        return (g1 + ' ' + g2).trim();
      }
      if (g1) {
        return g1;
      }
    }
    return '';
  }

  function sanitizeLocation(value, code) {
    var normalized = norm(String(value || ''));
    if (!normalized) {
      return '';
    }
    var compact = normalized.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
    var compactCode = norm(String(code || '')).replace(/[^A-Za-z0-9]/g, '').toUpperCase();
    if (/^[A-Z]\d$/.test(compact)) {
      return '';
    }
    if (/^U\d[A-Z0-9]*$/.test(compact)) {
      return '';
    }
    if (compactCode) {
      if (compact === compactCode) {
        return '';
      }
      if (compact.length <= 2 && compactCode.indexOf(compact) === 0) {
        return '';
      }
    }
    if (normalized.length <= 2 && !/(楼|室|教室|校区)/.test(normalized)) {
      return '';
    }
    return normalized;
  }

  function isOnlineCourse(name, teacher, scheduleText) {
    var haystack = norm(name + ' ' + teacher + ' ' + scheduleText).toLowerCase();
    var keywords = ['网课', '在线', 'mooc', '网络课程'];
    return keywords.some(function (k) {
      return haystack.indexOf(k) >= 0;
    });
  }

  function parseSemesters(doc) {
    var result = [];
    var select = doc.querySelector('#semesters');
    if (!select) {
      return result;
    }
    var options = select.querySelectorAll('option');
    for (var i = 0; i < options.length; i++) {
      var option = options[i];
      var value = norm(option.value);
      var name = norm(option.textContent);
      if (!value || value === 'all') {
        continue;
      }
      result.push({ name: name || value, dataSemester: value });
    }
    return result;
  }

  function parseCourseRow(row, fallbackSemester) {
    var nameNode =
      row.querySelector('.showSchedules') ||
      row.querySelector('td.courseInfo .showSchedules') ||
      row.querySelector('h3');
    var name = norm(nameNode ? nameNode.textContent : '');

    if (!name) {
      var courseInfo = row.querySelector('td.courseInfo');
      if (courseInfo) {
        var p = courseInfo.querySelector('p');
        name = norm(p ? p.textContent : '');
      }
    }
    if (!name || name.length < 2) {
      return null;
    }

    var rowText = norm(row.textContent || '');
    var rowHtml = String(row.innerHTML || '');
    var cells = row.querySelectorAll('td');

    var scheduleText = '';
    var scheduleHtml = '';
    var location = '';
    for (var i = 0; i < cells.length; i++) {
      var text = norm(cells[i].textContent || '');
      var html = String(cells[i].innerHTML || '');
      var titleText = norm((cells[i].getAttribute && cells[i].getAttribute('title')) || '');
      if (!scheduleText && looksLikeSchedule(text)) {
        scheduleText = text;
        scheduleHtml = html;
      }
      if (!location && text && looksLikeLocation(text)) {
        location = extractLocation(text);
      }
      if (!location) {
        location =
          extractLocation(text) ||
          extractLocation(titleText) ||
          extractLocation(html);
      }
    }

    if (!scheduleText && looksLikeSchedule(rowText)) {
      scheduleText = rowText;
    }
    if (scheduleHtml) {
      scheduleText = scheduleHtml;
    } else if (scheduleText && rowText && rowText.length > scheduleText.length) {
      scheduleText = rowText;
    } else if (!scheduleText) {
      scheduleText = rowHtml;
    }
    if (!location) {
      location =
        extractLocation(scheduleHtml) ||
        extractLocation(scheduleText) ||
        extractLocation(rowText) ||
        extractLocation(rowHtml);
    }

    var teacherMatch = rowHtml.match(/(?:授课教师|教师)\s*[：:]\s*([^<\n]+)/);
    var creditMatch = rowHtml.match(/学分\(([\d.]+)\)/);

    var courseInfoCell = row.querySelector('td.courseInfo');
    var fullCourseName = norm(
      courseInfoCell && courseInfoCell.getAttribute
        ? courseInfoCell.getAttribute('data-course')
        : ''
    );
    var codeMatch = fullCourseName.match(/\[([^\]]+)\]/);

    var dataSemester = norm(row.getAttribute('data-semester') || fallbackSemester || '');

    var course = {
      name: name,
      code: codeMatch ? norm(codeMatch[1]) : '',
      credits: creditMatch ? parseFloat(creditMatch[1]) : 0,
      teacher: teacherMatch ? norm(teacherMatch[1]) : '',
      location: sanitizeLocation(location, codeMatch ? norm(codeMatch[1]) : ''),
      scheduleText: scheduleText,
      rowText: rowText,
      dataSemester: dataSemester
    };

    if (!course.scheduleText && !isOnlineCourse(course.name, course.teacher, rowText)) {
      return null;
    }
    course.isOnline = isOnlineCourse(course.name, course.teacher, course.scheduleText || rowText);
    return course;
  }

  function collectDocuments() {
    var docs = [document];
    var iframes = document.querySelectorAll('iframe');
    for (var i = 0; i < iframes.length; i++) {
      try {
        var doc = iframes[i].contentDocument || iframes[i].contentWindow.document;
        if (doc) {
          docs.push(doc);
        }
      } catch (_) {}
    }
    return docs;
  }

  setTimeout(function () {
    try {
      var docs = collectDocuments();
      var courses = [];
      var semesterMap = {};
      var pageHtml = '';
      var bestDocScore = -1;

      for (var d = 0; d < docs.length; d++) {
        var doc = docs[d];

        var semesters = parseSemesters(doc);
        for (var s = 0; s < semesters.length; s++) {
          var item = semesters[s];
          if (!semesterMap[item.dataSemester]) {
            semesterMap[item.dataSemester] = item;
          }
        }

        var rows = doc.querySelectorAll('tr');
        var lessonRows = doc.querySelectorAll('tr.lessonInfo');
        var score = lessonRows.length * 1000 + rows.length;
        if (score > bestDocScore) {
          bestDocScore = score;
          pageHtml = doc.documentElement ? String(doc.documentElement.outerHTML || '') : '';
        }
        var currentSemester = '';
        for (var i = 0; i < rows.length; i++) {
          var row = rows[i];
          var rowSemester = norm(row.getAttribute('data-semester') || '');
          if (rowSemester) {
            currentSemester = rowSemester;
          }
          var parsed = parseCourseRow(row, currentSemester);
          if (!parsed) {
            continue;
          }
          courses.push(parsed);
          if (parsed.dataSemester && !semesterMap[parsed.dataSemester]) {
            semesterMap[parsed.dataSemester] = {
              name: parsed.dataSemester,
              dataSemester: parsed.dataSemester
            };
          }
        }
      }

      var semestersOut = Object.keys(semesterMap).map(function (key) {
        return semesterMap[key];
      });

      post(
        'DATA_EXTRACTED:' +
          JSON.stringify({
            semesters: semestersOut,
            courses: courses,
            pageHtml: pageHtml,
            pageUrl: window.location.href,
            extractedAt: new Date().toISOString()
          })
      );
    } catch (error) {
      var message = error && error.message ? error.message : String(error);
      post('ERROR:' + message);
    }
  }, 900);
})();
''';

class JwxtImportWebViewPage extends StatefulWidget {
  const JwxtImportWebViewPage({super.key});

  @override
  State<JwxtImportWebViewPage> createState() => _JwxtImportWebViewPageState();
}

class _JwxtImportWebViewPageState extends State<JwxtImportWebViewPage> {
  WebViewController? _controller;
  bool _extracting = false;
  bool _canExtract = false;
  int _progress = 0;
  String? _lastErrorMessage;
  DateTime? _lastErrorAt;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (!_supported) {
      return;
    }

    late final WebViewController controller;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _progress = 0;
              _canExtract = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) {
              return;
            }
            _applyDesktopViewport(controller);
            setState(() {
              _progress = 100;
              _canExtract = true;
            });
          },
          onProgress: (int progress) {
            if (!mounted) {
              return;
            }
            setState(() => _progress = progress);
          },
          onWebResourceError: _onWebResourceError,
        ),
      )
      ..addJavaScriptChannel(
        'JwxtImportChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _onWebMessage(message.message);
        },
      );

    _controller = controller;
    controller.loadRequest(Uri.parse(_jwxtUrl));
  }

  Future<void> _applyDesktopViewport(WebViewController controller) async {
    try {
      await controller.runJavaScript(_desktopViewportFixScript);
    } catch (_) {
      // Ignore script injection failures.
    }
  }

  void _onWebResourceError(WebResourceError error) {
    if (error.isForMainFrame != true) {
      return;
    }

    final String description = error.description.trim();
    if (description.isEmpty) {
      return;
    }

    final String lower = description.toLowerCase();
    final int code = error.errorCode;
    if (code == -999 || code == -3 || code == -10) {
      return;
    }
    final bool cancelled =
        lower.contains('cancelled') ||
        lower.contains('aborted') ||
        lower.contains('err_abort') ||
        lower.contains('interrupted');
    if (cancelled) {
      return;
    }

    final DateTime now = DateTime.now();
    // Suppress burst duplicates triggered by the same navigation transition.
    final bool duplicated =
        _lastErrorMessage == description &&
        _lastErrorAt != null &&
        now.difference(_lastErrorAt!) < const Duration(seconds: 3);
    if (duplicated) {
      return;
    }

    _lastErrorMessage = description;
    _lastErrorAt = now;
    debugPrint('JWXT WebView error(code=$code): $description');
  }

  Future<void> _extract() async {
    final WebViewController? controller = _controller;
    if (controller == null || !_canExtract || _extracting) {
      return;
    }

    setState(() => _extracting = true);
    try {
      await controller.runJavaScript(_extractDataScript);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _extracting = false);
      _showMessage('执行提取脚本失败: $error');
    }
  }

  void _onWebMessage(String message) {
    if (!mounted) {
      return;
    }

    // Channel message format:
    //   ERROR:<text>
    //   DATA_EXTRACTED:<json>
    if (message.startsWith('ERROR:')) {
      setState(() => _extracting = false);
      _showMessage(message.substring('ERROR:'.length));
      return;
    }

    if (!message.startsWith('DATA_EXTRACTED:')) {
      return;
    }

    final String payloadText = message.substring('DATA_EXTRACTED:'.length);
    try {
      final dynamic decoded = jsonDecode(payloadText);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('提取结果格式错误');
      }

      final List<dynamic> courses =
          (decoded['courses'] as List<dynamic>?) ?? <dynamic>[];
      if (courses.isEmpty) {
        setState(() => _extracting = false);
        _showMessage('未识别到课程，请先打开“我的课表/全部课程”页面再提取。');
        return;
      }

      Navigator.of(context).pop<Map<String, dynamic>>(decoded);
    } catch (error) {
      setState(() => _extracting = false);
      _showMessage('解析提取结果失败: $error');
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return Scaffold(
        appBar: AppBar(title: const Text('教务系统导入')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text('当前平台不支持内置网页导入，请改用 Android 或 iOS 设备。'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('教务系统导入'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: (_canExtract && !_extracting) ? _extract : null,
            icon: _extracting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_for_offline_outlined),
            label: const Text('提取课程'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          if (_controller == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(child: WebViewWidget(controller: _controller!)),
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: const Text(
              '操作：登录门户 -> 进入教务系统 -> 打开“我的课表/全部课程” -> 点击右上角“提取课程”。',
            ),
          ),
        ],
      ),
    );
  }
}
