import 'package:flutter/material.dart';
import 'package:naliv_delivery/shared/app_theme.dart';
import 'package:naliv_delivery/utils/api.dart';

const Map<String, String> _orderStatusLabels = <String, String>{
  '0': 'Новый заказ',
  '1': 'Принят магазином',
  '11': 'Просмотрен',
  '12': 'Собирается',
  '2': 'Готов к выдаче',
  '21': 'Передан курьеру',
  '3': 'Доставляется',
  '31': 'Курьер рядом',
  '4': 'Доставлен',
  '5': 'Отменен',
  '50': 'Отменен пользователем',
  '51': 'Отменен магазином',
  '52': 'Отменен: нет в наличии',
  '6': 'Ошибка платежа',
  '60': 'Ожидает оплаты',
  '61': 'Оплата в обработке',
  '66': 'Не оплачен',
  '7': 'Возврат начат',
  '71': 'Возврат завершен',
};

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailPage({super.key, required this.order});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Map<String, dynamic>? _orderDetails;
  Map<String, dynamic>? _courierLocation;
  bool _isLoading = true;
  bool _isLoadingCourier = false;
  String? _error;
  String? _courierError;

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return const <Map<String, dynamic>>[];
    return value.map(_asMap).whereType<Map<String, dynamic>>().toList();
  }

  num? _asNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString());
  }

  String _resolveStatusLabel(Map<String, dynamic>? status, {String fallback = 'Неизвестно'}) {
    if (status == null) return fallback;

    final explicitText = status['status_description']?.toString() ?? status['status_name']?.toString() ?? status['description']?.toString();
    if (explicitText != null && explicitText.trim().isNotEmpty) {
      return explicitText;
    }

    final code = status['status']?.toString();
    if (code == null || code.isEmpty) return fallback;
    return _orderStatusLabels[code] ?? 'Статус $code';
  }

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
    _loadCourierLocation();
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderId = int.tryParse(widget.order['order_id']?.toString() ?? '');
      final details = orderId != null ? await ApiService.getOrderDetails(orderId) : null;
      if (!mounted) return;
      setState(() {
        _orderDetails = details ?? widget.order;
        final courierLocation = _asMap(_orderDetails?['courier_location']);
        if (courierLocation != null) {
          _courierLocation = courierLocation;
        }
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

  Future<void> _loadCourierLocation() async {
    final orderId = int.tryParse(widget.order['order_id']?.toString() ?? '');
    final deliveryType = widget.order['delivery_type']?.toString();
    if (orderId == null || deliveryType != 'DELIVERY') {
      return;
    }

    setState(() {
      _isLoadingCourier = true;
      _courierError = null;
    });

    try {
      final location = await ApiService.getCourierLocation(orderId);
      if (!mounted) return;
      setState(() {
        _courierLocation = location;
        _isLoadingCourier = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _courierError = 'Не удалось загрузить местоположение курьера';
        _isLoadingCourier = false;
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
    final business = _asMap(order['business']);
    final deliveryAddress = _asMap(order['delivery_address']);
    final itemsSummary = _resolveItemsSummary(order);
    final costSummary = _resolveCostSummary(order);
    final statuses = _resolveStatuses(order);

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
            if (_shouldShowCourierCard(order)) ...[
              _section(child: _courierCard()),
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
    final currentStatus = _resolveCurrentStatus(order);
    final statusDescription = _resolveStatusLabel(currentStatus);
    final statusCode = currentStatus?['status']?.toString() ?? '';
    final createdAt = order['log_timestamp']?.toString() ?? order['created_at']?.toString();
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
    final comment = address['comment']?.toString() ?? address['other']?.toString();

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
    final items = (summary['items_preview'] as List<dynamic>? ?? summary['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
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

  Widget _courierCard() {
    final coords = _extractCourierCoordinates(_courierLocation);
    final updatedAt = _extractCourierTimestamp(_courierLocation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.near_me, color: AppColors.orange),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Курьер', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
            ),
            IconButton(
              onPressed: _isLoadingCourier ? null : _loadCourierLocation,
              icon: _isLoadingCourier
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.orange),
                      ),
                    )
                  : const Icon(Icons.refresh, color: AppColors.textMute),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_courierLocation == null && _courierError == null)
          const Text(
            'Местоположение курьера пока недоступно.',
            style: TextStyle(color: AppColors.textMute),
          )
        else if (_courierError != null)
          Text(_courierError!, style: const TextStyle(color: AppColors.textMute))
        else ...[
          if (coords != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: AppDecorations.card(radius: 12, color: AppColors.cardDark, shadow: false),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: AppColors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${coords['lat']!.toStringAsFixed(6)}, ${coords['lon']!.toStringAsFixed(6)}',
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          if (updatedAt != null) ...[
            const SizedBox(height: 8),
            Text('Обновлено: ${_formatDateTime(updatedAt)}', style: const TextStyle(color: AppColors.textMute, fontSize: 13)),
          ],
          if (_courierLocation != null) ...[
            const SizedBox(height: 8),
            Text(
              _buildCourierSummary(_courierLocation!),
              style: const TextStyle(color: AppColors.textMute, fontSize: 13),
            ),
          ],
        ],
      ],
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final image = item['img']?.toString() ?? item['item_img']?.toString();
    final name = item['name']?.toString() ?? item['item_name']?.toString() ?? 'Товар';
    final qty = _asNum(item['amount']) ?? 0;
    final price = _asNum(item['price']) ?? _asNum(item['total']) ?? _asNum(item['sum']) ?? 0;

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
              Text('Количество: ${qty % 1 == 0 ? qty.toInt() : qty}', style: const TextStyle(color: AppColors.textMute, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatMoney(price), style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _costCard(Map<String, dynamic> cost) {
    final itemsTotal = _asNum(cost['items_total']);
    final deliveryFee = _asNum(cost['delivery_fee']) ?? _asNum(cost['delivery_price']);
    final serviceFee = _asNum(cost['service_fee']);
    final discount = _asNum(cost['discount']);
    final bonusUsed = _asNum(cost['bonus_used']);
    final totalSum = _asNum(cost['total_sum']) ?? _asNum(cost['total']) ?? _asNum(cost['order_total']);
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
        _costRow('Товары', itemsTotal),
        if ((deliveryFee ?? 0) > 0) _costRow('Доставка', deliveryFee),
        if ((serviceFee ?? 0) > 0) _costRow('Сервисный сбор', serviceFee),
        if ((discount ?? 0) > 0) _costRow('Скидка', -(discount ?? 0), accent: Colors.greenAccent),
        if ((bonusUsed ?? 0) > 0) _costRow('Бонусы', -(bonusUsed ?? 0), accent: Colors.greenAccent),
        const Divider(color: Color(0x229FB0C8), height: 18),
        _costRow('Итого', totalSum, isTotal: true),
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
    final user = _asMap(order['user']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Информация', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _infoRow('Способ оплаты', order['payment_method']),
        _infoRow('Создан', _formatDateTime(order['created_at']?.toString() ?? order['log_timestamp']?.toString())),
        _infoRow('Номер заказа', '#${order['order_id'] ?? '-'}'),
        _infoRow('Клиент', user?['name']?.toString()),
        _infoRow('Телефон', user?['phone']?.toString()),
        if (order['delivery_time'] != null) _infoRow('Доставка', order['delivery_time'].toString()),
      ],
    );
  }

  Map<String, dynamic>? _resolveItemsSummary(Map<String, dynamic> order) {
    final explicitSummary = order['items_summary'];
    final mappedSummary = _asMap(explicitSummary);
    if (mappedSummary != null) {
      return mappedSummary;
    }

    final items = _asMapList(order['items']);
    if (items.isEmpty) return null;

    final totalAmount = items.fold<int>(
      0,
      (sum, item) => sum + ((_asNum(item['amount']))?.toInt() ?? 0),
    );

    return {
      'items_count': items.length,
      'total_amount': totalAmount,
      'items_preview': items,
      'items': items,
    };
  }

  Map<String, dynamic>? _resolveCostSummary(Map<String, dynamic> order) {
    final explicitSummary = order['cost_summary'];
    final mappedSummary = _asMap(explicitSummary);
    if (mappedSummary != null) {
      return mappedSummary;
    }

    final directCost = _asMap(order['cost']);
    if (directCost != null) {
      return directCost;
    }

    final items = _asMapList(order['items']);
    if (items.isEmpty &&
        order['delivery_price'] == null &&
        order['bonus_used'] == null &&
        order['bonus'] == null &&
        order['total_sum'] == null &&
        order['total'] == null) {
      return null;
    }

    final itemsTotal = items.fold<num>(0, (sum, item) {
      final amount = _asNum(item['amount']) ?? 0;
      final price = _asNum(item['price']) ?? _asNum(item['total']) ?? _asNum(item['sum']) ?? 0;
      return sum + (amount > 0 && item['price'] != null ? amount * price : price);
    });
    final deliveryPrice = _asNum(order['delivery_price']) ?? 0;
    final bonusUsed = _asNum(order['bonus_used']) ?? _asNum(order['bonus']) ?? 0;
    final totalSum = _asNum(order['total_sum']) ?? _asNum(order['total']) ?? (itemsTotal + deliveryPrice - bonusUsed);

    return {
      'items_total': itemsTotal,
      'delivery_price': deliveryPrice,
      'bonus_used': bonusUsed,
      'total_sum': totalSum,
    };
  }

  List<dynamic> _resolveStatuses(Map<String, dynamic> order) {
    final explicitStatuses = order['order_statuses'];
    if (explicitStatuses is List<dynamic> && explicitStatuses.isNotEmpty) {
      return explicitStatuses;
    }

    final statusHistory = order['status_history'];
    if (statusHistory is List<dynamic> && statusHistory.isNotEmpty) {
      return statusHistory
          .whereType<Map>()
          .map((entry) => {
                'status': entry['status_name'] ?? entry['status'],
                'description': entry['status_name'],
                'timestamp': entry['log_timestamp'] ?? entry['timestamp'],
              })
          .toList();
    }

    final currentStatus = order['current_status'];
    final mappedCurrentStatus = _asMap(currentStatus);
    if (mappedCurrentStatus != null) {
      return [
        {
          'status': mappedCurrentStatus['status_description'] ?? mappedCurrentStatus['status'],
          'description': mappedCurrentStatus['status_description'],
          'timestamp': mappedCurrentStatus['log_timestamp'] ?? order['log_timestamp'],
        }
      ];
    }

    final status = _asMap(order['status']);
    if (status != null) {
      return [
        {
          'status': status['status_name'] ?? status['status'],
          'description': status['status_name'],
          'timestamp': status['log_timestamp'] ?? order['log_timestamp'],
        }
      ];
    }

    return const [];
  }

  Map<String, dynamic>? _resolveCurrentStatus(Map<String, dynamic> order) {
    final currentStatus = _asMap(order['current_status']);
    if (currentStatus != null) {
      return currentStatus;
    }

    final status = _asMap(order['status']);
    if (status != null) {
      return {
        ...status,
        'status_description': status['status_name'] ?? status['status_description'],
      };
    }

    return null;
  }

  bool _shouldShowCourierCard(Map<String, dynamic> order) {
    final deliveryType = order['delivery_type']?.toString();
    return deliveryType == 'DELIVERY';
  }

  Map<String, double>? _extractCourierCoordinates(Map<String, dynamic>? data) {
    if (data == null) return null;

    final candidates = <Map<String, dynamic>>[
      data,
      if (_asMap(data['courier']) != null) _asMap(data['courier'])!,
      if (_asMap(data['location']) != null) _asMap(data['location'])!,
      if (_asMap(data['courier_location']) != null) _asMap(data['courier_location'])!,
    ];

    for (final candidate in candidates) {
      final lat = _parseDouble(candidate['lat'] ?? candidate['latitude']);
      final lon = _parseDouble(candidate['lon'] ?? candidate['lng'] ?? candidate['longitude']);
      if (lat != null && lon != null) {
        return {'lat': lat, 'lon': lon};
      }
    }

    return null;
  }

  String? _extractCourierTimestamp(Map<String, dynamic>? data) {
    if (data == null) return null;
    return data['updated_at']?.toString() ?? data['timestamp']?.toString() ?? _asMap(data['courier'])?['updated_at']?.toString();
  }

  String _buildCourierSummary(Map<String, dynamic> data) {
    final parts = <String>[];
    final courier = _asMap(data['courier']);
    if (courier != null) {
      final name = courier['name']?.toString();
      final phone = courier['phone']?.toString();
      if (name != null && name.isNotEmpty) parts.add('Курьер: $name');
      if (phone != null && phone.isNotEmpty) parts.add('Телефон: $phone');
    }
    final eta = data['eta']?.toString() ?? data['estimated_arrival']?.toString();
    if (eta != null && eta.isNotEmpty) {
      parts.add('ETA: $eta');
    }
    return parts.isEmpty ? 'Данные о курьере получены.' : parts.join(' • ');
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
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
          _historyItem(_asMap(statuses[i]) ?? const <String, dynamic>{}, isLatest: i == 0),
          if (i < statuses.length - 1) const Divider(color: Color(0x229FB0C8), height: 14),
        ],
      ],
    );
  }

  Widget _historyItem(Map<String, dynamic> status, {required bool isLatest}) {
    final label = _resolveStatusLabel(status, fallback: 'Неизвестный статус');
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
