import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design/motion.dart';
import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../bonus_account.dart';

const _enter = Duration(milliseconds: 380);
const _leave = Duration(milliseconds: 260);

/// Colours of the till presentation. The page always sits on a dark scrim, so its
/// text is light in both themes; the QR itself is always black on white, because a
/// light-on-dark (inverted) code is the one a lot of till scanners refuse.
const _onScrim = Colors.white;
const _onScrimMuted = Color(0xA3FFFFFF);

/// Opens the bonus card QR full screen, made for scanning at a till.
///
/// [heroTag] must match the [Hero] around the [BonusQrPlate] that started the
/// transition, so the QR grows out of (and shrinks back into) its source. With
/// reduced motion the page appears and leaves instantly.
Future<void> showBonusQr(
  BuildContext context, {
  required String code,
  required Object heroTag,
  num? balance,
  String balanceCaption = 'бонусов',
  String caption = 'Покажите QR на кассе',
}) {
  final reduced = AppMotion.reduced(context);
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: reduced ? Duration.zero : _enter,
      reverseTransitionDuration: reduced ? Duration.zero : _leave,
      pageBuilder: (_, __, ___) => BonusQrPage(
        code: code,
        heroTag: heroTag,
        balance: balance,
        balanceCaption: balanceCaption,
        caption: caption,
      ),
    ),
  );
}

/// The scannable plate: a black QR on pure white with a quiet zone, whatever the
/// theme. Its radius and inset scale with its size, so the same widget serves the
/// small tile on a card, the full-screen page and the hero flight between them.
class BonusQrPlate extends StatelessWidget {
  const BonusQrPlate({required this.code, super.key});

  final String code;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(side * 0.1),
            ),
            child: Padding(
              padding: EdgeInsets.all(side * 0.09),
              child: BarcodeWidget(
                key: const ValueKey('bonus-qr-code'),
                barcode: Barcode.qrCode(),
                data: code,
                drawText: false,
                color: Colors.black,
                backgroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
            ),
          );
        },
      );
}

/// Full-screen bonus card QR: the largest possible code on a white plate, the
/// balance and the card code as text, a close button, and swipe-down / tap-outside
/// to dismiss. Meant to be opened with [showBonusQr].
class BonusQrPage extends StatefulWidget {
  const BonusQrPage({
    required this.code,
    required this.heroTag,
    this.balance,
    this.balanceCaption = 'бонусов',
    this.caption = 'Покажите QR на кассе',
    super.key,
  });

  final String code;
  final Object heroTag;
  final num? balance;
  final String balanceCaption;
  final String caption;

  @override
  State<BonusQrPage> createState() => _BonusQrPageState();
}

class _BonusQrPageState extends State<BonusQrPage>
    with SingleTickerProviderStateMixin {
  static const _dismissDistance = 110.0;
  static const _dismissVelocity = 800.0;

  final _dy = ValueNotifier<double>(0);
  late final AnimationController _settle;
  double _settleFrom = 0;

  @override
  void initState() {
    super.initState();
    _settle = AnimationController(vsync: this)
      ..addListener(
        () => _dy.value =
            _settleFrom * (1 - AppMotion.out.transform(_settle.value)),
      );
  }

  @override
  void dispose() {
    _settle.dispose();
    _dy.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).maybePop();

  void _dragUpdate(DragUpdateDetails details) {
    _settle.stop();
    _dy.value = math.max(0, _dy.value + details.delta.dy);
  }

  void _dragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_dy.value > _dismissDistance || velocity > _dismissVelocity) {
      _close();
      return;
    }
    if (AppMotion.reduced(context)) {
      _dy.value = 0;
      return;
    }
    _settleFrom = _dy.value;
    _settle.duration = AppMotion.pop;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final animation =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final balance = widget.balance;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'QR бонусной карты',
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
        child: Focus(
          autofocus: true,
          child: Material(
            key: const ValueKey('bonus-qr-page'),
            type: MaterialType.transparency,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              onVerticalDragUpdate: _dragUpdate,
              onVerticalDragEnd: _dragEnd,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([animation, _dy]),
                    builder: (context, _) {
                      final pulled = (_dy.value / 360).clamp(0.0, 1.0);
                      final t = animation.value * (1 - 0.6 * pulled);
                      // A blurred, nearly opaque backdrop so the page behind
                      // reads as atmosphere, never as text next to the code.
                      final scrim = ColoredBox(
                        color: Colors.black.withValues(alpha: 0.94 * t),
                      );
                      if (t <= 0 || MediaQuery.highContrastOf(context)) {
                        return scrim;
                      }
                      return BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: 24 * t,
                          sigmaY: 24 * t,
                          tileMode: TileMode.clamp,
                        ),
                        child: scrim,
                      );
                    },
                  ),
                  SafeArea(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _dy,
                      builder: (context, dy, child) => Transform.translate(
                        offset: Offset(0, dy),
                        child: child,
                      ),
                      child: Column(
                        children: [
                          _TopBar(onClose: _close, animation: animation),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final side = math.max(
                                  160.0,
                                  math.min(
                                    math.min(box.maxWidth - 48, 440.0),
                                    box.maxHeight * 0.52,
                                  ),
                                );
                                return SingleChildScrollView(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                        minHeight: box.maxHeight),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.huge,
                                          vertical: AppSpacing.xxxl,
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox.square(
                                              dimension: side,
                                              child: Hero(
                                                tag: widget.heroTag,
                                                child: BonusQrPlate(
                                                    code: widget.code),
                                              ),
                                            ),
                                            const SizedBox(
                                                height: AppSpacing.huge),
                                            _Reveal(
                                              animation: animation,
                                              child: _Details(
                                                caption: widget.caption,
                                                balance: balance,
                                                balanceCaption:
                                                    widget.balanceCaption,
                                                code: widget.code,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Close button and the swipe grabber. Both fade in with the route.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose, required this.animation});

  final VoidCallback onClose;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => _Reveal(
        animation: animation,
        rise: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.touchTarget),
              Expanded(
                child: Center(
                  child: ExcludeSemantics(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _onScrim.withValues(alpha: 0.28),
                        borderRadius: AppRadii.pillAll,
                      ),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Закрыть',
                child: Semantics(
                  button: true,
                  label: 'Закрыть',
                  excludeSemantics: true,
                  child: InkResponse(
                    key: const ValueKey('bonus-qr-close'),
                    onTap: onClose,
                    radius: 26,
                    child: SizedBox.square(
                      dimension: AppSpacing.touchTarget,
                      child: Center(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: _onScrim.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox.square(
                            dimension: 40,
                            child: Icon(Icons.close_rounded,
                                size: 22, color: _onScrim),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Fades (and lifts) its child in over the later part of the route transition,
/// after the hero has mostly landed.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.animation, required this.child, this.rise = 14});

  final Animation<double> animation;
  final Widget child;
  final double rise;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final t = const Interval(0.35, 1, curve: AppMotion.out)
              .transform(animation.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, rise * (1 - t)),
              child: child,
            ),
          );
        },
      );
}

class _Details extends StatelessWidget {
  const _Details({
    required this.caption,
    required this.balance,
    required this.balanceCaption,
    required this.code,
  });

  final String caption;
  final num? balance;
  final String balanceCaption;
  final String code;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          caption,
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(color: _onScrim),
        ),
        if (balance != null) ...[
          const SizedBox(height: AppSpacing.xl),
          Text.rich(
            key: const ValueKey('bonus-qr-balance'),
            TextSpan(children: [
              TextSpan(
                text: bonusNumberLabel(balance!),
                style:
                    AppTypography.displayBold.copyWith(color: palette.accent),
              ),
              TextSpan(
                text: ' $balanceCaption',
                style: AppTypography.bodySmallSemibold
                    .copyWith(color: _onScrimMuted),
              ),
            ]),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          label: 'Код карты $code',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Код карты',
                  style:
                      AppTypography.labelMedium.copyWith(color: _onScrimMuted)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                code,
                key: const ValueKey('bonus-qr-card-code'),
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: _onScrim,
                  letterSpacing: 0.4,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
