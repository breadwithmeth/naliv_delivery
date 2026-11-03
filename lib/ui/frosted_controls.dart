import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'frosted_surface.dart';

/// A text field drawn as glass: the shared [FrostedSurface] material with the
/// design's field metrics (`45` high, radius 10, 14 px inset, Light 16 text).
///
/// Focus is shown by an accent ring that fades in over the hairline edge, so
/// the field never changes size. [fieldKey] is attached to the inner
/// [TextField], which is what tests and assistive tools address.
///
/// Inside a [FrostedScope] (a frosted header, a frosted sheet) the surface
/// paints only its tint, so stacking several fields costs no extra blur.
class FrostedTextField extends StatefulWidget {
  const FrostedTextField({
    required this.controller,
    this.fieldKey,
    this.focusNode,
    this.hintText,
    this.semanticLabel,
    this.suffixText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.minLines,
    this.maxLines = 1,
    this.enabled = true,
    this.readOnly = false,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.minHeight = 45,
    this.borderRadius = AppRadii.lgAll,
    this.tint,
    this.contentPadding = const EdgeInsets.symmetric(horizontal: 14),
    this.textStyle,
    this.trailing,
    this.trailingAlignment = CrossAxisAlignment.center,
    super.key,
  });

  final TextEditingController controller;
  final Key? fieldKey;
  final FocusNode? focusNode;
  final String? hintText;

  /// Spoken name of the field; the hint alone disappears once text is typed.
  final String? semanticLabel;
  final String? suffixText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? minLines;
  final int? maxLines;
  final bool enabled;
  final bool readOnly;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double minHeight;
  final BorderRadius borderRadius;

  /// Overrides [Frost.tint], for example on an already tinted sheet.
  final Color? tint;

  /// Horizontal inset of the text; vertical centring comes from [minHeight].
  final EdgeInsetsGeometry contentPadding;
  final TextStyle? textStyle;

  /// Sits after the text, e.g. a send button; see [trailingAlignment].
  final Widget? trailing;
  final CrossAxisAlignment trailingAlignment;

  @override
  State<FrostedTextField> createState() => _FrostedTextFieldState();
}

class _FrostedTextFieldState extends State<FrostedTextField> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void didUpdateWidget(FrostedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != null && _ownFocus != null) {
      _ownFocus!.dispose();
      _ownFocus = null;
    }
  }

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final style = (widget.textStyle ?? AppTypography.bodyLight).copyWith(
        color: widget.enabled ? palette.textPrimary : palette.textSecondary);
    final hint = AppTypography.bodyLight.copyWith(color: palette.textSecondary);
    final multiline = widget.maxLines != 1;
    final field = TextField(
      key: widget.fieldKey,
      controller: widget.controller,
      focusNode: _focus,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      cursorColor: palette.accent,
      style: style,
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          vertical: multiline ? 12 : 0,
        ).add(widget.contentPadding),
        hintText: widget.hintText,
        hintStyle: hint,
        suffixText: widget.suffixText,
        suffixStyle: style.copyWith(color: palette.textSecondary),
      ),
    );
    final labelled = widget.semanticLabel == null
        ? field
        : Semantics(label: widget.semanticLabel, child: field);
    return FrostedSurface(
      borderRadius: widget.borderRadius,
      tint: widget.tint,
      child: ListenableBuilder(
        listenable: _focus,
        builder: (context, child) => AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: BoxConstraints(minHeight: widget.minHeight),
          alignment: Alignment.center,
          foregroundDecoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _focus.hasFocus && widget.enabled
                  ? palette.accent
                  : palette.accent.withValues(alpha: 0),
              width: 1.5,
            ),
          ),
          child: child,
        ),
        child: Row(
          crossAxisAlignment: widget.trailingAlignment,
          children: [
            Expanded(child: labelled),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

/// A primary action drawn as orange glass: [FrostedSurface] tinted with
/// [Frost.accent] carrying a transparent [FilledButton].
///
/// [buttonKey] lands on the [FilledButton], so `onPressed` stays inspectable.
/// The tint fades between enabled and disabled instead of jumping.
class FrostedButton extends StatelessWidget {
  const FrostedButton({
    required this.onPressed,
    required this.child,
    this.buttonKey,
    this.borderRadius = AppRadii.lgAll,
    this.minHeight = 45,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    super.key,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Key? buttonKey;
  final BorderRadius borderRadius;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final accent = Frost.accent(context);
    final tint = onPressed == null ? accent.withValues(alpha: 0.42) : accent;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: tint),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 180),
      builder: (context, color, child) => FrostedSurface(
        tint: color,
        borderRadius: borderRadius,
        child: child!,
      ),
      child: FilledButton(
        key: buttonKey,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: palette.textOnAccent,
          disabledForegroundColor: palette.textOnAccent.withValues(alpha: 0.7),
          shadowColor: Colors.transparent,
          elevation: 0,
          minimumSize: Size(AppSpacing.touchTarget, minHeight),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: padding,
          textStyle: AppTypography.bodyMedium,
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        child: child,
      ),
    );
  }
}
