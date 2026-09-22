import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_icon.dart';

/// The four introduction slides — the design's `Регистрация и логин - Слайд 1…4` frames.
///
/// Measured from the frames: the wordmark 166 × 38 centred at y = 70, a 100 px badge (accent
/// @50 % disc with a 68 px glyph) at y = 316, title 20/700 at y = 440 and body 14/400 muted at
/// y = 478, then a constant bottom block — «Войдите, чтобы не упустить выгоду» 12/400 at
/// y = 676 over a 343 × 49 r100 «Войти или зарегистрироваться» pill at y = 704.
///
/// The frames contain **no pagination dots**, so none are drawn: the slides advance by swiping.
/// The call to action is identical on every slide, exactly as the frames show.
class IntroSlidesPage extends StatefulWidget {
  const IntroSlidesPage({required this.onContinue, super.key});

  /// Proceeds to sign-in; the caller also records that the slides were seen.
  final Future<void> Function() onContinue;

  @override
  State<IntroSlidesPage> createState() => _IntroSlidesPageState();
}

class _IntroSlidesPageState extends State<IntroSlidesPage> {
  static const _slides = <({String icon, String title, String body})>[
    (
      icon: AppIcons.discountShape,
      title: 'Персональные акции',
      body: 'Уникальные скидки только для вас',
    ),
    (
      icon: AppIcons.bagHappy,
      title: 'Быстрый заказ',
      body: 'Оформление в пару нажатий',
    ),
    (
      icon: AppIcons.bagTimer,
      title: 'История покупок',
      body: 'Повторите любой прошлый заказ',
    ),
    (
      icon: AppIcons.bonusStar,
      title: 'Бонусы',
      body: 'Копите с каждой покупки',
    ),
  ];

  final _controller = PageController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: top + 22),
              const SizedBox(
                height: 38,
                child: Center(
                  // The exported lockup is white-on-transparent (drawn for the dark theme), so
                  // it is tinted from the palette — otherwise it disappears on a white page.
                  child: _Wordmark(),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  itemBuilder: (context, index) =>
                      _Slide(slide: _slides[index]),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.xxxl,
                  0,
                  AppSpacing.xxxl,
                  bottom + AppSpacing.huge,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Войдите, чтобы не упустить выгоду',
                      textAlign: TextAlign.center,
                      style: AppTypography.base(size: 12, weight: 400)
                          .copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    GestureDetector(
                      onTap: _busy ? null : _continue,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 49,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          'Войти или зарегистрироваться',
                          style:
                              AppTypography.title.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The wordmark, tinted from the palette so it reads on both themes.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => AppIcon(AppIcons.wordmark,
      width: 166, height: 38, color: context.palette.textPrimary);
}

class _Slide extends StatelessWidget {
  const _Slide({required this.slide});

  final ({String icon, String title, String body}) slide;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Center(child: AppIcon(slide.icon, size: 68)),
        ),
        const SizedBox(height: AppSpacing.huge),
        Text(
          slide.title,
          textAlign: TextAlign.center,
          style: AppTypography.headline.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          slide.body,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: AppSpacing.huge),
      ],
    );
  }
}
