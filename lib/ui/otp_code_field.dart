import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'frosted_surface.dart';

/// Returns the one-time code of exactly [length] digits contained in [text], or
/// null. Accepts a bare code, a code split by spaces or dashes ("123 456",
/// "123-456") and an SMS sentence ("Ваш код: 123456. Никому не сообщайте").
/// A phone number or any other digit string is not a code.
String? extractOtpCode(String text, {required int length}) {
  final run = RegExp('(?<!\\d)\\d{$length}(?!\\d)').firstMatch(text);
  if (run != null) return run.group(0);
  final compact = text.replaceAll(RegExp(r'[\s\-\u2010-\u2015.·]'), '');
  return RegExp('^\\d{$length}\$').hasMatch(compact) ? compact : null;
}

/// Keeps only the digits of a one-time code and lets a pasted or autofilled
/// code replace the whole value.
///
/// Typing past [length] digits is ignored. A paste containing a full code
/// (even with spaces, dashes or surrounding words) replaces what was there, so
/// pasting over an already complete code works too.
class OtpCodeFormatter extends TextInputFormatter {
  const OtpCodeFormatter({required this.length});

  final int length;

  static final _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final onlyDigits = !raw.contains(_nonDigits);
    if (onlyDigits && raw.length <= length) return newValue;

    final inserted = _inserted(oldValue, newValue);
    final code = extractOtpCode(inserted, length: length);
    final text = code ?? raw.replaceAll(_nonDigits, '');
    final accepted = text.length > length ? text.substring(0, length) : text;
    return TextEditingValue(
      text: accepted,
      selection: TextSelection.collapsed(offset: accepted.length),
    );
  }

  /// The text that arrived with this edit: the grown part of the value when
  /// text was inserted, otherwise the whole value (a replacement).
  static String _inserted(TextEditingValue oldValue, TextEditingValue value) {
    final grown = value.text.length - oldValue.text.length;
    final end = value.selection.end;
    if (grown > 0 && value.selection.isValid && end >= grown) {
      return value.text.substring(end - grown, end);
    }
    return value.text;
  }
}

/// One-time code entry drawn as separate boxes and driven by **one** real
/// (invisible) [TextField].
///
/// Because the field is real, the platform treats it as a code field: iOS
/// offers the code from Messages, Android keyboards suggest a copied code, long
/// press offers Paste, and hardware keyboards and screen readers work. The
/// boxes only render [controller]; the field lies on top of them, so tapping
/// any box focuses it, and a collapsed caret is always kept at the end so
/// typing appends and backspace removes the last digit.
///
/// Under the boxes only an [errorText] appears, when there is one.
class OtpCodeField extends StatefulWidget {
  const OtpCodeField({
    required this.controller,
    required this.focusNode,
    this.length = 6,
    this.fieldKey,
    this.autofocus = true,
    this.busy = false,
    this.errorText,
    this.errorShake = 0,
    this.onSubmitted,
    this.semanticLabel = 'Код из SMS',
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;

  /// Key of the underlying [TextField].
  final Key? fieldKey;
  final bool autofocus;

  /// A verification is in flight: the boxes dim but keep focus, so the
  /// keyboard does not collapse and reopen.
  final bool busy;

  /// Tints the boxes and replaces the status slot with this message.
  final String? errorText;

  /// Each increase plays the shake.
  final int errorShake;
  final ValueChanged<String>? onSubmitted;
  final String semanticLabel;

  @override
  State<OtpCodeField> createState() => _OtpCodeFieldState();
}

class _OtpCodeFieldState extends State<OtpCodeField>
    with SingleTickerProviderStateMixin {
  static const _boxMaxWidth = 51.0;
  static const _boxMinHeight = 45.0;
  static const _gap = 4.0;
  static const _groupGap = 10.0;
  static const _caretHalfPeriod = Duration(milliseconds: 530);

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  final ValueNotifier<bool> _caretOn = ValueNotifier<bool>(true);
  Timer? _caretTimer;
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onValueChanged);
    widget.focusNode.addListener(_onFocusChanged);
    _hadFocus = widget.focusNode.hasFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restartCaretBlink());
  }

  @override
  void didUpdateWidget(OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onValueChanged);
      widget.controller.addListener(_onValueChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
    if (widget.errorShake > oldWidget.errorShake) {
      unawaited(HapticFeedback.heavyImpact().catchError((_) {}));
      if (!AppMotion.reduced(context)) _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValueChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _caretTimer?.cancel();
    _caretOn.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _onValueChanged() {
    final value = widget.controller.value;
    final end = value.text.length;
    final selection = value.selection;
    // A tap inside the code would otherwise move the caret under a digit:
    // typing appends, so keep a collapsed caret at the end. A range selection
    // (select all, long press) stays so it can be replaced or pasted over.
    if (selection.isCollapsed && selection.baseOffset != end) {
      widget.controller.value = value.copyWith(
        selection: TextSelection.collapsed(offset: end),
      );
      return;
    }
    _restartCaretBlink();
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    final focused = widget.focusNode.hasFocus;
    if (focused == _hadFocus) return;
    _hadFocus = focused;
    _restartCaretBlink();
    if (mounted) setState(() {});
  }

  /// The caret is solid after every edit, then blinks. A timer rather than an
  /// animation: no frames are scheduled between blinks, and the caret holds
  /// steady when animations are reduced.
  void _restartCaretBlink() {
    _caretTimer?.cancel();
    _caretTimer = null;
    if (!mounted) return;
    _caretOn.value = true;
    final active = widget.focusNode.hasFocus &&
        widget.controller.text.length < widget.length;
    if (!active || AppMotion.reduced(context)) return;
    _caretTimer = Timer.periodic(_caretHalfPeriod, (_) {
      _caretOn.value = !_caretOn.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final length = widget.length;
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final focused = widget.focusNode.hasFocus;
    final hasError = widget.errorText != null;
    final activeIndex = focused && text.length < length ? text.length : -1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final available =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 343.0;
            final groups = length.isEven && length > 2;
            final gapTotal =
                (length - 1) * _gap + (groups ? _groupGap - _gap : 0);
            final boxWidth = math.min(
              _boxMaxWidth,
              math.max(24.0, (available - gapTotal) / length),
            );
            final scaler = MediaQuery.textScalerOf(context);
            final boxHeight = math.max(_boxMinHeight, scaler.scale(26) + 12);
            return Center(
              child: SizedBox(
                width: boxWidth * length + gapTotal,
                height: boxHeight,
                child: _entry(
                  boxWidth: boxWidth,
                  boxHeight: boxHeight,
                  text: text,
                  selection: selection,
                  activeIndex: activeIndex,
                  hasError: hasError,
                  groups: groups,
                ),
              ),
            );
          },
        ),
        AnimatedSize(
          duration: AppMotion.of(context, AppMotion.swap),
          curve: AppMotion.out,
          alignment: Alignment.topCenter,
          child: widget.errorText == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: _error(widget.errorText!),
                ),
        ),
      ],
    );
  }

  Widget _entry({
    required double boxWidth,
    required double boxHeight,
    required String text,
    required TextSelection selection,
    required int activeIndex,
    required bool hasError,
    required bool groups,
  }) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final length = widget.length;
    final reduced = AppMotion.reduced(context);
    final duration = AppMotion.of(context, AppMotion.state);
    final selectedFrom =
        selection.isValid && !selection.isCollapsed ? selection.start : length;
    final selectedTo =
        selection.isValid && !selection.isCollapsed ? selection.end : 0;
    final errorColor =
        dark ? palette.error : Color.lerp(palette.error, Colors.black, 0.22)!;
    const transparent = Colors.transparent;

    final boxes = <Widget>[];
    for (var i = 0; i < length; i++) {
      if (i > 0) {
        boxes.add(
            SizedBox(width: groups && i == length ~/ 2 ? _groupGap : _gap));
      }
      final digit = i < text.length ? text[i] : null;
      final active = i == activeIndex;
      final selected = digit != null && i >= selectedFrom && i < selectedTo;
      final ring = hasError
          ? errorColor
          : active
              ? palette.accent
              : palette.accent.withValues(alpha: 0);
      final wash = hasError
          ? errorColor.withValues(alpha: 0.12)
          : selected
              ? palette.accent.withValues(alpha: 0.22)
              : palette.accent.withValues(alpha: 0);
      boxes.add(
        FrostedSurface(
          borderRadius: AppRadii.lgAll,
          // Opaque-ish control fill: the page behind the boxes is flat.
          tint: palette.surface,
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.out,
            width: boxWidth,
            height: boxHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: wash,
              borderRadius: AppRadii.lgAll,
              border: Border.all(color: ring, width: 1.5),
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.pop),
              switchInCurve: AppMotion.overshoot,
              switchOutCurve: AppMotion.leave,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.6, end: 1).animate(animation),
                  child: child,
                ),
              ),
              child: digit != null
                  ? Padding(
                      key: ValueKey('otp-digit-$i-$digit'),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          digit,
                          style: AppTypography.base(
                            size: 20,
                            weight: 500,
                            color: palette.textPrimary,
                          ).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    )
                  : active
                      ? ValueListenableBuilder<bool>(
                          key: ValueKey('otp-caret-$i'),
                          valueListenable: _caretOn,
                          builder: (context, on, _) => Opacity(
                            opacity: on || reduced ? 1 : 0,
                            child: Container(
                              width: 2,
                              height: 22,
                              decoration: BoxDecoration(
                                color: palette.accent,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        )
                      : SizedBox.shrink(key: ValueKey('otp-empty-$i')),
            ),
          ),
        ),
      );
    }

    return AnimatedOpacity(
      duration: AppMotion.of(context, AppMotion.state),
      opacity: widget.busy ? 0.55 : 1,
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _shake,
                builder: (context, child) {
                  final t = _shake.value;
                  final dx = math.sin(t * math.pi * 6) * (1 - t) * 10;
                  return Transform.translate(
                    offset: Offset(t == 0 ? 0 : dx, 0),
                    child: child,
                  );
                },
                // The row is the only thing painted; it must not intercept the
                // field's gestures.
                child: IgnorePointer(
                  // The page behind is flat: boxes paint only tint and edge
                  // instead of six backdrop blurs.
                  child: FrostedScope(child: Row(children: boxes)),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: TextSelectionTheme(
              data: const TextSelectionThemeData(
                cursorColor: transparent,
                selectionColor: transparent,
                selectionHandleColor: transparent,
              ),
              child: Semantics(
                label: widget.semanticLabel,
                child: TextField(
                  key: widget.fieldKey,
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  autofocus: widget.autofocus,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [OtpCodeFormatter(length: length)],
                  maxLength: length,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  textAlign: TextAlign.center,
                  textAlignVertical: TextAlignVertical.center,
                  showCursor: false,
                  cursorWidth: 0,
                  cursorColor: transparent,
                  // Invisible but real: it keeps text, selection and IME state.
                  style: const TextStyle(color: transparent, fontSize: 20),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isCollapsed: true,
                    filled: false,
                  ),
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  onSubmitted: widget.onSubmitted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _error(String errorText) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color =
        dark ? palette.error : Color.lerp(palette.error, Colors.black, 0.22)!;
    return Semantics(
      key: const ValueKey('otp-error'),
      liveRegion: true,
      child: Text(
        errorText,
        textAlign: TextAlign.center,
        style: AppTypography.bodySmall.copyWith(color: color),
      ),
    );
  }
}
