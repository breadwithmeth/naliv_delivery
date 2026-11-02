import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import 'native_liquid_glass.dart';
import 'scene_sampler_orientation.dart';

/// A floating material with a sampled underlay and a separate sharp foreground.
///
/// iOS 26+ uses Apple's native effect. Other supported Flutter renderers sample
/// [content] into a GPU image and refract it with a fragment shader, without a
/// per-frame CPU readback or a delayed screenshot. One paired-marker probe at
/// [warmUp] measures the sampler's vertical orientation. Platform views in
/// [content] cannot be sampled by Flutter; keep them outside this optical underlay.
class LiquidGlassDock extends StatefulWidget {
  const LiquidGlassDock({
    required this.content,
    required this.dock,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(36)),
    this.tint,
    this.onDockHeightChanged,
    super.key,
  });

  final Widget content;
  final Widget? dock;
  final EdgeInsets? margin;
  final BorderRadius borderRadius;
  final Color? tint;

  /// Reports the actual material height after layout, excluding [margin].
  final ValueChanged<double>? onDockHeightChanged;

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
    // passthrough bounds and flip explicit instead of relying on zero defaults.
    for (var index = 2; index < 16; index++) {
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
  Rect bounds = Rect.zero;
}

enum _MaterialStatus { loading, native, shader, error }

enum _DockSlot { content, dock }

class _LiquidGlassDockState extends State<LiquidGlassDock> {
  final _geometry = _DockGeometry();
  final _paint = Paint();
  // The page is drawn through Flutter's own image painter, which is upright on
  // every renderer; only the glass samples the snapshot through the shader.
  final _pagePaint = Paint()..filterQuality = FilterQuality.none;

  // `liquid_glass.frag` leaves everything farther than this from the glass
  // untouched (`distance > 14.0`), so only that ring needs the shader.
  static const _glassReach = 14.0;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dock == null) return widget.content;
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Apple's glass carries a base material under its adaptive response; the
    // shader's range control only handles luminance extremes on top of it.
    final tint = widget.tint ??
        (dark
            ? const Color(0xFF0E0E10).withValues(alpha: 0.32)
            : Colors.white.withValues(alpha: 0.30));
    final margin = widget.margin ??
        EdgeInsets.fromLTRB(
          AppSpacing.xxxl,
          0,
          AppSpacing.xxxl,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        );
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
              ..setImageSampler(0, image);
            _paint.shader = shader;
            canvas.drawRect(bounds.inflate(_glassReach), _paint);
          }, child: underlay)
        : underlay;
    return CustomMultiChildLayout(
      delegate: _DockLayout(_geometry, margin, _reportDockHeight),
      children: [
        LayoutId(id: _DockSlot.content, child: background),
        LayoutId(id: _DockSlot.dock, child: _foreground(dark, tint)),
      ],
    );
  }

  bool _heightReportScheduled = false;

  void _reportDockHeight() {
    if (_heightReportScheduled || widget.onDockHeightChanged == null) return;
    _heightReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heightReportScheduled = false;
      if (mounted) widget.onDockHeightChanged?.call(_geometry.bounds.height);
    });
  }

  Widget _foreground(bool dark, Color tint) {
    if (_status == _MaterialStatus.native) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: NativeLiquidGlassBackdrop(
              borderRadius: widget.borderRadius,
              tint: tint,
              dark: dark,
            ),
          ),
          widget.dock!,
        ],
      );
    }
    if (_status == _MaterialStatus.shader) return widget.dock!;
    final failure = _status == _MaterialStatus.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: widget.borderRadius,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Semantics(
              liveRegion: true,
              child: Tooltip(
                message: failure ? '$_error' : '',
                child: Text(
                  failure ? 'Стекло недоступно' : 'Подготовка стекла…',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
          widget.dock!,
        ],
      ),
    );
  }
}

class _DockLayout extends MultiChildLayoutDelegate {
  _DockLayout(this.geometry, this.margin, this.onHeightChanged);

  final _DockGeometry geometry;
  final EdgeInsets margin;
  final VoidCallback onHeightChanged;

  @override
  void performLayout(Size size) {
    final width = math.max(0.0, size.width - margin.horizontal);
    final maxHeight = math.max(0.0, size.height - margin.vertical);
    final dock = layoutChild(
      _DockSlot.dock,
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: maxHeight),
    );
    final top = math.max(margin.top, size.height - margin.bottom - dock.height);
    final previousHeight = geometry.bounds.height;
    geometry.bounds = Rect.fromLTWH(margin.left, top, width, dock.height);
    if ((dock.height - previousHeight).abs() > 0.5) onHeightChanged();
    positionChild(_DockSlot.dock, geometry.bounds.topLeft);
    layoutChild(_DockSlot.content, BoxConstraints.tight(size));
    positionChild(_DockSlot.content, Offset.zero);
  }

  @override
  bool shouldRelayout(covariant _DockLayout oldDelegate) =>
      geometry != oldDelegate.geometry || margin != oldDelegate.margin;
}
