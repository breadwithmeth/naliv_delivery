import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../design/theme.dart';
import '../../../ui/app_states.dart';
import '../../../design/tokens.dart';
import '../../../design/typography.dart';
import '../../../ui/app_cart_button.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/app_top_bar.dart';
import '../../../utils/api.dart';
import '../../../utils/cart_provider.dart';
import '../certificate_purchase_session.dart';
import 'certificate_purchase_sheet.dart';

/// Certificates — the design's `Сертификаты` frames.
///
/// Geometry: the standard top bar, «Активировать по коду» 16/700 at y = 151 with a 45 px row
/// beneath it (246 px code field + an 85 px «Ок» button, 12 px apart), a 343 × 60 «Купить
/// сертификат» row at y = 253, a 343 × 38 filter bar at y = 337 (a 91 × 34 selected pill inside
/// it) and 343 × 71 certificate rows. The empty state is centred at y = 517.
///
/// Certificate rows show the name 20/700 in the accent with the amount 16/500 and a state line
/// beneath it — green for active, muted for redeemed, error for cancelled.
///
/// The status values (`active` / `redeemed` / `canceled`) are the app's own; the design only
/// names the three tabs.
///
/// Purchases use the supported saved-card flow. Verification must use fixtures.
class CertificatesPage extends StatefulWidget {
  const CertificatesPage(
      {this.onBuy, this.onCart, this.openCardForm, super.key});

  /// An explicit override for the default themed purchase action.
  final VoidCallback? onBuy;
  final Future<bool> Function(Uri)? openCardForm;
  final VoidCallback? onCart;

  @override
  State<CertificatesPage> createState() => _CertificatesPageState();
}

class _CertificatesPageState extends State<CertificatesPage> {
  static const _statuses = <String>['active', 'redeemed', 'canceled'];
  static const _statusLabels = <String, String>{
    'active': 'Активные',
    'redeemed': 'Использованные',
    'canceled': 'Отменённые',
  };

  final _code = TextEditingController();
  CertificatePurchaseSession _purchase = CertificatePurchaseSession();
  bool _purchaseOpen = false;
  String _status = 'active';
  List<Map<String, dynamic>>? _certificates;
  String? _error;
  String? _claimError;
  int _requestId = 0;
  bool _claiming = false;
  bool _hasMore = false;
  bool _loadingMore = false;
  String? _moreError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _purchase.dispose();
    super.dispose();
  }

  Future<void> _load({bool append = false}) async {
    if (append && _loadingMore) return;
    final requestId = ++_requestId;
    final status = _status;
    final offset = append ? _certificates?.length ?? 0 : 0;
    setState(() {
      _error = null;
      _moreError = null;
      _loadingMore = append;
      if (!append) _certificates = null;
    });
    try {
      final response = await ApiService.getCertificates(
        status: status,
        limit: 50,
        offset: offset,
      );
      final data = response['data'];
      final list = data is Map ? data['certificates'] : null;
      if (response['success'] != true || list is! List) {
        throw StateError(
            _message(response, 'Не удалось загрузить сертификаты'));
      }
      final certificates = <Map<String, dynamic>>[
        for (final entry in list)
          if (entry is Map)
            Map<String, dynamic>.from(entry)
          else
            throw const FormatException('Invalid certificate'),
      ];
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _certificates =
            append ? [...?_certificates, ...certificates] : certificates;
        _hasMore = certificates.length == 50;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        final message = error is StateError
            ? error.message.toString()
            : 'Не удалось загрузить сертификаты';
        if (append) {
          _moreError = message;
        } else {
          _error = message;
        }
      });
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loadingMore = false);
      }
    }
  }

  String _message(Map<String, dynamic> response, String fallback) {
    final message = response['error'] ?? response['message'];
    return message is String && message.trim().isNotEmpty ? message : fallback;
  }

  Future<void> _claim() async {
    final code = _code.text.trim();
    if (code.isEmpty || _claiming) return;
    setState(() {
      _claiming = true;
      _claimError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final response = await ApiService.claimCertificate(code);
      if (response['success'] != true) {
        if (mounted) {
          setState(() => _claimError =
              _message(response, 'Не удалось активировать сертификат'));
        }
        return;
      }
      if (!mounted) return;
      _code.clear();
      setState(() => _status = 'active');
      messenger.showSnackBar(
          const SnackBar(content: Text('Сертификат активирован')));
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _claimError = 'Не удалось активировать сертификат');
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  Future<void> _buy() async {
    final override = widget.onBuy;
    if (override != null) {
      override();
      return;
    }
    if (_purchaseOpen) return;
    _purchaseOpen = true;
    try {
      await showCertificatePurchase(
        context,
        session: _purchase,
        openCardForm: widget.openCardForm,
      );
      if (!mounted) return;
      if (_purchase.completed) {
        _purchase.dispose();
        _purchase = CertificatePurchaseSession();
        setState(() => _status = 'active');
        await _load();
      } else if (_purchase.unconfirmed) {
        await _load();
      }
    } finally {
      _purchaseOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cart = context.watch<CartProvider>();
    final count = cart.displayItemCount;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Stack(
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xxxl),
                      child: AppTopBar(
                        title: 'Сертификаты',
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.huge),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.only(
                          bottom: AppCartButton.clearanceFor(context) +
                              MediaQuery.paddingOf(context).bottom,
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxxl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Активировать по коду',
                                  style: AppTypography.title
                                      .copyWith(color: palette.textPrimary),
                                ),
                                const SizedBox(height: AppSpacing.xl),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 45,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xxl),
                                        decoration: BoxDecoration(
                                          color: palette.surface
                                              .withValues(alpha: 0.75),
                                          borderRadius: BorderRadius.circular(
                                              AppRadii.lg),
                                        ),
                                        child: Center(
                                          child: TextField(
                                            controller: _code,
                                            textCapitalization:
                                                TextCapitalization.characters,
                                            enabled: !_claiming,
                                            onChanged: (_) {
                                              if (_claimError != null) {
                                                setState(
                                                    () => _claimError = null);
                                              }
                                            },
                                            onSubmitted: (_) => _claim(),
                                            cursorColor: palette.accent,
                                            style: AppTypography.base(
                                                    size: 16, weight: 300)
                                                .copyWith(
                                                    color: palette.textPrimary),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              filled: false,
                                              border: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                              hintText: 'AAAA-AAAA-AAAA-AAAA',
                                              hintStyle: AppTypography.base(
                                                      size: 16, weight: 300)
                                                  .copyWith(
                                                      color: palette
                                                          .textSecondary),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xl),
                                    ValueListenableBuilder<TextEditingValue>(
                                      valueListenable: _code,
                                      builder: (context, value, _) => SizedBox(
                                        width: 85,
                                        height: 48,
                                        child: FilledButton(
                                          onPressed: _claiming ||
                                                  value.text.trim().isEmpty
                                              ? null
                                              : _claim,
                                          child: _claiming
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                )
                                              : const Text('Ок'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_claimError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: AppSpacing.md),
                                    child: Text(
                                      _claimError!,
                                      key: const ValueKey(
                                          'certificate-claim-error'),
                                      style: AppTypography.bodySmall
                                          .copyWith(color: palette.error),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.huge),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxxl),
                            child: _BuyRow(onTap: _buy),
                          ),
                          const SizedBox(height: AppSpacing.huge),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xxxl),
                            child: _StatusTabs(
                              statuses: _statuses,
                              labels: _statusLabels,
                              selected: _status,
                              onSelect: (status) {
                                if (status == _status) return;
                                setState(() => _status = status);
                                _load();
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpacing.huge),
                          ..._body(palette),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
                  child: Center(
                    child: AppCartButton(
                      itemCount: count,
                      total: count == 0 ? null : cart.getTotalPrice().round(),
                      onTap: widget.onCart,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(AppPalette palette) {
    if (_error != null) {
      return [
        AppErrorState(
          message: _error!,
          onRetry: _load,
        ),
      ];
    }
    final certificates = _certificates;
    if (certificates == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.huge),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (certificates.isEmpty) {
      return const [
        AppEmptyState(
          title: 'Сертификатов нет',
          subtitle: 'Активируйте код или купите новый сертификат',
          topOffset: 88,
        ),
      ];
    }
    return [
      for (final certificate in certificates)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxxl,
            0,
            AppSpacing.xxxl,
            AppSpacing.md,
          ),
          child: _CertificateRow(certificate: certificate, status: _status),
        ),
      if (_hasMore || _moreError != null)
        Center(
          child: TextButton(
            onPressed: _loadingMore ? null : () => _load(append: true),
            child: Text(_loadingMore
                ? 'Загрузка…'
                : _moreError != null
                    ? 'Повторить загрузку'
                    : 'Показать ещё'),
          ),
        ),
    ];
  }
}

/// 343 × 60 — «Купить сертификат» with its subtitle.
class _BuyRow extends StatelessWidget {
  const _BuyRow({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('certificate-buy'),
        onTap: onTap,
        borderRadius: AppRadii.lgAll,
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(
            children: [
              AppIcon(AppIcons.certificates, size: 24, color: palette.accent),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Купить сертификат',
                      style: AppTypography.titleMedium
                          .copyWith(color: palette.textPrimary),
                    ),
                    Text(
                      'Оплата сохранённой Halyk картой',
                      style: AppTypography.label
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 24, color: palette.textPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

/// 343 × 38 filter bar with a 91 × 34 selected pill inset 2 px.
class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.statuses,
    required this.labels,
    required this.selected,
    this.onSelect,
  });

  final List<String> statuses;
  final Map<String, String> labels;
  final String selected;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final status in statuses)
                  Semantics(
                    selected: status == selected,
                    child: TextButton(
                      onPressed:
                          onSelect == null ? null : () => onSelect!(status),
                      style: TextButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        backgroundColor:
                            status == selected ? palette.accentSoft : null,
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        labels[status] ?? status,
                        maxLines: 1,
                        style: AppTypography.body,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 343 × 71 — name in the accent, amount and state on the right.
class _CertificateRow extends StatelessWidget {
  const _CertificateRow({required this.certificate, required this.status});

  final Map<String, dynamic> certificate;
  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final amount = _amount();
    return Container(
      constraints: const BoxConstraints(minHeight: 71),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              _name(),
              maxLines: 2,
              style: AppTypography.base(size: 20, weight: 700)
                  .copyWith(color: palette.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (amount != null)
                Text(
                  '$amount ₸',
                  style: AppTypography.titleMedium
                      .copyWith(color: palette.textPrimary),
                ),
              Text(
                _stateLine(),
                style:
                    AppTypography.label.copyWith(color: _stateColor(palette)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _name() {
    for (final key in const ['name', 'title', 'code', 'certificate_code']) {
      final value = certificate[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return 'Сертификат';
  }

  int? _amount() {
    final raw = certificate['balance'] ?? certificate['initial_amount'];
    final amount = raw is num ? raw.toDouble() : double.tryParse('$raw');
    return amount != null && amount.isFinite && amount >= 0
        ? amount.round()
        : null;
  }

  String _stateLine() {
    switch (status) {
      case 'redeemed':
        return 'Использован';
      case 'canceled':
        return 'Отменён';
      default:
        final raw = certificate['expires_at'] ??
            certificate['valid_until'] ??
            certificate['expiration_date'];
        final date = raw == null ? null : DateTime.tryParse(raw.toString());
        if (date == null) return 'Активен';
        return 'Активен до ${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
  }

  Color _stateColor(AppPalette palette) {
    switch (status) {
      case 'redeemed':
        return palette.textSecondary;
      case 'canceled':
        return palette.error;
      default:
        return palette.success;
    }
  }
}
