import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'board_themes.dart';

// ────────────────────────────────────────────────────────────────────────────
// Platform Channel  (Path A — iOS native Liquid Glass bridge)
// ────────────────────────────────────────────────────────────────────────────

/// Platform channel name registered in `ios/Runner/AppDelegate.swift`.
const String _kLiquidGlassChannel = 'enterprise_chess/liquid_glass';

/// Queries the native iOS accessibility flags for Reduce Motion and
/// Reduce Transparency.  Returns `(reduceMotion, reduceTransparency)`.
/// On non-iOS platforms always returns `(false, false)`.
Future<({bool reduceMotion, bool reduceTransparency})>
    queryLiquidGlassBridge() async {
  try {
    final MethodChannel ch = const MethodChannel(_kLiquidGlassChannel);
    final Map<Object?, Object?> result =
        (await ch.invokeMethod<Map<Object?, Object?>>('accessibilityFlags')) ??
            {};
    return (
      reduceMotion: result['reduceMotion'] == true,
      reduceTransparency: result['reduceTransparency'] == true,
    );
  } on MissingPluginException {
    // Not on iOS or bridge not registered — fall through to Path B.
    return (reduceMotion: false, reduceTransparency: false);
  } on PlatformException {
    return (reduceMotion: false, reduceTransparency: false);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// LiquidGlassContainer  (Path B — Flutter-native approximation)
// ────────────────────────────────────────────────────────────────────────────

/// Path B Liquid Glass surface:
///
/// • `BackdropFilter(ImageFilter.blur(sigmaX: 24, sigmaY: 24))` — frosted glass.
/// • Flat semi-transparent white/black wash (no gradient fills).
/// • 1 px hairline perimeter border at 12% opacity.
/// • Motion-reactive specular highlight: soft blurred bright streak along the
///   top edge driven by `sensors_plus` accelerometer stream (±6 px parallax).
///
/// Accessibility:
/// • When `MediaQuery.disableAnimations` is true **or**
///   `MediaQuery.highContrast` is true the blur and specular are disabled and
///   a flat `BoardThemes.surfaceCard` surface is rendered instead.
class LiquidGlassContainer extends StatefulWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.sigmaBlur = 24.0,
    this.lightMode = false,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Blur strength (σ). Clamped to [0, 40].
  final double sigmaBlur;

  /// `true` → light surface (8% black wash); `false` → dark surface (18% black wash).
  final bool lightMode;

  final EdgeInsets padding;
  final EdgeInsets margin;
  final double? width;
  final double? height;

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer> {
  /// Horizontal offset of the specular streak driven by accelerometer X-axis.
  double _specularOffsetX = 0.0;

  // Max parallax in logical pixels.
  static const double _maxParallax = 6.0;

  // Smoothing factor for exponential moving average on raw accelerometer data.
  static const double _alpha = 0.12;

  // Raw accelerometer event subscription.
  dynamic _accelSub;

  @override
  void initState() {
    super.initState();
    _startSensorStream();
  }

  void _startSensorStream() {
    try {
      _accelSub = accelerometerEventStream().listen(
        (AccelerometerEvent e) {
          // e.x ranges roughly ±10 m/s² at 90° tilt.
          // Normalise to [-1, 1] then scale to ±maxParallax.
          final double raw = (e.x / 10.0).clamp(-1.0, 1.0) * _maxParallax;
          setState(() {
            _specularOffsetX =
                _specularOffsetX * (1 - _alpha) + raw * _alpha;
          });
        },
        onError: (_) {},
        cancelOnError: false,
      );
    } catch (_) {
      // Sensor unavailable on desktop / web — silently ignore.
    }
  }

  @override
  void dispose() {
    (_accelSub as dynamic)?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool disableAnimations = MediaQuery.disableAnimationsOf(context);
    final bool highContrast      = MediaQuery.highContrastOf(context);
    final bool flat              = disableAnimations || highContrast;

    return Container(
      margin: widget.margin,
      width: widget.width,
      height: widget.height,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: flat ? _buildFlatSurface() : _buildGlassSurface(),
      ),
    );
  }

  Widget _buildFlatSurface() {
    return Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        color: BoardThemes.surfaceCard,
        borderRadius: widget.borderRadius,
      ),
      child: widget.child,
    );
  }

  Widget _buildGlassSurface() {
    final double sigma = widget.sigmaBlur.clamp(0.0, 40.0);
    final Color wash = widget.lightMode
        ? const Color(0x14000000) // 8% black
        : const Color(0x2E000000); // 18% black

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: Container(
        padding: widget.padding,
        decoration: BoxDecoration(
          color: wash,
          borderRadius: widget.borderRadius,
          border: Border.all(
            color: const Color(0x1FFFFFFF), // 12% white hairline
            width: 1.0,
          ),
        ),
        child: Stack(
          children: [
            // ── Specular streak ─────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _SpecularHighlight(offsetX: _specularOffsetX),
            ),
            // ── Content ─────────────────────────────────────────────────
            widget.child,
          ],
        ),
      ),
    );
  }
}

/// Soft blurred bright streak rendered at the top of a glass panel.
/// Shifts horizontally by [offsetX] to simulate gyroscope-driven lensing.
class _SpecularHighlight extends StatelessWidget {
  const _SpecularHighlight({required this.offsetX});

  final double offsetX;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(offsetX, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOutBack,
        height: 2,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              BoardThemes.pureWhite.withValues(alpha: 0.30),
              BoardThemes.pureWhite.withValues(alpha: 0.55),
              BoardThemes.pureWhite.withValues(alpha: 0.30),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Convenience extension — wrap any widget in a glass surface
// ────────────────────────────────────────────────────────────────────────────

extension LiquidGlassExtension on Widget {
  /// Wraps this widget in a [LiquidGlassContainer] with default parameters.
  Widget inLiquidGlass({
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(20)),
    double sigmaBlur = 24.0,
    bool lightMode = false,
    EdgeInsets padding = const EdgeInsets.all(16),
    EdgeInsets margin = EdgeInsets.zero,
    double? width,
    double? height,
  }) {
    return LiquidGlassContainer(
      borderRadius: borderRadius,
      sigmaBlur: sigmaBlur,
      lightMode: lightMode,
      padding: padding,
      margin: margin,
      width: width,
      height: height,
      child: this,
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// LiquidGlassModal — full bottom-sheet / dialog replacement
// ────────────────────────────────────────────────────────────────────────────

/// Shows a bottom sheet wrapped in [LiquidGlassContainer] with spring-overshoot
/// entry animation ([Curves.easeOutBack]).
Future<T?> showLiquidGlassModal<T>({
  required BuildContext context,
  required Widget child,
  BorderRadius borderRadius = const BorderRadius.vertical(
    top: Radius.circular(28),
  ),
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: BoardThemes.pitchBlack.withValues(alpha: 0.55),
    isDismissible: isDismissible,
    isScrollControlled: true,
    transitionAnimationController: AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 420),
    ),
    builder: (_) => LiquidGlassContainer(
      borderRadius: borderRadius,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: child,
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Spring curve utility — matches iOS spring feel
// ────────────────────────────────────────────────────────────────────────────

/// Custom spring curve that slightly overshoots and settles, matching the
/// feel of Apple's UISpringTimingParameters.
class _SpringCurve extends Curve {
  const _SpringCurve();

  @override
  double transformInternal(double t) {
    // Damped-spring approximation: 1 - e^(-6t) * cos(10t)
    return 1 - math.exp(-6 * t) * math.cos(10 * t);
  }
}

/// Drop-in for [Curves.easeOutBack] with iOS-tuned spring overshoot.
// ignore: unused_element
const Curve kLiquidGlassSpring = _SpringCurve();
