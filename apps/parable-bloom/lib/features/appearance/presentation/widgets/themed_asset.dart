import 'package:material_ui/material_ui.dart';

import '../../domain/appearance_pack.dart';
import '../../domain/appearance_slot.dart';

/// Exposes the resolved appearance pack to widgets that are not consumers.
///
/// [of] returns [AppearancePack.garden] when no scope is mounted, so screens
/// pumped in tests keep today's assets.
class AppearanceScope extends InheritedWidget {
  const AppearanceScope({
    super.key,
    required this.pack,
    required super.child,
  });

  final AppearancePack pack;

  static AppearancePack of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppearanceScope>();
    return scope?.pack ?? AppearancePack.garden;
  }

  @override
  bool updateShouldNotify(AppearanceScope oldWidget) => oldWidget.pack != pack;
}

/// [Image.asset] for one [AppearanceSlot] on the ambient [AppearanceScope].
class ThemedAsset extends StatelessWidget {
  const ThemedAsset({
    super.key,
    required this.slot,
    this.fit,
    this.height,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.low,
  });

  final AppearanceSlot slot;
  final BoxFit? fit;
  final double? height;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final pack = AppearanceScope.of(context);
    final brightness = Theme.of(context).brightness;
    return Image.asset(
      pack.asset(slot, brightness: brightness),
      fit: fit,
      height: height,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
    );
  }
}
