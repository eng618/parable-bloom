import 'package:flutter/material.dart';

/// Caps content width on wide screens (desktop/web) so text screens don't
/// sprawl edge-to-edge in landscape. Below [maxWidth] it behaves like a
/// plain padded container, so phones are unaffected.
///
/// Wrap Scaffold *bodies* (keep AppBars full-bleed); works around both
/// scrollables and plain columns.
class ConstrainedPage extends StatelessWidget {
  const ConstrainedPage({
    super.key,
    required this.child,
    this.maxWidth = 680,
    this.padding = EdgeInsets.zero,
  });

  /// Readability-tuned default: ~66 characters of body text per line.
  static const double textWidth = 680;

  /// Narrow width for forms and compact controls.
  static const double formWidth = 440;

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
