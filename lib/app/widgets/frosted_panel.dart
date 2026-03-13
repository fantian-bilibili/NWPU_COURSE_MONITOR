import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FrostedPanel extends StatelessWidget {
  const FrostedPanel({
    super.key,
    required this.enabled,
    required this.child,
    this.tint,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
    this.radius = 20,
  });

  final bool enabled;
  final Widget child;
  final Color? tint;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool useRealtimeBlur = enabled && _shouldUseRealtimeBlur();
    final Color baseColor =
        tint ?? (isDark ? const Color(0xC0192028) : const Color(0xD9FFFFFF));
    final BorderRadius borderRadius = BorderRadius.circular(radius);
    final BoxDecoration decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? <Color>[
                baseColor.withValues(alpha: 0.92),
                const Color(0xB3141A21),
              ]
            : <Color>[baseColor, const Color(0xCCF6FAFD)],
      ),
      borderRadius: borderRadius,
      border: Border.all(
        color: isDark ? const Color(0x26FFFFFF) : const Color(0x140E2334),
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: isDark ? const Color(0x26000000) : const Color(0x120E2235),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ],
    );

    final Widget decoratedChild = DecoratedBox(
      decoration: decoration,
      child: child,
    );

    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: useRealtimeBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: decoratedChild,
              )
            : decoratedChild,
      ),
    );
  }

  bool _shouldUseRealtimeBlur() {
    if (kIsWeb) {
      return true;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.accent,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tone = accent ?? theme.colorScheme.primary;

    return FrostedPanel(
      enabled: true,
      padding: EdgeInsets.zero,
      radius: 22,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                if (icon != null)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: tone, size: 16),
                  ),
                if (icon != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
            if (caption != null && caption!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                caption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
