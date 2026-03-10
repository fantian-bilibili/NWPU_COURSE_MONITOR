import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'pages/gpa_page.dart';
import 'pages/import_page.dart';
import 'pages/schedule_page.dart';
import 'pages/settings_page.dart';
import 'pages/windows_mini_schedule_page.dart';

class CourseMonitorApp extends StatelessWidget {
  const CourseMonitorApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (BuildContext context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '课表管家',
          scrollBehavior: const _DesktopSmoothScrollBehavior(),
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: appState.settings.themeModeSetting.toThemeMode(),
          home: !appState.initialized
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.windows &&
                    appState.windowsMiniMode)
              ? _WindowsMiniRoot(
                  key: const ValueKey<String>('windows-mini'),
                  appState: appState,
                )
              : CourseHomeShell(
                  key: const ValueKey<String>('course-home'),
                  appState: appState,
                ),
        );
      },
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2A6C86),
      brightness: brightness,
    );

    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Noto Sans SC',
      fontFamilyFallback: const <String>[
        'PingFang SC',
        'Microsoft YaHei',
        'Helvetica Neue',
        'Arial',
        'sans-serif',
      ],
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF15181F)
          : const Color(0xFFF2F4F7),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF242933) : Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF242933) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.secondaryContainer.withValues(alpha: 0.8),
        backgroundColor: isDark
            ? const Color(0xE6242933)
            : const Color(0xEFFFFFFF),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          alignment: Alignment.center,
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
          shape: WidgetStatePropertyAll(controlShape),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
          animationDuration: const Duration(milliseconds: 180),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 44)),
          shape: WidgetStatePropertyAll(controlShape),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontWeight: FontWeight.w600),
          ),
          animationDuration: const Duration(milliseconds: 180),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class _DesktopSmoothScrollBehavior extends MaterialScrollBehavior {
  const _DesktopSmoothScrollBehavior();

  static const double _desktopScrollScale = 0.62;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final ScrollPhysics base = super.getScrollPhysics(context);
    final TargetPlatform platform = kIsWeb
        ? getPlatform(context)
        : defaultTargetPlatform;
    final bool desktop =
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    if (!desktop) {
      return base;
    }
    return _ScaledScrollPhysics(parent: base, scale: _desktopScrollScale);
  }
}

class _ScaledScrollPhysics extends ScrollPhysics {
  const _ScaledScrollPhysics({required this.scale, super.parent});

  final double scale;

  @override
  _ScaledScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _ScaledScrollPhysics(scale: scale, parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final double adjusted = super.applyPhysicsToUserOffset(position, offset);
    return adjusted * scale;
  }
}

class CourseHomeShell extends StatefulWidget {
  const CourseHomeShell({super.key, required this.appState});

  final AppState appState;

  @override
  State<CourseHomeShell> createState() => _CourseHomeShellState();
}

class _CourseHomeShellState extends State<CourseHomeShell> {
  int _index = 0;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_onStateUpdated);
  }

  @override
  void dispose() {
    widget.appState.removeListener(_onStateUpdated);
    super.dispose();
  }

  void _onStateUpdated() {
    final String? message = widget.appState.statusMessage;
    if (!mounted || message == null || message == _lastMessage) {
      return;
    }
    _lastMessage = message;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _onDestinationSelected(int value) {
    if (value == _index) {
      return;
    }
    setState(() => _index = value);
  }

  bool _isDesktopLayout(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    if (width >= 900) {
      return true;
    }
    if (kIsWeb) {
      return width >= 900;
    }
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  Widget _buildCurrentPage() {
    return switch (_index) {
      0 => SchedulePage(
        key: const ValueKey<String>('page-schedule'),
        appState: widget.appState,
      ),
      1 => ImportPage(
        key: const ValueKey<String>('page-import'),
        appState: widget.appState,
      ),
      2 => GpaPage(
        key: const ValueKey<String>('page-gpa'),
        appState: widget.appState,
      ),
      _ => SettingsPage(
        key: const ValueKey<String>('page-settings'),
        appState: widget.appState,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool desktop = _isDesktopLayout(context);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          SafeArea(
            child: RepaintBoundary(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.018, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildCurrentPage(),
              ),
            ),
          ),
          if (widget.appState.busy)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: desktop
          ? _DesktopNavigationBar(
              index: _index,
              onDestinationSelected: _onDestinationSelected,
            )
          : _MobileFloatingNavigationBar(
              index: _index,
              onDestinationSelected: _onDestinationSelected,
            ),
    );
  }
}

class _WindowsMiniRoot extends StatelessWidget {
  const _WindowsMiniRoot({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: WindowsMiniSchedulePage(
              appState: appState,
              onExitMiniMode: () =>
                  appState.runWithBusy(appState.launchWindowsMainWindow),
            ),
          ),
          if (appState.busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _DesktopNavigationBar extends StatelessWidget {
  const _DesktopNavigationBar({
    required this.index,
    required this.onDestinationSelected,
  });

  final int index;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onDestinationSelected,
          elevation: 0,
          destinations: _destinations,
        ),
      ),
    );
  }
}

class _MobileFloatingNavigationBar extends StatelessWidget {
  const _MobileFloatingNavigationBar({
    required this.index,
    required this.onDestinationSelected,
  });

  final int index;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xE6242933) : const Color(0xEFFFFFFF),
              border: Border.all(
                color: isDark
                    ? const Color(0x33FFFFFF)
                    : const Color(0x22111827),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onDestinationSelected,
              destinations: _destinations,
            ),
          ),
        ),
      ),
    );
  }
}

const List<NavigationDestination> _destinations = <NavigationDestination>[
  NavigationDestination(
    icon: Icon(Icons.calendar_month_outlined),
    selectedIcon: Icon(Icons.calendar_month),
    label: '课表',
  ),
  NavigationDestination(
    icon: Icon(Icons.file_upload_outlined),
    selectedIcon: Icon(Icons.file_upload),
    label: '导入',
  ),
  NavigationDestination(
    icon: Icon(Icons.calculate_outlined),
    selectedIcon: Icon(Icons.calculate),
    label: '绩点',
  ),
  NavigationDestination(
    icon: Icon(Icons.tune_outlined),
    selectedIcon: Icon(Icons.tune),
    label: '设置',
  ),
];
