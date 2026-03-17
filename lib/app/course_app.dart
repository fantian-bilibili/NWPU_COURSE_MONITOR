import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'pages/gpa_page.dart';
import 'pages/import_page.dart';
import 'pages/schedule_page.dart';
import 'pages/settings_page.dart';
import 'pages/windows_mini_schedule_page.dart';
import 'widgets/frosted_panel.dart';

class CourseMonitorApp extends StatelessWidget {
  const CourseMonitorApp({super.key, required this.appState});

  final AppState appState;

  static const List<String> _fontFallback = <String>[
    'PingFang SC',
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'Heiti SC',
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (BuildContext context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '课程表管家',
          scrollBehavior: const _DesktopSmoothScrollBehavior(),
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: appState.settings.themeModeSetting.toThemeMode(),
          home: !appState.initialized
              ? const _AppLoadingView()
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
    final ColorScheme baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E6F86),
      brightness: brightness,
    );
    final ColorScheme scheme = baseScheme.copyWith(
      primary: isDark ? const Color(0xFF8DC8DE) : const Color(0xFF2F6D83),
      onPrimary: isDark ? const Color(0xFF102029) : Colors.white,
      secondary: isDark ? const Color(0xFFB8CFD8) : const Color(0xFF526A78),
      surface: isDark ? const Color(0xFF12181F) : const Color(0xFFF7FAFC),
      onSurface: isDark ? const Color(0xFFEAF0F5) : const Color(0xFF16202A),
      surfaceContainerHighest: isDark
          ? const Color(0xFF1A212A)
          : const Color(0xFFE8EEF3),
      outline: isDark ? const Color(0x335D6B78) : const Color(0x1F2A3E50),
      outlineVariant: isDark
          ? const Color(0x224D5B67)
          : const Color(0x14334455),
      shadow: Colors.black,
    );

    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final TextTheme rawTextTheme = baseTheme.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
      fontFamilyFallback: _fontFallback,
    );
    final TextTheme textTheme = rawTextTheme.copyWith(
      headlineSmall: rawTextTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.08,
      ),
      titleLarge: rawTextTheme.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.35,
      ),
      titleMedium: rawTextTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      titleSmall: rawTextTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      bodyLarge: rawTextTheme.bodyLarge?.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: rawTextTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
      bodySmall: rawTextTheme.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.35,
        color: isDark ? const Color(0xFF9FB0C0) : const Color(0xFF657586),
      ),
      labelLarge: rawTextTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: rawTextTheme.labelMedium?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );

    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(
        color: isDark ? const Color(0x16FFFFFF) : const Color(0x140B2032),
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xD7171E25) : const Color(0xF6FFFFFF),
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        iconColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xCC1B232C) : const Color(0xF7FFFFFF),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFF8091A1) : const Color(0xFF8190A0),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: isDark
            ? const Color(0x7F1B232C)
            : const Color(0xCCFFFFFF),
        selectedColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.14),
        labelStyle: textTheme.labelMedium,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          alignment: Alignment.center,
          minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12);
            }
            return isDark ? const Color(0x991C242D) : const Color(0xEFFFFFFF);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary;
            }
            return scheme.onSurface;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          visualDensity: VisualDensity.standard,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: WidgetStatePropertyAll(scheme.onPrimary),
          backgroundColor: WidgetStateProperty.resolveWith((
            Set<WidgetState> states,
          ) {
            final double opacity = states.contains(WidgetState.pressed)
                ? 0.92
                : 1;
            return scheme.primary.withValues(alpha: opacity);
          }),
          overlayColor: WidgetStatePropertyAll(
            scheme.onPrimary.withValues(alpha: 0.06),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(controlShape),
          animationDuration: const Duration(milliseconds: 180),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outlineVariant),
          ),
          shape: WidgetStatePropertyAll(controlShape),
          animationDuration: const Duration(milliseconds: 180),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          shape: WidgetStatePropertyAll(controlShape),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.standard,
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xEE11161C)
            : const Color(0xF9FDFEFF),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFFF2F7FB) : const Color(0xFF1A2933),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark
            ? const Color(0xFF151C23)
            : const Color(0xFFFBFDFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: isDark ? 0.36 : 0.24),
        ),
        trackColor: WidgetStatePropertyAll(
          scheme.surfaceContainerHighest.withValues(alpha: isDark ? 0.4 : 0.3),
        ),
        radius: const Radius.circular(999),
        thickness: const WidgetStatePropertyAll(8),
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
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };

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

class _AppLoadingView extends StatelessWidget {
  const _AppLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: _AppBackdrop()),
          Center(child: CircularProgressIndicator()),
        ],
      ),
    );
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
    if (width >= 980) {
      return true;
    }
    if (kIsWeb) {
      return width >= 980;
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
      extendBody: !desktop,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _AppBackdrop()),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: desktop ? 1360 : double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 20 : 12,
                    12,
                    desktop ? 20 : 12,
                    0,
                  ),
                  child: Column(
                    children: <Widget>[
                      if (desktop)
                        _DesktopHeaderBar(
                          index: _index,
                          semesterName: widget.appState.currentSemester.name,
                          onDestinationSelected: _onDestinationSelected,
                        ),
                      if (desktop) const SizedBox(height: 18),
                      Expanded(
                        child: RepaintBoundary(
                          child: _PageStage(
                            desktop: desktop,
                            child: _buildCurrentPage(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (!desktop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _MobileFloatingNavigationBar(
                index: _index,
                onDestinationSelected: _onDestinationSelected,
              ),
            ),
          if (widget.appState.busy)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0x4A0C1015)
                    : const Color(0x42F8FBFE),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: null,
    );
  }
}

class _PageStage extends StatelessWidget {
  const _PageStage({required this.desktop, required this.child});

  final bool desktop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget stage = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );

    if (!desktop) {
      return Padding(padding: const EdgeInsets.only(bottom: 20), child: stage);
    }

    return FrostedPanel(
      enabled: true,
      padding: EdgeInsets.zero,
      radius: 34,
      child: stage,
    );
  }
}

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1218) : const Color(0xFFF4F7FB),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const <Color>[
                  Color(0xFF0D1218),
                  Color(0xFF101821),
                  Color(0xFF121B23),
                ]
              : const <Color>[
                  Color(0xFFF7FAFC),
                  Color(0xFFF1F5F8),
                  Color(0xFFEDF2F7),
                ],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const <Color>[
                    Color(0x22108AA6),
                    Color(0x08108AA6),
                    Color(0x120A1118),
                  ]
                : const <Color>[
                    Color(0x42FFFFFF),
                    Color(0x20F7FBFD),
                    Color(0x08DCEAF1),
                  ],
          ),
        ),
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

class _DesktopHeaderBar extends StatelessWidget {
  const _DesktopHeaderBar({
    required this.index,
    required this.semesterName,
    required this.onDestinationSelected,
  });

  final int index;
  final String semesterName;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return FrostedPanel(
      enabled: true,
      padding: EdgeInsets.zero,
      radius: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.auto_stories_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '课程表管家',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    semesterName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Flexible(
              flex: 3,
              child: _NavigationStrip(
                index: index,
                mobile: false,
                onDestinationSelected: onDestinationSelected,
              ),
            ),
          ],
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        child: FrostedPanel(
          enabled: true,
          padding: EdgeInsets.zero,
          radius: 28,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _NavigationStrip(
              index: index,
              mobile: true,
              onDestinationSelected: onDestinationSelected,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationStrip extends StatelessWidget {
  const _NavigationStrip({
    required this.index,
    required this.mobile,
    required this.onDestinationSelected,
  });

  final int index;
  final bool mobile;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(_destinations.length, (int itemIndex) {
        final _AppDestination destination = _destinations[itemIndex];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: mobile ? 2 : 4),
            child: _NavigationButton(
              selected: itemIndex == index,
              mobile: mobile,
              destination: destination,
              onTap: () => onDestinationSelected(itemIndex),
            ),
          ),
        );
      }),
    );
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.selected,
    required this.mobile,
    required this.destination,
    required this.onTap,
  });

  final bool selected;
  final bool mobile;
  final _AppDestination destination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color background = selected
        ? scheme.primary.withValues(alpha: isDark ? 0.18 : 0.11)
        : Colors.transparent;
    final Color border = selected
        ? scheme.primary.withValues(alpha: isDark ? 0.24 : 0.16)
        : Colors.transparent;
    final Color foreground = selected
        ? scheme.primary
        : theme.textTheme.bodySmall!.color!;
    final IconData icon = selected
        ? destination.selectedIcon
        : destination.icon;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 6 : 14,
            vertical: mobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: mobile
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(icon, size: 21, color: foreground),
                    const SizedBox(height: 4),
                    Text(
                      destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, size: 20, color: foreground),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AppDestination {
  const _AppDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_AppDestination> _destinations = <_AppDestination>[
  _AppDestination(
    label: '课程表',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
  ),
  _AppDestination(
    label: '导入',
    icon: Icons.file_download_outlined,
    selectedIcon: Icons.file_download,
  ),
  _AppDestination(
    label: '绩点',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
  ),
  _AppDestination(
    label: '设置',
    icon: Icons.tune_outlined,
    selectedIcon: Icons.tune,
  ),
];
