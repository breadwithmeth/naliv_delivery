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
/// **Purchasing is bridged, never executed.** «Купить сертификат» opens the legacy purchase flow;
/// it involves a real payment, so no verification run may submit it.
class CertificatesPage extends StatefulWidget {
  const CertificatesPage({this.onBuy, this.onCart, super.key});

  /// Opens the (legacy) purchase flow.
  final VoidCallback? onBuy;
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
  String _status = 'active';
  List<Map<String, dynamic>>? _certificates;
  bool _failed = false;
  bool _claiming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _failed = false;
      _certificates = null;
    });
    try {
      final response = await ApiService.getCertificates(status: _status);
      final data = response['data'];
      final list = data is Map ? data['certificates'] : null;
      if (!mounted) return;
      setState(() {
        _certificates = [
          if (list is List)
            for (final entry in list)
              if (entry is Map) entry.cast<String, dynamic>(),
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _claim() async {
    final code = _code.text.trim();
    if (code.isEmpty || _claiming) return;
    setState(() => _claiming = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.claimCertificate(code);
      if (!mounted) return;
      _code.clear();
      messenger.showSnackBar(
          const SnackBar(content: Text('Сертификат активирован')));
      await _load();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Не удалось активировать сертификат')),
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
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
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
                  child: AppTopBar(
                    title: 'Сертификаты',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(height: AppSpacing.huge),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: AppCartButton.clearance +
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
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.lg),
                                    ),
                                    child: Center(
                                      child: TextField(
                                        controller: _code,
                                        textCapitalization:
                                            TextCapitalization.characters,
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
                                                  color: palette.textSecondary),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xl),
                                GestureDetector(
                                  onTap: _claiming ? null : _claim,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: 85,
                                    height: 45,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: palette.accentSoft,
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.lg),
                                    ),
                                    child: Text(
                                      _claiming ? '...' : 'Ок',
                                      style: AppTypography.titleMedium
                                          .copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.huge),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxxl),
                        child: _BuyRow(onTap: widget.onBuy),
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
    );
  }

  List<Widget> _body(AppPalette palette) {
    if (_failed) {
      return [
        AppErrorState(
          message: 'Не удалось загрузить сертификаты',
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            const AppIcon(AppIcons.certificates, size: 24, color: Colors.white),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Column(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    return Container(
      height: 38,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final status in statuses)
            GestureDetector(
              onTap: onSelect == null ? null : () => onSelect!(status),
              behavior: HitTestBehavior.opaque,
              // Content-sized, as the frame shows: the selected pill is 91 px for «Активные»
              // and the long label never truncates.
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: status == selected ? palette.accentSoft : null,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  labels[status] ?? status,
                  maxLines: 1,
                  style:
                      AppTypography.body.copyWith(color: palette.textPrimary),
                ),
              ),
            ),
        ],
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
      height: 71,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _name(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.base(size: 20, weight: 700)
                  .copyWith(color: palette.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
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

  /// The payload's amount key is not part of the documented contract, so several are tried.
  int? _amount() {
    for (final key in const [
      'amount',
      'balance',
      'value',
      'denomination',
      'face_value'
    ]) {
      final value = certificate[key];
      if (value is num && value > 0) return value.toInt();
    }
    return null;
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
