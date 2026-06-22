import 'package:flutter/material.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';
import 'package:naliv_delivery/utils/responsive.dart';

class CertificatesPage extends StatefulWidget {
  const CertificatesPage({super.key});

  @override
  State<CertificatesPage> createState() => _CertificatesPageState();
}

class _CertificatesPageState extends State<CertificatesPage> {
  static const List<String> _statuses = <String>[
    'active',
    'redeemed',
    'canceled',
  ];

  final TextEditingController _claimCodeController = TextEditingController();
  String _selectedStatus = 'active';
  List<Map<String, dynamic>> _certificates = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  @override
  void dispose() {
    _claimCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadCertificates() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final result = await ApiService.getCertificates(status: _selectedStatus);
    if (!mounted) return;

    if (result['success'] == true) {
      final data = ApiService.mapFromDynamic(result['data']);
      setState(() {
        _certificates = ApiService.mapListFromDynamic(data['certificates']);
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = false);
    await _showNotice(
      'Сертификаты не загружены',
      _messageFromResult(result, 'Попробуйте еще раз.'),
    );
  }

  Future<void> _claimCertificate() async {
    final code = _claimCodeController.text.trim();
    if (code.isEmpty) {
      await _showNotice('Сертификат', 'Введите код сертификата.');
      return;
    }

    setState(() => _isClaiming = true);
    final result = await ApiService.claimCertificate(code);
    if (!mounted) return;
    setState(() => _isClaiming = false);

    if (result['success'] == true) {
      _claimCodeController.clear();
      await _loadCertificates();
      if (!mounted) return;
      await _showNotice(
          'Сертификат активирован', 'Сертификат добавлен в ваш список.');
      return;
    }

    await _showNotice(
      'Не удалось активировать',
      _messageFromResult(result, 'Проверьте код сертификата.'),
    );
  }

  Future<void> _openPurchaseSheet() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.s)),
      ),
      builder: (_) => const _CertificatePurchaseSheet(),
    );

    if (!mounted || result == null) return;
    await _handlePurchaseResult(result);
  }

  Future<void> _handlePurchaseResult(Map<String, dynamic> result) async {
    if (result['success'] != true) {
      await _showNotice(
        'Покупка не выполнена',
        _messageFromResult(result, 'Попробуйте еще раз.'),
      );
      return;
    }

    final data = ApiService.mapFromDynamic(result['data']);
    final status = data['payment_status']?.toString();

    if (status == 'completed') {
      await _loadCertificates();
      if (!mounted) return;
      final certificate = ApiService.mapFromDynamic(data['certificate']);
      final code = certificate['code']?.toString();
      await _showNotice(
        'Сертификат выпущен',
        code == null || code.isEmpty
            ? 'Сертификат добавлен в ваш список.'
            : 'Код: $code',
      );
      return;
    }

    await _showNotice(
      'Покупка не завершена',
      'Оплата картой не была подтверждена. Попробуйте еще раз.',
    );
  }

  Future<void> _showDetails(Map<String, dynamic> certificate) async {
    final id = _certificateIdOf(certificate);
    if (id == null) return;

    final result = await ApiService.getCertificateDetails(id);
    if (!mounted) return;
    if (result['success'] != true) {
      await _showNotice(
        'Детали не загружены',
        _messageFromResult(result, 'Попробуйте еще раз.'),
      );
      return;
    }

    final data = ApiService.mapFromDynamic(result['data']);
    final detailedCertificate =
        ApiService.mapFromDynamic(data['certificate']).isEmpty
            ? certificate
            : ApiService.mapFromDynamic(data['certificate']);
    final transactions = ApiService.mapListFromDynamic(data['transactions']);

    if (!mounted) return;
    await AppDialogs.show<void>(
      context,
      title: 'Сертификат',
      content: _CertificateDetailsDialogContent(
        certificate: detailedCertificate,
        transactions: transactions,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child:
              const Text('Закрыть', style: TextStyle(color: AppColors.orange)),
        ),
      ],
    );
  }

  Future<void> _showGiftSheet(Map<String, dynamic> certificate) async {
    final id = _certificateIdOf(certificate);
    if (id == null) return;

    final gifted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.s)),
      ),
      builder: (_) => _GiftCertificateSheet(certificateId: id),
    );

    if (!mounted || gifted != true) return;
    await _loadCertificates();
    if (!mounted) return;
    await _showNotice(
      'Сертификат отправлен',
      'Он исчезнет из вашего списка и появится у получателя.',
    );
  }

  String _messageFromResult(
    Map<String, dynamic> result,
    String fallback,
  ) {
    final error = result['error'];
    if (error is Map) {
      return error['message']?.toString() ?? fallback;
    }
    final message = error?.toString() ?? result['message']?.toString();
    return message == null || message.isEmpty ? fallback : message;
  }

  Future<void> _showNotice(String title, String message) {
    return AppDialogs.showMessage(context, title: title, message: message);
  }

  int? _certificateIdOf(Map<String, dynamic> certificate) {
    final raw = certificate['certificate_id'] ?? certificate['id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(
          value?.toString().replaceAll(' ', '').replaceAll(',', '.') ?? '',
        ) ??
        0;
  }

  bool _canGift(Map<String, dynamic> certificate) {
    return certificate['status']?.toString() == 'active' &&
        _asDouble(certificate['balance']) > 0 &&
        certificate['is_expired'] != true;
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Активные';
      case 'redeemed':
        return 'Использованные';
      case 'canceled':
        return 'Отмененные';
      default:
        return status;
    }
  }

  static String _money(num value) => '${value.toStringAsFixed(0)} ₸';

  String _dateText(dynamic raw) {
    if (raw == null) return 'без срока';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return raw.toString();
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: const Text('Сертификаты',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _isLoading ? null : _loadCertificates,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: RefreshIndicator(
              color: AppColors.orange,
              backgroundColor: AppColors.card,
              onRefresh: _loadCertificates,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.s, 10.s, 16.s, 110.s),
                children: [
                  _claimSection(),
                  SizedBox(height: 12.s),
                  _purchaseSection(),
                  SizedBox(height: 18.s),
                  _statusFilters(),
                  SizedBox(height: 12.s),
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.only(top: 42.s),
                      child: const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.orange),
                      ),
                    )
                  else if (_certificates.isEmpty)
                    _emptyState()
                  else
                    ..._certificates.map(_certificateCard),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _claimSection() {
    return Container(
      padding: EdgeInsets.all(14.s),
      decoration: AppDecorations.card(
        radius: 18,
        color: AppColors.cardDark.withValues(alpha: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Активировать по коду',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 10.s),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _claimCodeController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700),
                  decoration: _fieldDecoration('NALIV-ABCD-2345-EFGH'),
                ),
              ),
              SizedBox(width: 8.s),
              SizedBox(
                height: 44.s,
                child: TextButton(
                  onPressed: _isClaiming ? null : _claimCertificate,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 13.s),
                  ),
                  child: Text(_isClaiming ? '...' : 'ОК',
                      style: TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 12.sp)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _purchaseSection() {
    return GestureDetector(
      onTap: _openPurchaseSheet,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(14.s),
        decoration: AppDecorations.card(
          radius: 18,
          color: AppColors.blue.withValues(alpha: 0.72),
        ),
        child: Row(
          children: [
            Container(
              width: 42.s,
              height: 42.s,
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(14.s),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.card_giftcard_rounded,
                  color: Colors.black, size: 21.s),
            ),
            SizedBox(width: 12.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Купить сертификат',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w900)),
                  SizedBox(height: 2.s),
                  Text('Оплата сохраненной Halyk картой',
                      style: TextStyle(
                          color: AppColors.textMute,
                          fontSize: 12.sp,
                          height: 1.3)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.textMute, size: 22.s),
          ],
        ),
      ),
    );
  }

  Widget _statusFilters() {
    return Row(
      children: _statuses.map((status) {
        final active = _selectedStatus == status;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: status == _statuses.last ? 0 : 7.s,
            ),
            child: GestureDetector(
              onTap: active
                  ? null
                  : () {
                      setState(() => _selectedStatus = status);
                      _loadCertificates();
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(vertical: 10.s),
                decoration: BoxDecoration(
                  color: active ? AppColors.orange : AppColors.card,
                  borderRadius: BorderRadius.circular(14.s),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _statusLabel(status),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? Colors.black : AppColors.text,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.s, vertical: 32.s),
      decoration: AppDecorations.card(
        radius: 18,
        color: AppColors.cardDark.withValues(alpha: 0.78),
      ),
      child: Column(
        children: [
          Icon(Icons.card_giftcard_outlined,
              color: AppColors.textMute, size: 36.s),
          SizedBox(height: 12.s),
          Text('Сертификатов нет',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900)),
          SizedBox(height: 4.s),
          Text(
            'Активируйте код или купите новый сертификат.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMute, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _certificateCard(Map<String, dynamic> certificate) {
    final code = certificate['code']?.toString() ?? 'Сертификат';
    final balance = _asDouble(certificate['balance']);
    final initialAmount = _asDouble(certificate['initial_amount']);
    final message = certificate['message']?.toString().trim();
    final expiresAt = _dateText(certificate['expires_at']);
    final status = certificate['status']?.toString() ?? _selectedStatus;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.s),
      child: Container(
        padding: EdgeInsets.all(15.s),
        decoration: AppDecorations.card(
          radius: 18,
          color: AppColors.cardDark.withValues(alpha: 0.9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard_rounded,
                    color: AppColors.orange, size: 22.s),
                SizedBox(width: 10.s),
                Expanded(
                  child: Text(
                    code,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                _statusPill(status),
              ],
            ),
            SizedBox(height: 12.s),
            Row(
              children: [
                Expanded(
                  child: _metricTile('Баланс', _money(balance)),
                ),
                SizedBox(width: 8.s),
                Expanded(
                  child: _metricTile('Номинал', _money(initialAmount)),
                ),
              ],
            ),
            SizedBox(height: 10.s),
            Text('Срок: $expiresAt',
                style: TextStyle(
                    color: AppColors.textMute,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600)),
            if (message != null && message.isNotEmpty) ...[
              SizedBox(height: 6.s),
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12.sp,
                    height: 1.35,
                    fontWeight: FontWeight.w600),
              ),
            ],
            SizedBox(height: 12.s),
            Row(
              children: [
                Expanded(
                  child: _outlineButton(
                    icon: Icons.receipt_long_rounded,
                    label: 'Детали',
                    onTap: () => _showDetails(certificate),
                  ),
                ),
                if (_canGift(certificate)) ...[
                  SizedBox(width: 8.s),
                  Expanded(
                    child: _outlineButton(
                      icon: Icons.ios_share_rounded,
                      label: 'Подарить',
                      onTap: () => _showGiftSheet(certificate),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.s, vertical: 9.s),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12.s),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: AppColors.textMute, fontSize: 11.sp)),
          SizedBox(height: 2.s),
          Text(value,
              style: TextStyle(
                  color: AppColors.orange,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final active = status == 'active';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.s, vertical: 5.s),
      decoration: BoxDecoration(
        color: active
            ? Colors.greenAccent.withValues(alpha: 0.13)
            : AppColors.textMute.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'active' : status,
        style: TextStyle(
          color: active ? Colors.greenAccent : AppColors.textMute,
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40.s,
        decoration: BoxDecoration(
          color: AppColors.blue.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14.s),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.orange, size: 16.s),
            SizedBox(width: 7.s),
            Text(label,
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMute, fontSize: 12.sp),
      isDense: true,
      filled: true,
      fillColor: AppColors.card,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 12.s),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.s),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.s),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.s),
        borderSide: const BorderSide(color: AppColors.orange),
      ),
    );
  }
}

class _CertificatePurchaseSheet extends StatefulWidget {
  const _CertificatePurchaseSheet();

  @override
  State<_CertificatePurchaseSheet> createState() =>
      _CertificatePurchaseSheetState();
}

class _CertificatePurchaseSheetState extends State<_CertificatePurchaseSheet> {
  final TextEditingController _amountController =
      TextEditingController(text: '10000');
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  List<Map<String, dynamic>> _cards = <Map<String, dynamic>>[];
  String? _selectedCardId;
  String? _error;
  bool _isLoadingCards = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    final cards = await ApiService.getUserCards(source: 'halyk');
    if (!mounted) return;
    final normalized = cards ?? <Map<String, dynamic>>[];
    setState(() {
      _cards = normalized;
      _selectedCardId = normalized.isEmpty ? null : _cardIdOf(normalized.first);
      _isLoadingCards = false;
    });
  }

  Future<void> _submit() async {
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(' ', '').replaceAll(',', '.'),
    );
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Введите сумму сертификата.');
      return;
    }
    if (_selectedCardId == null) {
      setState(() => _error = 'Выберите сохраненную карту.');
      return;
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    final result = await ApiService.purchaseCertificate(
      amount: amount,
      paymentType: 'card',
      halykCardId: _selectedCardId,
      recipientLogin: _recipientController.text.trim(),
      message: _messageController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop(result);
  }

  String? _cardIdOf(Map<String, dynamic> card) {
    final id = card['halyk_id'] ?? card['card_id'] ?? card['id'];
    final normalized = id?.toString().trim();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized.toLowerCase() == 'null') {
      return null;
    }
    return normalized;
  }

  String _cardLabel(Map<String, dynamic> card) {
    final masked = card['masked_pan'] ??
        card['maskedPan'] ??
        card['pan_masked'] ??
        card['card_mask'] ??
        card['cardMask'];
    final title = masked?.toString();
    if (title != null && title.trim().isNotEmpty) return title;
    return 'Карта ${_cardIdOf(card) ?? ''}'.trim();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.s,
          right: 16.s,
          top: 16.s,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16.s,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42.s,
                  height: 4.s,
                  decoration: BoxDecoration(
                    color: AppColors.textMute.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: 18.s),
              Text('Купить сертификат',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900)),
              SizedBox(height: 14.s),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800),
                decoration: _fieldDecoration('Сумма'),
              ),
              SizedBox(height: 10.s),
              Wrap(
                spacing: 8.s,
                runSpacing: 8.s,
                children: const [5000, 10000, 20000, 50000]
                    .map((amount) => _amountChip(amount))
                    .toList(growable: false),
              ),
              SizedBox(height: 14.s),
              if (_isLoadingCards)
                const LinearProgressIndicator(color: AppColors.orange)
              else if (_cards.isEmpty)
                Text('Сохраненных Halyk карт нет',
                    style:
                        TextStyle(color: AppColors.textMute, fontSize: 12.sp))
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedCardId,
                  dropdownColor: AppColors.card,
                  decoration: _fieldDecoration('Карта'),
                  iconEnabledColor: AppColors.orange,
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700),
                  items: _cards
                      .map((card) => DropdownMenuItem<String>(
                            value: _cardIdOf(card),
                            child: Text(_cardLabel(card)),
                          ))
                      .where((item) => item.value != null)
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _selectedCardId = value),
                ),
              SizedBox(height: 12.s),
              TextField(
                controller: _recipientController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.text),
                decoration: _fieldDecoration('Телефон получателя, если дарите'),
              ),
              SizedBox(height: 10.s),
              TextField(
                controller: _messageController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.text),
                decoration: _fieldDecoration('Сообщение'),
              ),
              if (_error != null) ...[
                SizedBox(height: 10.s),
                Text(_error!,
                    style: TextStyle(color: AppColors.red, fontSize: 12.sp)),
              ],
              SizedBox(height: 16.s),
              SizedBox(
                width: double.infinity,
                height: 48.s,
                child: TextButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(_isSubmitting ? 'Покупаем...' : 'Купить',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountChip(int amount) {
    return GestureDetector(
      onTap: () => setState(() => _amountController.text = amount.toString()),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 8.s),
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(12.s),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text('$amount ₸',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 12.sp,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMute, fontSize: 12.sp),
      isDense: true,
      filled: true,
      fillColor: AppColors.cardDark,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 12.s),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.s),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.s),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.s),
        borderSide: const BorderSide(color: AppColors.orange),
      ),
    );
  }
}

class _GiftCertificateSheet extends StatefulWidget {
  final int certificateId;

  const _GiftCertificateSheet({required this.certificateId});

  @override
  State<_GiftCertificateSheet> createState() => _GiftCertificateSheetState();
}

class _GiftCertificateSheetState extends State<_GiftCertificateSheet> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_recipientController.text.trim().isEmpty) {
      setState(() => _error = 'Введите телефон или логин получателя.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final result = await ApiService.giftCertificate(
      certificateId: widget.certificateId,
      recipientLogin: _recipientController.text.trim(),
      message: _messageController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      Navigator.of(context).pop(true);
      return;
    }

    final error = result['error'];
    setState(() {
      _error = error is Map
          ? error['message']?.toString()
          : error?.toString() ?? 'Не удалось подарить сертификат.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16.s,
          right: 16.s,
          top: 16.s,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 16.s,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42.s,
                height: 4.s,
                decoration: BoxDecoration(
                  color: AppColors.textMute.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            SizedBox(height: 18.s),
            Text('Подарить сертификат',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 14.s),
            TextField(
              controller: _recipientController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: AppColors.text),
              decoration: _fieldDecoration('Телефон или логин получателя'),
            ),
            SizedBox(height: 10.s),
            TextField(
              controller: _messageController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.text),
              decoration: _fieldDecoration('Сообщение'),
            ),
            if (_error != null) ...[
              SizedBox(height: 10.s),
              Text(_error!,
                  style: TextStyle(color: AppColors.red, fontSize: 12.sp)),
            ],
            SizedBox(height: 16.s),
            SizedBox(
              width: double.infinity,
              height: 48.s,
              child: TextButton(
                onPressed: _isSubmitting ? null : _submit,
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.black,
                ),
                child: Text(_isSubmitting ? 'Отправляем...' : 'Подарить',
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textMute, fontSize: 12.sp),
      isDense: true,
      filled: true,
      fillColor: AppColors.cardDark,
      contentPadding: EdgeInsets.symmetric(horizontal: 12.s, vertical: 12.s),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.s),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.s),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.s),
        borderSide: const BorderSide(color: AppColors.orange),
      ),
    );
  }
}

class _CertificateDetailsDialogContent extends StatelessWidget {
  final Map<String, dynamic> certificate;
  final List<Map<String, dynamic>> transactions;

  const _CertificateDetailsDialogContent({
    required this.certificate,
    required this.transactions,
  });

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(num value) => '${value.toStringAsFixed(0)} ₸';

  String _dateText(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return raw?.toString() ?? '';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final code = certificate['code']?.toString() ?? '';
    final balance = _asDouble(certificate['balance']);
    final initial = _asDouble(certificate['initial_amount']);

    return SizedBox(
      width: double.maxFinite,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              code,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 10.s),
            Text('Баланс: ${_money(balance)}',
                style: const TextStyle(color: AppColors.text)),
            Text('Номинал: ${_money(initial)}',
                style: const TextStyle(color: AppColors.textMute)),
            SizedBox(height: 14.s),
            Text('Операции',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900)),
            SizedBox(height: 8.s),
            if (transactions.isEmpty)
              const Text('Операций пока нет',
                  style: TextStyle(color: AppColors.textMute))
            else
              ...transactions.map((transaction) {
                final type = transaction['type']?.toString() ?? 'operation';
                final amount = _asDouble(transaction['amount']);
                final comment = transaction['comment']?.toString();
                return Padding(
                  padding: EdgeInsets.only(bottom: 10.s),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$type · ${_money(amount)}',
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 2.s),
                      Text(_dateText(transaction['created_at']),
                          style: const TextStyle(
                              color: AppColors.textMute, fontSize: 12)),
                      if (comment != null && comment.trim().isNotEmpty)
                        Text(comment,
                            style: const TextStyle(
                                color: AppColors.textMute, fontSize: 12)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
