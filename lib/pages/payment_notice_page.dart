import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../features/faq/models/faq.dart' show FaqSection;
import '../features/faq/ui/faq_page.dart';
import '../ui/app_top_bar.dart';
import '../ui/frosted_dock.dart';
import '../ui/frosted_surface.dart';
import '../ui/kaspi_payment.dart';
import '../ui/motion_widgets.dart';
import 'card_widgets.dart' show CardFaqPanel;

/// What the payment page does once a [PaymentNoticePage] has closed.
///
/// The notice is a dialog route over a payment that is still being finished, so it only
/// reports the choice; the page runs it after its own "paying" state has been released.
enum PaymentFollowUp {
  /// Start the same payment again. Offered only when the guard says no charge can exist.
  retry,

  /// Open the Kaspi link that was already created, without a new request.
  reopen,

  /// Ask the server for the order's payment status.
  check,

  /// Open the support chat with the payment error attached.
  support,
}

/// A button of a [PaymentNoticePage].
class PaymentNoticeChoice {
  const PaymentNoticeChoice(this.label, {this.followUp, this.key});

  final String label;

  /// Handed to the payment page; null only closes the notice.
  final PaymentFollowUp? followUp;
  final Key? key;
}

/// A full-screen payment result.
///
/// Kaspi.kz screens follow Kaspi's template for the payment process: the logo, a red
/// loader while preparing, a grey cross for a cancelled or failed payment, then the title
/// and a single reason. Card screens use the app's own marks. Actions sit in a
/// [FrostedDock] so they stay put while a long reason scrolls beneath the header.
///
/// While [loading] the screen has no actions and cannot be left. Otherwise [onResult]
/// receives the follow-up of the tapped choice, or null when the notice was only
/// dismissed (back, or a choice without a follow-up).
class PaymentNoticePage extends StatefulWidget {
  const PaymentNoticePage({
    required this.title,
    this.message,
    this.note,
    this.kaspi = false,
    this.loading = false,
    this.failed = false,
    this.primary,
    this.secondary,
    this.help = false,
    this.cardFaq = false,
    this.onResult,
    super.key,
  });

  final String title;

  /// The one-line reason under the title.
  final String? message;

  /// A muted explanation under [message], for example why a retry is blocked.
  final String? note;
  final bool kaspi;
  final bool loading;
  final bool failed;
  final PaymentNoticeChoice? primary;
  final PaymentNoticeChoice? secondary;

  /// Shows the support and payment-FAQ links under the actions.
  final bool help;

  /// Card payments only: the FAQ banner of the card-error design replaces the FAQ link.
  final bool cardFaq;
  final ValueChanged<PaymentFollowUp?>? onResult;

  @override
  State<PaymentNoticePage> createState() => _PaymentNoticePageState();
}

class _PaymentNoticePageState extends State<PaymentNoticePage> {
  double _dockHeight = 0;

  bool get _interactive => widget.onResult != null && !widget.loading;

  void _choose(PaymentNoticeChoice choice) => widget.onResult!(choice.followUp);

  void _openFaq() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const FaqPage(initialSection: FaqSection.payment),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: FrostedDock(
            onDockHeightChanged: (height) {
              if ((height - _dockHeight).abs() > 0.5) {
                setState(() => _dockHeight = height);
              }
            },
            content: _interactive
                ? FrostedHeaderLayout(
                    estimatedHeaderHeight: 87,
                    header: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xxxl, 0, AppSpacing.xxxl, AppSpacing.md),
                      child: AppTopBar(
                        title: '',
                        onBack: () => widget.onResult!(null),
                      ),
                    ),
                    body: _body,
                  )
                : SafeArea(bottom: false, child: _body(context, 0)),
            dock: _interactive ? _actions(context) : null,
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, double topInset) {
    final bottom = MediaQuery.paddingOf(context).bottom +
        (_interactive ? _dockHeight + AppSpacing.huge : AppSpacing.huge);
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xxxl,
                topInset + AppSpacing.huge, AppSpacing.xxxl, bottom),
            child: Center(child: _content(context)),
          ),
        ),
      ],
    );
  }

  Widget _content(BuildContext context) {
    final palette = context.palette;
    final kaspi = widget.kaspi;
    final loading = widget.loading;
    final failed = widget.failed;
    final Widget? mark;
    if (kaspi && loading) {
      mark = const KaspiLoader();
    } else if (kaspi && failed) {
      mark = const AppearIn(
        scale: .7,
        duration: AppMotion.pop,
        child: KaspiResultMark(accepted: false),
      );
    } else if (kaspi) {
      mark = null;
    } else if (loading) {
      mark = SizedBox(
        width: 80,
        height: 80,
        child: CircularProgressIndicator(
          strokeWidth: 8,
          strokeCap: StrokeCap.round,
          color: palette.accent,
          backgroundColor: palette.textSecondary,
        ),
      );
    } else {
      mark = AppearIn(
        scale: .7,
        duration: AppMotion.pop,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: failed ? palette.error : palette.accentFaint,
          ),
          child: Icon(
            failed ? Icons.close_rounded : Icons.schedule_rounded,
            size: 48,
            color: failed ? Colors.white : palette.accent,
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kaspi) ...[
            const KaspiLogo(),
            const SizedBox(height: AppSpacing.huge),
          ],
          if (mark != null) ...[
            mark,
            const SizedBox(height: AppSpacing.huge),
          ],
          Semantics(
            container: true,
            liveRegion: failed,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.title,
                    style: AppTypography.headline, textAlign: TextAlign.center),
                if (widget.message != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text(widget.message!,
                      style: AppTypography.body
                          .copyWith(color: palette.textSecondary),
                      textAlign: TextAlign.center),
                ],
                if (widget.note != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(widget.note!,
                      style: AppTypography.bodySmall
                          .copyWith(color: palette.textSecondary),
                      textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
          if (widget.cardFaq) ...[
            const SizedBox(height: AppSpacing.huge),
            const CardFaqPanel(),
          ],
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    final primary = widget.primary ?? const PaymentNoticeChoice('Понятно');
    final secondary = widget.secondary;
    const shape = StadiumBorder();
    const minimumSize = Size.fromHeight(52);
    return Padding(
      // The dock supplies the 16 dp sides and the safe-area inset below.
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.xxxl, 0, AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: primary.key,
            onPressed: () => _choose(primary),
            style:
                FilledButton.styleFrom(minimumSize: minimumSize, shape: shape),
            child: Text(primary.label, textAlign: TextAlign.center),
          ),
          if (secondary != null) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              key: secondary.key,
              onPressed: () => _choose(secondary),
              style: OutlinedButton.styleFrom(
                  minimumSize: minimumSize, shape: shape),
              child: Text(secondary.label, textAlign: TextAlign.center),
            ),
          ],
          if (widget.help)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    key: const ValueKey('payment-notice-support'),
                    onPressed: () => widget.onResult!(PaymentFollowUp.support),
                    style:
                        TextButton.styleFrom(minimumSize: const Size(44, 44)),
                    child: const Text('Написать в поддержку'),
                  ),
                  if (!widget.cardFaq)
                    TextButton(
                      key: const ValueKey('payment-notice-faq'),
                      onPressed: _openFaq,
                      style:
                          TextButton.styleFrom(minimumSize: const Size(44, 44)),
                      child: const Text('Вопросы об оплате'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
