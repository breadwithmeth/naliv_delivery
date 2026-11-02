import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _capabilityChannel = MethodChannel('naliv/native_liquid_glass');
const _viewType = 'naliv/native_liquid_glass_backdrop';

/// Native Apple Liquid Glass capability for the current Flutter engine.
abstract final class NativeLiquidGlass {
  /// Whether this engine can host Apple's iOS 26+ glass effect.
  ///
  /// The future is cached, including failures. Web and non-iOS platforms return
  /// `false` without contacting a platform channel. An iOS registration or API
  /// error completes with [PlatformException], not an unsupported result.
  static final Future<bool> isAvailable = _checkAvailability();

  static Future<bool> _checkAvailability() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;

    final Object? response;
    try {
      response = await _capabilityChannel.invokeMethod<Object?>('isAvailable');
    } on MissingPluginException catch (error) {
      throw PlatformException(
        code: 'native_liquid_glass_not_registered',
        message:
            'Native Liquid Glass is not registered on this Flutter engine. '
            'Register NativeLiquidGlassPlugin through Runner registerPlugins '
            'and rebuild the iOS app with Xcode 26 or newer.',
        details: error.message,
      );
    } on PlatformException catch (error) {
      throw PlatformException(
        code: 'native_liquid_glass_capability_failed',
        message: 'The native Liquid Glass capability check failed. '
            'Check NativeLiquidGlassPlugin registration and the iOS Runner '
            'built with Xcode 26 or newer. ${error.message ?? error.code}',
        details: <String, Object?>{
          'nativeCode': error.code,
          'nativeDetails': error.details,
        },
      );
    }
    if (response is! bool) {
      throw PlatformException(
        code: 'invalid_native_liquid_glass_capability',
        message: 'The native Liquid Glass bridge returned a non-boolean '
            'capability. Rebuild Dart and iOS Runner together so their '
            'glass bridge versions match.',
        details: response,
      );
    }
    return response;
  }
}

/// A pointer-transparent native glass background for a bounded [Stack].
///
/// Mount only after [NativeLiquidGlass.isAvailable] resolves to `true`. Place
/// Flutter foreground controls above this widget, without a clipping mask over
/// the native lens. Changed properties update the existing UIKit effect view.
/// Apple's corner API uses circular radii; an elliptical radius uses its smaller
/// axis. [interactive] configures the glass effect, but this background does not
/// receive or synthesize presses from Flutter foreground controls.
class NativeLiquidGlassBackdrop extends StatefulWidget {
  const NativeLiquidGlassBackdrop({
    required this.borderRadius,
    required this.tint,
    required this.dark,
    this.interactive = true,
    super.key,
  });

  final BorderRadius borderRadius;
  final Color tint;
  final bool dark;
  final bool interactive;

  @override
  State<NativeLiquidGlassBackdrop> createState() =>
      _NativeLiquidGlassBackdropState();
}

class _NativeLiquidGlassBackdropState extends State<NativeLiquidGlassBackdrop> {
  late final Map<String, Object> _creationParameters;
  late Map<String, Object> _parameters;
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    _parameters = _encodeParameters(widget);
    _creationParameters = _parameters;
  }

  @override
  void didUpdateWidget(covariant NativeLiquidGlassBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.borderRadius == widget.borderRadius &&
        oldWidget.tint == widget.tint &&
        oldWidget.dark == widget.dark &&
        oldWidget.interactive == widget.interactive) {
      return;
    }
    _parameters = _encodeParameters(widget);
    if (_channel != null) unawaited(_updateNativeView());
  }

  static Map<String, Object> _encodeParameters(
      NativeLiquidGlassBackdrop backdrop) {
    final radius = backdrop.borderRadius;
    return <String, Object>{
      'tint': backdrop.tint.toARGB32(),
      'dark': backdrop.dark,
      'interactive': backdrop.interactive,
      'cornerRadii': <double>[
        radius.topLeft.x,
        radius.topLeft.y,
        radius.topRight.x,
        radius.topRight.y,
        radius.bottomLeft.x,
        radius.bottomLeft.y,
        radius.bottomRight.x,
        radius.bottomRight.y,
      ],
    };
  }

  void _onPlatformViewCreated(int viewId) {
    if (!mounted) return;
    _channel = MethodChannel('$_viewType/$viewId');
    // Creation is asynchronous. Send changes that arrived before UIKit was ready.
    if (!identical(_creationParameters, _parameters)) {
      unawaited(_updateNativeView());
    }
  }

  Future<void> _updateNativeView() async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.invokeMethod<void>('update', _parameters);
    } catch (error, stackTrace) {
      if (!mounted || !identical(_channel, channel)) return;
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'native Liquid Glass',
        context: ErrorDescription(
          'while updating the existing UIKit glass backdrop; check the '
          'Runner bridge registration and rebuild Dart and iOS together',
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError(
        'NativeLiquidGlassBackdrop requires iOS 26 or newer. '
        'Mount it only when NativeLiquidGlass.isAvailable resolves to true.',
      );
    }
    return ExcludeSemantics(
      child: IgnorePointer(
        child: UiKitView(
          viewType: _viewType,
          layoutDirection: TextDirection.ltr,
          hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          creationParams: _creationParameters,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel = null;
    super.dispose();
  }
}
