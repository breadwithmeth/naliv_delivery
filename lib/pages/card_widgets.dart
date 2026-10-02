import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../features/faq/ui/faq_page.dart';
import '../ui/app_icon.dart';
import '../ui/surfaces.dart';
import '../utils/web_window.dart';
import 'add_card_webview_page.dart';
import 'card_flow.dart';
import 'login_page.dart';
import '../features/faq/models/faq.dart' show FaqSection;

const cardFormWindowName = 'gradusy24_add_card';

Future<CardFormOutcome> openHostedCardForm(
  BuildContext context,
  Uri uri,
  Object? reservedWindow, {
  Future<bool> Function(Uri)? openCardForm,
}) async {
  if (openCardForm != null) {
    return await openCardForm(uri)
        ? CardFormOutcome.opened
        : CardFormOutcome.failed;
  }
  if (kIsWeb) {
    return navigateReservedWebWindow(
      reservedWindow,
      uri.toString(),
      windowName: cardFormWindowName,
    )
        ? CardFormOutcome.opened
        : CardFormOutcome.failed;
  }
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    final returned = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AddCardWebViewPage(initialUrl: uri.toString()),
    ));
    return returned == true
        ? CardFormOutcome.returned
        : CardFormOutcome.cancelled;
  }
  final launched = await launchUrl(
    uri,
    mode: defaultTargetPlatform == TargetPlatform.iOS
        ? LaunchMode.inAppWebView
        : LaunchMode.externalApplication,
  );
  return launched ? CardFormOutcome.opened : CardFormOutcome.failed;
}

class CardFaqPanel extends StatelessWidget {
  const CardFaqPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return AppSurface(
      fill: palette.accent.withValues(alpha: .2),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accent.withValues(alpha: .25),
            ),
            child: Center(
                child: Text('?',
                    style: AppTypography.headline
                        .copyWith(color: palette.accent))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Не получается добавить карту?',
                    style: AppTypography.bodyBold),
                const SizedBox(height: 8),
                Text(
                  'В FAQ собраны ответы по привязке карты и оплате заказов',
                  style: AppTypography.bodySmall.copyWith(
                      color: palette.textPrimary.withValues(alpha: .5)),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) =>
                        const FaqPage(initialSection: FaqSection.payment),
                  )),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Открыть FAQ'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SavedCardRow extends StatelessWidget {
  const SavedCardRow(
      {required this.card, this.selected = false, this.onSelected, super.key});

  final SavedCard card;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? palette.accentFaint : palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: palette.accent) : null,
      ),
      child: Row(
        children: [
          AppIcon(AppIcons.cards, size: 24, color: palette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.mask, style: AppTypography.title),
                Text('Карта',
                    style: AppTypography.bodySmall
                        .copyWith(color: palette.textSecondary)),
              ],
            ),
          ),
          if (onSelected != null) ...[
            const SizedBox(width: 12),
            Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? palette.accent : palette.textSecondary,
                size: 24),
          ],
        ],
      ),
    );
    if (onSelected == null) return content;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
            onTap: onSelected,
            borderRadius: BorderRadius.circular(12),
            child: content),
      ),
    );
  }
}

class CardFlowFeedback extends StatelessWidget {
  const CardFlowFeedback({required this.flow, super.key});

  final CardFlow flow;

  @override
  Widget build(BuildContext context) {
    final message = flow.message;
    if (message == null) return const SizedBox.shrink();
    final palette = context.palette;
    final confirmed = flow.addState == CardAddState.confirmed;
    final color = confirmed
        ? palette.success
        : flow.messageIsError
            ? palette.error
            : palette.accent;
    return AppSurface(
      fill: confirmed
          ? color.withValues(alpha: .75)
          : color.withValues(alpha: .12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (confirmed)
                  const AppIcon(AppIcons.check, size: 20, color: Colors.black)
                else
                  Icon(
                      flow.messageIsError
                          ? Icons.error_outline
                          : Icons.info_outline,
                      size: 20,
                      color: color),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(message,
                        style: AppTypography.body.copyWith(
                          color: confirmed ? Colors.black : palette.textPrimary,
                        ))),
              ],
            ),
            if (flow.awaiting ||
                flow.preparing ||
                (flow.messageIsError && flow.canAdd) ||
                flow.addState == CardAddState.launchFailed)
              Wrap(
                spacing: AppSpacing.xl,
                children: [
                  if (flow.messageIsError && flow.canAdd)
                    TextButton(
                      key: const ValueKey('retry-card-add'),
                      onPressed: flow.addCard,
                      child: const Text('Повторить'),
                    ),
                  if (flow.awaiting)
                    TextButton(
                      key: const ValueKey('refresh-card-list'),
                      onPressed: flow.loading ? null : flow.refresh,
                      child: const Text('Обновить список'),
                    ),
                  if (flow.awaiting ||
                      flow.preparing ||
                      flow.addState == CardAddState.launchFailed)
                    TextButton(
                      key: const ValueKey('cancel-card-add'),
                      onPressed: flow.cancel,
                      child: const Text('Отменить ожидание'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class CardReadFeedback extends StatelessWidget {
  const CardReadFeedback({
    required this.flow,
    this.allowSignIn = true,
    super.key,
  });

  final CardFlow flow;
  final bool allowSignIn;

  Future<void> _signIn(BuildContext context) async {
    if (!allowSignIn) return;
    final authenticated =
        await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => const LoginPage(
        startWithPhoneForm: true,
        completionMode: LoginCompletionMode.returnAuthenticated,
      ),
    ));
    if (authenticated == true && context.mounted) await flow.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = flow.error ?? flow.partialWarning;
    if (text == null) return const SizedBox.shrink();
    final palette = context.palette;
    return AppSurface(
      key: ValueKey(
          flow.error == null ? 'card-read-partial' : 'card-read-error'),
      fill: (flow.error == null ? palette.accent : palette.error)
          .withValues(alpha: .12),
      padding: const EdgeInsets.all(12),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: AppTypography.body),
            const SizedBox(height: 8),
            Wrap(
              spacing: AppSpacing.xl,
              runSpacing: AppSpacing.md,
              children: [
                if (flow.authRequired && allowSignIn)
                  FilledButton(
                    key: const ValueKey('card-sign-in'),
                    onPressed: flow.preparing || flow.loading
                        ? null
                        : () => _signIn(context),
                    child: const Text('Войти'),
                  ),
                TextButton(
                  key: const ValueKey('retry-card-read'),
                  onPressed:
                      flow.preparing || flow.loading ? null : flow.refresh,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
