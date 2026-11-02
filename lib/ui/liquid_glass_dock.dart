import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'native_liquid_glass.dart';
import 'scene_sampler_orientation.dart';

/// A full-bleed frosted bottom bar with a separate sharp foreground.
///
/// The bar spans the whole width, sits flush on the bottom edge (under the
/// system inset) and rounds only its top corners. [dock] is laid out inside it
/// with [horizontalPadding] on both sides and the bottom safe-area inset plus
/// [basePadding] below, so callers only describe their own vertical rhythm.
///
/// A foreground that projects above the bar (the cart stamp) declares how far
/// with [DockOverhang]; that strip belongs to the foreground's layout box, so
/// the projecting part stays hit-testable, but the glass starts below it.
///
/// iOS 26+ uses Apple's native effect. Other supported Flutter renderers sample
/// [content] into a GPU image, Gaussian-blur the part of it near the bar, and
/// refract that blurred crop with a fragment shader, without a per-frame CPU
/// readback or a delayed screenshot. One paired-marker probe at [warmUp]
/// measures the sampler's vertical orientation. Platform views in [content]
/// cannot be sampled by Flutter; keep them outside this optical underlay.
class LiquidGlassDock extends StatefulWidget {
  const LiquidGlassDock({
    required this.content,
    required this.dock,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(20)),
    this.tint,
    this.onDockHeightChanged,
    super.key,
  });

  final Widget content;
  final Widget? dock;
  final BorderRadius borderRadius;
  final Color? tint;

  /// Reports the bar's height after layout, excluding the bottom safe-area
  /// inset (which the bar also covers) and any [DockOverhang]. Content that
  /// must stay clear of the bar reserves this plus the inset. Reports 0 while
  /// the foreground is empty.
  final ValueChanged<double>? onDockHeightChanged;

  /// Space between the foreground and the page's left and right edges.
  static const double horizontalPadding = AppSpacing.xxxl;

  /// Space under the foreground, on top of the bottom safe-area inset.
  static const double basePadding = AppSpacing.xs;

  // Float uniforms of `liquid_glass.frag`: uSize, uBounds, uCorners, uTint,
  // uDark, uFlipY, uCrop.
  static const int _uniformFloatCount = 20;

  static Future<void>? _preparation;
  static bool _prepared = false;
  static bool _nativeReady = false;
  static ui.FragmentProgram? _readyProgram;
  static bool _sceneFlipY = false;

  /// Prepares the selected renderer before mounting a deterministic surface.
  static Future<void> warmUp() => _preparation ??= _prepare();

  static Future<void> _prepare() async {
    _nativeReady = await NativeLiquidGlass.isAvailable;
    if (!_nativeReady) {
      final program = await ui.FragmentProgram.fromAsset(
        'shaders/liquid_glass.frag',
      );
      _sceneFlipY = await _sceneSamplesUpsideDown(program);
      // One line in logcat (`adb logcat -s flutter`) records what this device measured.
      debugPrint(
          'LiquidGlassDock: sampler needs a vertical flip: $_sceneFlipY');
      _readyProgram = program;
    }
    _prepared = true;
  }

  /// Measures, once, whether the dock shader's scene sampler returns a
  /// [ui.Scene.toImageSync] image upside down on the active renderer.
  ///
  /// Flutter's normal image painter and the raw shader draw the same red/blue
  /// scene side by side in one output image. Their relative row order, rather
  /// than an assumed read-back origin, determines the correction.
  /// Zero-size glass bounds make the shader pass the sampled scene through.
  static Future<bool> _sceneSamplesUpsideDown(
    ui.FragmentProgram program,
  ) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..drawRect(
        const Rect.fromLTWH(0, 0, 2, 1),
        Paint()..color = const Color(0xFFFF0000),
      )
      ..drawRect(
        const Rect.fromLTWH(0, 1, 2, 1),
        Paint()..color = const Color(0xFF0000FF),
      );
    final scenePicture = recorder.endRecording();
    final scene =
        (ui.SceneBuilder()..addPicture(Offset.zero, scenePicture)).build();
    final sceneImage = scene.toImageSync(2, 2);
    final shader = program.fragmentShader();
    // CanvasKit may reuse uncleared WASM uniform memory. Make the raw
    // passthrough bounds, flip and crop explicit instead of relying on zero
    // defaults (a zero crop width makes the sampler span `uSize`).
    for (var index = 2; index < _uniformFloatCount; index++) {
      shader.setFloat(index, 0);
    }
    shader
      ..setFloat(0, 2)
      ..setFloat(1, 2)
      ..setImageSampler(0, sceneImage);
    final outputRecorder = ui.PictureRecorder();
    // Keep the shader at the origin and paint the reference beside it.
    Canvas(outputRecorder)
      ..drawRect(const Rect.fromLTWH(0, 0, 2, 2), Paint()..shader = shader)
      ..drawImage(sceneImage, const Offset(2, 0), Paint());
    final outputPicture = outputRecorder.endRecording();
    ui.Image? output;
    try {
      output = await outputPicture.toImage(4, 2);
      final pixels = (await output.toByteData())!;
      return sceneSamplerNeedsYFlip(pixels);
    } finally {
      output?.dispose();
      outputPicture.dispose();
      shader.dispose();
      sceneImage.dispose();
      scene.dispose();
      scenePicture.dispose();
    }
  }

  @override
  State<LiquidGlassDock> createState() => _LiquidGlassDockState();
}

class _DockGeometry {
  /// The glass bar in the content's coordinates; empty while the foreground is.
  Rect bounds = Rect.zero;
  double reportedHeight = 0;
}

/// Carries a foreground's declared overhang from [DockOverhang] to the layout.
class _DockScope extends InheritedWidget {
  const _DockScope({required this.overhang, required super.child});

  final ValueNotifier<double> overhang;

  @override
  bool updateShouldNotify(_DockScope oldWidget) =>
      overhang != oldWidget.overhang;
}

/// Declares that the surrounding [LiquidGlassDock] foreground projects [extent]
/// logical pixels above the glass bar.
///
/// The foreground's own box includes that strip (so the projecting control is
/// hit-testable); the dock starts the glass [extent] below the top of the box.
/// Outside a [LiquidGlassDock] this is transparent.
class DockOverhang extends StatefulWidget {
  const DockOverhang({required this.extent, required this.child, super.key});

  final double extent;
  final Widget child;

  @override
  State<DockOverhang> createState() => _DockOverhangState();
}

class _DockOverhangState extends State<DockOverhang> {
  ValueNotifier<double>? _target;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next =
        context.dependOnInheritedWidgetOfExactType<_DockScope>()?.overhang;
    if (next == _target) return;
    _target?.value = 0;
    _target = next;
    _target?.value = widget.extent;
  }

  @override
  void didUpdateWidget(covariant DockOverhang oldWidget) {
    super.didUpdateWidget(oldWidget);
    _target?.value = widget.extent;
  }

  @override
  void dispose() {
    _target?.value = 0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

enum _MaterialStatus { loading, native, shader, error }

enum _DockSlot { content, backdrop, dock }

class _LiquidGlassDockState extends State<LiquidGlassDock> {
  final _geometry = _DockGeometry();
  final _overhang = ValueNotifier<double>(0);
  final _paint = Paint();
  // The page is drawn through Flutter's own image painter, which is upright on
  // every renderer; only the glass samples the blurred crop through the shader.
  final _pagePaint = Paint()..filterQuality = FilterQuality.none;
  final _blurPaint = Paint()
    ..imageFilter = ui.ImageFilter.blur(
      sigmaX: _blurSigma,
      sigmaY: _blurSigma,
      tileMode: TileMode.clamp,
    );

  // `liquid_glass.frag` leaves everything farther than this above the glass
  // untouched (`distance > 24.0`), so only that band needs the shader.
  static const _glassReach = 24.0;
  // The frost is a real Gaussian of the page, taken in the page's logical
  // pixels. Its input is read this far (3 sigma) beyond the sampled crop so the
  // crop's own edges are not darkened by missing neighbours.
  static const _blurSigma = 10.0;
  static const _blurReach = _blurSigma * 3;
  // Refraction bends sampling up to 32 px, plus the shader's smoothing taps.
  static const _sampleReach = 40.0;
  // A smooth blur needs no more than about 1.5 texels per logical pixel.
  static const _maxTexelsPerPixel = 1.5;
  ui.FragmentShader? _shader;
  _MaterialStatus _status = _MaterialStatus.loading;
  Object? _error;
  bool _materialStarted = false;

  @override
  void initState() {
    super.initState();
    if (widget.dock != null) _startMaterial();
  }

  @override
  void didUpdateWidget(covariant LiquidGlassDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dock != null && !_materialStarted) _startMaterial();
  }

  void _startMaterial() {
    _materialStarted = true;
    if (LiquidGlassDock._prepared) {
      _applyMaterial();
    } else {
      _loadMaterial();
    }
  }

  void _applyMaterial() {
    if (LiquidGlassDock._nativeReady) {
      _status = _MaterialStatus.native;
    } else {
      _shader = LiquidGlassDock._readyProgram!.fragmentShader();
      _status = _MaterialStatus.shader;
    }
  }

  Future<void> _loadMaterial() async {
    try {
      await LiquidGlassDock.warmUp();
      if (!mounted) return;
      setState(_applyMaterial);
    } catch (error, stack) {
      if (!mounted) return;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'Liquid Glass',
          context: ErrorDescription('loading the floating optical material'),
        ),
      );
      setState(() {
        _status = _MaterialStatus.error;
        _error = error;
      });
    }
  }

  @override
  void dispose() {
    _paint.shader = null;
    _shader?.dispose();
    _overhang.dispose();
    super.dispose();
  }

  /// Gaussian-blurs the part of [image] around [crop] into a new GPU image
  /// that covers exactly [crop] (both in logical page coordinates). Like the
  /// page snapshot it comes from `toImageSync`, so the measured sampler
  /// orientation applies to it unchanged.
  ui.Image _blurredCrop(
    ui.Image image,
    Size size,
    Rect crop,
    double devicePixelRatio,
  ) {
    final texelsPerPixel = math.min(devicePixelRatio, _maxTexelsPerPixel);
    final width = math.max(1, (crop.width * texelsPerPixel).ceil());
    final height = math.max(1, (crop.height * texelsPerPixel).ceil());
    final input = crop.inflate(_blurReach).intersect(Offset.zero & size);
    final imageScaleX = image.width / size.width;
    final imageScaleY = image.height / size.height;
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..scale(width / crop.width, height / crop.height)
      ..translate(-crop.left, -crop.top)
      ..saveLayer(input, _blurPaint)
      ..drawImageRect(
        image,
        Rect.fromLTRB(
          input.left * imageScaleX,
          input.top * imageScaleY,
          input.right * imageScaleX,
          input.bottom * imageScaleY,
        ),
        input,
        _pagePaint,
      )
      ..restore();
    final picture = recorder.endRecording();
    try {
      return picture.toImageSync(width, height);
    } finally {
      picture.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dock == null) return widget.content;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // A frosted base material under the optics: enough tint that text under
    // the bar reads as colour, never as garbled letters.
    final tint = widget.tint ??
        (dark
            ? const Color(0xFF0E0E10).withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.62));
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final underlay = ColoredBox(
      color: context.palette.background,
      child: widget.content,
    );
    final background = _status == _MaterialStatus.shader
        ? AnimatedSampler((image, size, canvas) {
            canvas.drawImageRect(
              image,
              Rect.fromLTWH(
                0,
                0,
                image.width.toDouble(),
                image.height.toDouble(),
              ),
              Offset.zero & size,
              _pagePaint,
            );
            final bounds = _geometry.bounds;
            if (bounds.isEmpty) return;
            final crop =
                bounds.inflate(_sampleReach).intersect(Offset.zero & size);
            if (crop.isEmpty) return;
            final blurred = _blurredCrop(image, size, crop, devicePixelRatio);
            try {
              final shader = _shader!;
              final corners = widget.borderRadius;
              shader
                ..setFloat(0, size.width)
                ..setFloat(1, size.height)
                ..setFloat(2, bounds.left)
                ..setFloat(3, bounds.top)
                ..setFloat(4, bounds.width)
                ..setFloat(5, bounds.height)
                ..setFloat(6, corners.topLeft.x)
                ..setFloat(7, corners.topRight.x)
                ..setFloat(8, corners.bottomRight.x)
                ..setFloat(9, corners.bottomLeft.x)
                ..setFloat(10, tint.r)
                ..setFloat(11, tint.g)
                ..setFloat(12, tint.b)
                ..setFloat(13, tint.a)
                ..setFloat(14, dark ? 1 : 0)
                ..setFloat(15, LiquidGlassDock._sceneFlipY ? 1 : 0)
                ..setFloat(16, crop.left)
                ..setFloat(17, crop.top)
                ..setFloat(18, crop.width)
                ..setFloat(19, crop.height)
                ..setImageSampler(0, blurred);
              _paint.shader = shader;
              // The bar's sides and bottom lie on the page edge: only the
              // band above it needs the shadow.
              canvas.drawRect(
                Rect.fromLTRB(
                  bounds.left,
                  bounds.top - _glassReach,
                  bounds.right,
                  bounds.bottom,
                ),
                _paint,
              );
            } finally {
              blurred.dispose();
            }
          }, child: underlay)
        : underlay;
    final backdrop = _backdrop(dark, tint);
    return _DockScope(
      overhang: _overhang,
      child: CustomMultiChildLayout(
        delegate: _DockLayout(
          geometry: _geometry,
          overhang: _overhang,
          bottomInset: MediaQuery.paddingOf(context).bottom,
          onHeightChanged: _reportDockHeight,
        ),
        children: [
          LayoutId(id: _DockSlot.content, child: background),
          if (backdrop != null)
            LayoutId(id: _DockSlot.backdrop, child: backdrop),
          LayoutId(id: _DockSlot.dock, child: widget.dock!),
        ],
      ),
    );
  }

  bool _heightReportScheduled = false;
  double _pendingHeight = 0;

  void _reportDockHeight(double height) {
    _pendingHeight = height;
    if (_heightReportScheduled || widget.onDockHeightChanged == null) return;
    _heightReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heightReportScheduled = false;
      if (mounted) widget.onDockHeightChanged?.call(_pendingHeight);
    });
  }

  /// The material under the foreground when the shader is not the renderer:
  /// Apple's native glass, or a plain surface while the shader loads or if it
  /// failed. The layout sizes it to exactly the bar.
  Widget? _backdrop(bool dark, Color tint) {
    switch (_status) {
      case _MaterialStatus.native:
        return NativeLiquidGlassBackdrop(
          borderRadius: widget.borderRadius,
          tint: tint,
          dark: dark,
        );
      case _MaterialStatus.shader:
        return null;
      case _MaterialStatus.loading:
      case _MaterialStatus.error:
        final failure = _status == _MaterialStatus.error;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.24 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: failure
              ? Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      LiquidGlassDock.horizontalPadding,
                      AppSpacing.xs,
                      LiquidGlassDock.horizontalPadding,
                      0,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Tooltip(
                        message: '$_error',
                        child: Text(
                          'Стекло недоступно',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
    }
  }
}

class _DockLayout extends MultiChildLayoutDelegate {
  _DockLayout({
    required this.geometry,
    required this.overhang,
    required this.bottomInset,
    required this.onHeightChanged,
  }) : super(relayout: overhang);

  final _DockGeometry geometry;
  final ValueNotifier<double> overhang;
  final double bottomInset;
  final ValueChanged<double> onHeightChanged;

  @override
  void performLayout(Size size) {
    final bottomPadding = bottomInset + LiquidGlassDock.basePadding;
    final width =
        math.max(0.0, size.width - LiquidGlassDock.horizontalPadding * 2);
    final dock = layoutChild(
      _DockSlot.dock,
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        maxHeight: math.max(0.0, size.height - bottomPadding),
      ),
    );
    // An empty foreground (a hidden cart button) has no material at all.
    final present = dock.height > 0.5;
    final projecting = present ? math.min(overhang.value, dock.height) : 0.0;
    final barHeight = present ? dock.height - projecting + bottomPadding : 0.0;
    final bar = present
        ? Rect.fromLTWH(0, size.height - barHeight, size.width, barHeight)
        : Rect.zero;
    geometry.bounds = bar;
    final reported = present ? barHeight - bottomInset : 0.0;
    if ((reported - geometry.reportedHeight).abs() > 0.5) {
      geometry.reportedHeight = reported;
      onHeightChanged(reported);
    }
    positionChild(
      _DockSlot.dock,
      Offset(
        LiquidGlassDock.horizontalPadding,
        size.height - bottomPadding - dock.height,
      ),
    );
    if (hasChild(_DockSlot.backdrop)) {
      layoutChild(_DockSlot.backdrop, BoxConstraints.tight(bar.size));
      positionChild(_DockSlot.backdrop, bar.topLeft);
    }
    layoutChild(_DockSlot.content, BoxConstraints.tight(size));
    positionChild(_DockSlot.content, Offset.zero);
  }

  @override
  bool shouldRelayout(covariant _DockLayout oldDelegate) =>
      geometry != oldDelegate.geometry ||
      overhang != oldDelegate.overhang ||
      bottomInset != oldDelegate.bottomInset;
}
