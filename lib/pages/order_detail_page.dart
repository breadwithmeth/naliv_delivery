import 'package:flutter/material.dart';
import 'package:naliv_delivery/shared/app_theme.dart';

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Map<String, dynamic>? _orderDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() {
        _orderDetails = widget.order;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки деталей заказа: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = '#${widget.order['order_id'] ?? '-'}';
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.text,
        title: Text('Заказ $title', style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.orange)),
            )
          else if (_error != null)
            _buildErrorState()
          else if (_orderDetails != null)
            _buildOrderDetails()
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.red, size: 48),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadOrderDetails,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange, foregroundColor: Colors.black),
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    final order = _orderDetails!;
    final business = order['business'] as Map<String, dynamic>?;
    final deliveryAddress = order['delivery_address'] as Map<String, dynamic>?;
    final itemsSummary = order['items_summary'] as Map<String, dynamic>?;
    final costSummary = order['cost_summary'] as Map<String, dynamic>?;
    final statuses = (order['order_statuses'] as List<dynamic>?) ?? [];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _statusCard(order),
            const SizedBox(height: 14),
            if (business != null) ...[
              _section(child: _businessCard(business)),
              const SizedBox(height: 14),
            ],
            if (deliveryAddress != null) ...[
              _section(child: _addressCard(deliveryAddress)),
              const SizedBox(height: 14),
            ],
            if (itemsSummary != null) ...[
              _section(child: _itemsCard(itemsSummary)),
              const SizedBox(height: 14),
            ],
            if (costSummary != null) ...[
              _section(child: _costCard(costSummary)),
              const SizedBox(height: 14),
            ],
            _section(child: _metaCard(order)),
            if (statuses.isNotEmpty) ...[
              const SizedBox(height: 14),
              _section(child: _historyCard(statuses)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 18),
      child: child,
    );
  }

  Widget _statusChip(String label, {Color? color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: AppDecorations.pill(color: (color ?? AppColors.blue).withValues(alpha: 0.9)),
      child: Text(label, style: TextStyle(color: textColor ?? AppColors.text, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _statusCard(Map<String, dynamic> order) {
    final currentStatus = order['current_status'] as Map<String, dynamic>?;
    final statusDescription = currentStatus?['status_description']?.toString() ?? 'Неизвестно';
    final statusCode = currentStatus?['status']?.toString() ?? '';
    final createdAt = order['log_timestamp']?.toString();
    final deliveryType = order['delivery_type']?.toString() ?? 'Не указан';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 18, color: AppColors.cardDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping, color: AppColors.orange, size: 22),
              const SizedBox(width: 8),
              const Text('Статус заказа', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              _statusChip(statusCode.isNotEmpty ? statusCode : '—', color: AppColors.orange, textColor: Colors.black),
            ],
          ),
          const SizedBox(height: 10),
          Text(statusDescription, style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.textMute, size: 16),
              const SizedBox(width: 6),
              Text('Заказ #${order['order_id'] ?? '-'}', style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
            ],
          ),
          if (createdAt != null) ...[
            const SizedBox(height: 4),
            Text('Создан: ${_formatDateTime(createdAt)}', style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.place_outlined, color: AppColors.textMute, size: 16),
              const SizedBox(width: 6),
              Text('Тип доставки: $deliveryType', style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _businessCard(Map<String, dynamic> business) {
    final name = business['name']?.toString() ?? 'Магазин';
    final address = business['address']?.toString();
    final phone = business['phone']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.store_mall_directory, color: AppColors.orange),
            SizedBox(width: 8),
            Text('Магазин', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        Text(name, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
        if (address != null) ...[
          const SizedBox(height: 4),
          Text(address, style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
        ],
        if (phone != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone, color: AppColors.textMute, size: 16),
              const SizedBox(width: 6),
              Text(phone, style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _addressCard(Map<String, dynamic> address) {
    final entrance = address['entrance']?.toString();
    final floor = address['floor']?.toString();
    final apt = address['apartment']?.toString();
    final comment = address['comment']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.location_on_outlined, color: AppColors.orange),
            SizedBox(width: 8),
            Text('Адрес доставки', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 10),
        Text(address['address']?.toString() ?? 'Адрес не указан',
            style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            if (entrance != null) _statusChip('Подъезд $entrance'),
            if (floor != null) _statusChip('Этаж $floor'),
            if (apt != null) _statusChip('Кв. $apt'),
          ],
        ),
        if (comment != null && comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppDecorations.card(radius: 12, color: AppColors.cardDark, shadow: false),
            child: Row(
              children: [
                const Icon(Icons.comment, color: AppColors.textMute, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(comment, style: const TextStyle(color: AppColors.textMute, fontSize: 13))),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _itemsCard(Map<String, dynamic> summary) {
    final items = (summary['items_preview'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final itemsCount = summary['items_count'] ?? items.length;
    final totalAmount = summary['total_amount'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shopping_bag, color: AppColors.orange),
            const SizedBox(width: 8),
            Text('Товары ($itemsCount)', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('Всего: $totalAmount', style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < items.length; i++) ...[
          _itemRow(items[i]),
          if (i < items.length - 1) const Divider(color: Color(0x229FB0C8), height: 16),
        ],
      ],
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final image = item['img']?.toString();
    final name = item['name']?.toString() ?? 'Товар';
    final qty = item['amount'] ?? 0;
    final price = item['price'] ?? item['total'] ?? 0;

    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: AppDecorations.card(radius: 14, color: AppColors.cardDark, shadow: false),
          child: image != null && image.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined, color: AppColors.textMute),
                  ),
                )
              : const Icon(Icons.inventory_2_outlined, color: AppColors.textMute),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('Количество: $qty', style: const TextStyle(color: AppColors.textMute, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatMoney(price), style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _costCard(Map<String, dynamic> cost) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.receipt_long, color: AppColors.orange),
            SizedBox(width: 8),
            Text('Стоимость', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 12),
        _costRow('Товары', cost['items_total']),
        if ((cost['delivery_fee'] ?? 0) > 0) _costRow('Доставка', cost['delivery_fee']),
        if ((cost['service_fee'] ?? 0) > 0) _costRow('Сервисный сбор', cost['service_fee']),
        if ((cost['discount'] ?? 0) > 0) _costRow('Скидка', -cost['discount'], accent: Colors.greenAccent),
        if ((cost['bonus_used'] ?? 0) > 0) _costRow('Бонусы', -cost['bonus_used'], accent: Colors.greenAccent),
        const Divider(color: Color(0x229FB0C8), height: 18),
        _costRow('Итого', cost['total_sum'], isTotal: true),
      ],
    );
  }

  Widget _costRow(String label, num? amount, {Color? accent, bool isTotal = false}) {
    if (amount == null) return const SizedBox.shrink();
    final color = isTotal ? AppColors.orange : accent ?? AppColors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.text, fontSize: isTotal ? 15 : 14, fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600)),
          Text(_formatMoney(amount),
              style: TextStyle(color: color, fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _metaCard(Map<String, dynamic> order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Информация', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _infoRow('Способ оплаты', order['payment_method']),
        _infoRow('Создан', _formatDateTime(order['created_at']?.toString())),
        _infoRow('Номер заказа', '#${order['order_id'] ?? '-'}'),
        if (order['delivery_time'] != null) _infoRow('Доставка', order['delivery_time'].toString()),
      ],
    );
  }

  Widget _infoRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(color: AppColors.textMute, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _historyCard(List<dynamic> statuses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.history, color: AppColors.orange),
            SizedBox(width: 8),
            Text('История статусов', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < statuses.length; i++) ...[
          _historyItem(statuses[i] as Map<String, dynamic>, isLatest: i == 0),
          if (i < statuses.length - 1) const Divider(color: Color(0x229FB0C8), height: 14),
        ],
      ],
    );
  }

  Widget _historyItem(Map<String, dynamic> status, {required bool isLatest}) {
    final label = status['status']?.toString() ?? 'Неизвестный статус';
    final desc = status['description']?.toString();
    final ts = status['timestamp']?.toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: isLatest ? AppColors.orange : AppColors.textMute.withValues(alpha: 0.7), shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: isLatest ? AppColors.orange : AppColors.text, fontWeight: FontWeight.w800)),
              if (desc != null) ...[
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
              ],
              if (ts != null) ...[
                const SizedBox(height: 4),
                Text(_formatDateTime(ts), style: const TextStyle(color: AppColors.textMute, fontSize: 12)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatMoney(num? value) {
    if (value == null) return '—';
    return '${value >= 0 ? '' : '−'}${value.abs().toStringAsFixed(0)} ₸';
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return 'Неизвестно';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inDays > 0) return '${difference.inDays} дн. назад';
      if (difference.inHours > 0) return '${difference.inHours} ч. назад';
      if (difference.inMinutes > 0) return '${difference.inMinutes} мин. назад';
      return 'Только что';
    } catch (_) {
      return 'Неизвестно';
    }
  }
}
