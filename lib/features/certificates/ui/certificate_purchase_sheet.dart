import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../design/theme.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../pages/card_flow.dart';
import '../../../pages/card_widgets.dart';
import '../../../ui/surfaces.dart';
import '../../../utils/api.dart';
import '../../../utils/web_window.dart';
import '../certificate_purchase_session.dart';

/// Opens the supported saved-card certificate purchase form.
///
/// The caller owns [session], so dismissing and reopening an unresolved purchase
/// keeps its draft and server identity. A null [openCardForm] uses the actual bank
/// helper; an override only launches the form, never confirms card binding.
Future<Map<String, dynamic>?> showCertificatePurchase(
  BuildContext context, {
  required CertificatePurchaseSession session,
  Future<bool> Function(Uri)? openCardForm,
}) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      backgroundColor: context.palette.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: CertificatePurchaseSheet(
          session: session,
          openCardForm: openCardForm,
        ),
      ),
    );

class CertificatePurchaseSheet extends StatefulWidget {
  const CertificatePurchaseSheet({
    super.key,
    required this.session,
    this.openCardForm,
  });

  final CertificatePurchaseSession session;
  final Future<bool> Function(Uri)? openCardForm;

  @override
  State<CertificatePurchaseSheet> createState() =>
      _CertificatePurchaseSheetState();
}

class _CertificatePurchaseSheetState extends State<CertificatePurchaseSheet>
    with WidgetsBindingObserver {
  static const _presets = <int, String>{
    5000: '5 000 ₸',
    10000: '10 000 ₸',
    20000: '20 000 ₸',
    50000: '50 000 ₸',
  };
  late final TextEditingController _amount;
  late final TextEditingController _recipient;
  late final TextEditingController _message;
  late final CardFlow _cards;
  String? _lastConfirmedCardId;

  CertificatePurchaseSession get _session => widget.session;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: _session.amountText);
    _recipient = TextEditingController(text: _session.recipientLogin);
    _message = TextEditingController(text: _session.message);
    _session.addListener(_changed);
    _cards = CardFlow(
      readCards: () => ApiService.getUserCards(source: 'halyk'),
      openForm: (uri, window) => openHostedCardForm(context, uri, window,
          openCardForm: widget.openCardForm),
      requiresWindow: kIsWeb && widget.openCardForm == null,
      reserveWindow: kIsWeb && widget.openCardForm == null
          ? () => reserveWebNamedWindow(cardFormWindowName)
          : null,
      closeWindow: closeReservedWebWindow,
    )..addListener(_cardsChanged);
    WidgetsBinding.instance.addObserver(this);
    if (!_session.completed) _cards.refresh();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _cardsChanged() {
    if (!mounted) return;
    if (!_cards.loading && _cards.error == null && _session.canPurchase) {
      final newId = _cards.newCardId;
      if (newId != null && newId != _lastConfirmedCardId) {
        _lastConfirmedCardId = newId;
        _session.selectedCardId = newId;
      } else if (!_cards.cards.any((card) =>
          card.canCharge && card.chargeId == _session.selectedCardId)) {
        _session.selectedCardId = null;
        for (final card in _cards.cards) {
          if (card.canCharge) {
            _session.selectedCardId = card.chargeId;
            break;
          }
        }
      }
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_session.completed) _cards.refresh();
      if (_session.unconfirmed) _session.refreshStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session.removeListener(_changed);
    _cards.removeListener(_cardsChanged);
    _cards.dispose();
    _amount.dispose();
    _recipient.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _session.canPurchase &&
      !_cards.loading &&
      !_cards.preparing &&
      !_cards.awaiting &&
      _cards.error == null &&
      _cards.cards.any((card) =>
          card.canCharge && card.chargeId == _session.selectedCardId);

  void _close() {
    if (_session.busy) return;
    Navigator.of(context).pop(_session.certificate);
  }

  Future<void> _purchase() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    await _session.purchase();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final editable = _session.canPurchase;
    final selectedAmount = CertificatePurchaseSession.parseAmount(_amount.text);
    return PopScope(
      canPop: !_session.busy,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: AppSpacing.touchTarget,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.textSecondary,
                      borderRadius: AppRadii.pillAll,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 8,
                    bottom: 0,
                    child: IconButton(
                      key: const ValueKey('certificate-purchase-close'),
                      tooltip: 'Закрыть',
                      onPressed: _session.busy ? null : _close,
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('certificate-purchase-scroll'),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 7, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _session.completed
                          ? 'Сертификат выпущен'
                          : 'Купить сертификат',
                      style: AppTypography.headline,
                    ),
                    const SizedBox(height: AppSpacing.huge),
                    if (_session.completed)
                      _completedView()
                    else ...[
                      TextField(
                        key: const ValueKey('certificate-purchase-amount'),
                        controller: _amount,
                        enabled: editable,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textInputAction: TextInputAction.next,
                        style: AppTypography.titleRegular,
                        decoration: _fieldDecoration('Сумма', filled: true)
                            .copyWith(suffixText: '₸'),
                        onChanged: (value) {
                          _session.amountText = value;
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final amount in _presets.keys)
                            OutlinedButton(
                              key: ValueKey('certificate-preset-$amount'),
                              onPressed: editable
                                  ? () => setState(() {
                                        _amount.text = '$amount';
                                        _session.amountText = '$amount';
                                      })
                                  : null,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 44),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                shape: const StadiumBorder(),
                                textStyle: AppTypography.body,
                                side: BorderSide(
                                    color: selectedAmount == amount
                                        ? palette.accent
                                        : palette.divider),
                              ),
                              child: Text(_presets[amount]!),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _cardSection(),
                      const SizedBox(height: AppSpacing.huge),
                      TextField(
                        key: const ValueKey('certificate-purchase-recipient'),
                        controller: _recipient,
                        enabled: editable,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        decoration:
                            _fieldDecoration('Телефон получателя, если дарите'),
                        onChanged: (value) => _session.recipientLogin = value,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      TextField(
                        key: const ValueKey('certificate-purchase-message'),
                        controller: _message,
                        enabled: editable,
                        minLines: 3,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        decoration: _fieldDecoration('Сообщение'),
                        onChanged: (value) => _session.message = value,
                      ),
                      if (_session.unconfirmed) ...[
                        const SizedBox(height: AppSpacing.huge),
                        _pendingView(),
                      ],
                      if (_session.error != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _session.error!,
                            key: const ValueKey('certificate-purchase-error'),
                            style: AppTypography.body
                                .copyWith(color: palette.error),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.huge),
                      if (!_session.unconfirmed)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            key: const ValueKey('certificate-purchase-submit'),
                            onPressed: _canSubmit ? _purchase : null,
                            style: FilledButton.styleFrom(
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              minimumSize: const Size(44, 49),
                            ),
                            child: Text(_session.busy ? 'Покупаем…' : 'Купить'),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardSection() {
    final palette = context.palette;
    final editable = _session.canPurchase;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_cards.loading) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (_cards.error != null || _cards.partialWarning != null) ...[
          KeyedSubtree(
            key: ValueKey(_cards.error == null
                ? 'certificate-cards-partial'
                : 'certificate-cards-error'),
            child: CardReadFeedback(flow: _cards, allowSignIn: editable),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (!_cards.loading && _cards.error == null &&
            _cards.partialWarning == null &&
            _cards.cards.isEmpty)
          Text(
            'Сохранённых Halyk карт нет',
            key: const ValueKey('certificate-cards-empty'),
            style:
                AppTypography.bodySmall.copyWith(color: palette.textSecondary),
          ),
        if (_cards.cards.isNotEmpty) ...[
          Text('Карта для оплаты', style: AppTypography.bodyBold),
          const SizedBox(height: AppSpacing.md),
          for (final card in _cards.cards)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: SavedCardRow(
                key: ValueKey('certificate-card-${card.rowKey}'),
                card: card,
                selected: card.canCharge &&
                    card.chargeId == _session.selectedCardId,
                onSelected: card.canCharge && editable &&
                        _cards.error == null && !_cards.loading &&
                        !_cards.preparing && !_cards.awaiting
                    ? () => setState(
                        () => _session.selectedCardId = card.chargeId)
                    : null,
              ),
            ),
        ],
        if (editable) ...[
          if (_cards.message != null) ...[
            const SizedBox(height: AppSpacing.md),
            CardFlowFeedback(flow: _cards),
          ],
          Wrap(
            spacing: AppSpacing.xl,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                key: const ValueKey('certificate-add-card'),
                onPressed: _cards.canAdd ? _cards.addCard : null,
                icon: const Icon(Icons.add, size: 20),
                label: Text(_cards.preparing
                    ? 'Открываем банк…'
                    : _cards.addState == CardAddState.launchFailed
                        ? 'Открыть форму снова'
                        : 'Добавить карту'),
              ),
              if (!_cards.awaiting)
                TextButton.icon(
                  key: const ValueKey('certificate-refresh-cards'),
                  onPressed: _cards.preparing ? null : _cards.refresh,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: Text(_cards.error == null ? 'Обновить' : 'Повторить'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _pendingView() {
    final palette = context.palette;
    final id = _session.purchaseId;
    return AppSurface(
      fill: palette.accentFaint,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Оплата не подтверждена',
              key: const ValueKey('certificate-purchase-pending'),
              style: AppTypography.title),
          const SizedBox(height: AppSpacing.md),
          Text(
            id == null
                ? 'Не удалось получить номер покупки. Не оплачивайте повторно: проверьте сертификаты или обратитесь в поддержку.'
                : 'Покупка $id. Проверьте статус оплаты — повторного списания не будет.',
            style: AppTypography.body,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (id != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('certificate-refresh-status'),
                onPressed: _session.busy ? null : _session.refreshStatus,
                child: Text(
                    _session.busy ? 'Проверяем…' : 'Проверить статус оплаты'),
              ),
            )
          else
            TextButton(
              key: const ValueKey('certificate-return-to-list'),
              onPressed: _close,
              child: const Text('Вернуться к сертификатам'),
            ),
        ],
      ),
    );
  }

  Widget _completedView() {
    final palette = context.palette;
    final certificate = _session.certificate!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Оплата подтверждена',
            style: AppTypography.body.copyWith(color: palette.success)),
        const SizedBox(height: AppSpacing.xl),
        SelectableText(
          certificate['code'] as String,
          key: const ValueKey('certificate-issued-code'),
          style: AppTypography.headline.copyWith(color: palette.accent),
        ),
        const SizedBox(height: AppSpacing.huge),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('certificate-purchase-done'),
            onPressed: _close,
            child: const Text('К сертификатам'),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint, {bool filled = false}) {
    final palette = context.palette;
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.bodyLight.copyWith(color: palette.textSecondary),
      filled: true,
      fillColor: filled ? palette.background : palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppRadii.lgAll,
        borderSide: BorderSide(color: palette.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadii.lgAll,
        borderSide: BorderSide(color: palette.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadii.lgAll,
        borderSide: BorderSide(color: palette.accent),
      ),
    );
  }
}
