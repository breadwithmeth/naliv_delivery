import 'package:flutter/material.dart';

class OrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailPage({
    super.key,
    required this.order,
  });

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
      // Используем переданные данные заказа
      await Future.delayed(const Duration(milliseconds: 100));

      setState(() {
        _orderDetails = widget.order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки деталей заказа: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Заказ #${widget.order['order_id']}'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadOrderDetails,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : _orderDetails != null
                  ? _buildOrderDetails()
                  : const SizedBox.shrink(),
    );
  }

  Widget _buildOrderDetails() {
    final order = _orderDetails!;
    final business = order['business'] as Map<String, dynamic>?;
    final deliveryAddress = order['delivery_address'] as Map<String, dynamic>?;
    final itemsSummary = order['items_summary'] as Map<String, dynamic>?;
    final costSummary = order['cost_summary'] as Map<String, dynamic>?;
    final statuses = order['order_statuses'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Статус заказа
          _buildStatusCard(order),
          const SizedBox(height: 16),

          // Информация о магазине
          if (business != null) ...[
            _buildBusinessCard(business),
            const SizedBox(height: 16),
          ],

          // Адрес доставки
          if (deliveryAddress != null) ...[
            _buildDeliveryAddressCard(deliveryAddress),
            const SizedBox(height: 16),
          ],

          // Товары в заказе
          if (itemsSummary != null) ...[
            _buildItemsCard(itemsSummary),
            const SizedBox(height: 16),
          ],

          // Стоимость заказа
          if (costSummary != null) ...[
            _buildCostSummaryCard(costSummary),
            const SizedBox(height: 16),
          ],

          // Информация о доставке и оплате
          _buildOrderInfoCard(order),
          const SizedBox(height: 16),

          // История статусов
          if (statuses.isNotEmpty) ...[
            _buildOrderStatusHistory(statuses),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> order) {
    final currentStatus = order['current_status'] as Map<String, dynamic>?;
    final statusDescription =
        currentStatus?['status_description'] ?? 'Неизвестно';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Статус заказа',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusDescription,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Заказ #${order['order_id']}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (order['log_timestamp'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Создан: ${_formatDateTime(order['log_timestamp'])}',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.local_shipping,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                'Тип доставки: ${order['delivery_type'] ?? 'Не указан'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessCard(Map<String, dynamic> business) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.store,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Магазин',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            business['name'] ?? 'Неизвестный магазин',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (business['address'] != null) ...[
            const SizedBox(height: 4),
            Text(
              business['address'],
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (business['phone'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.phone,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  business['phone'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeliveryAddressCard(Map<String, dynamic> deliveryAddress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Адрес доставки',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            deliveryAddress['address'] ?? 'Адрес не указан',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (deliveryAddress['entrance'] != null ||
              deliveryAddress['floor'] != null ||
              deliveryAddress['apartment'] != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                if (deliveryAddress['entrance'] != null)
                  Text('Подъезд: ${deliveryAddress['entrance']}'),
                if (deliveryAddress['floor'] != null)
                  Text('Этаж: ${deliveryAddress['floor']}'),
                if (deliveryAddress['apartment'] != null)
                  Text('Квартира: ${deliveryAddress['apartment']}'),
              ],
            ),
          ],
          if (deliveryAddress['comment'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.comment,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      deliveryAddress['comment'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItemsCard(Map<String, dynamic> itemsSummary) {
    final itemsCount = itemsSummary['items_count'] ?? 0;
    final totalAmount = itemsSummary['total_amount'] ?? 0;
    final itemsPreview = itemsSummary['items_preview'] as List<dynamic>? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shopping_bag,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Товары в заказе ($itemsCount)',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Общее количество: $totalAmount',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < itemsPreview.length; i++) ...[
            _buildItemPreviewRow(itemsPreview[i]),
            if (i < itemsPreview.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildItemPreviewRow(Map<String, dynamic> item) {
    return Row(
      children: [
        // Изображение товара (если есть)
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: item['img'] != null && item['img'].toString().isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item['img'],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.inventory_2_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 24,
                      );
                    },
                  ),
                )
              : Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 24,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item['name'] ?? 'Неизвестный товар',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Количество: ${item['amount'] ?? 0}',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCostSummaryCard(Map<String, dynamic> costSummary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Стоимость заказа',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCostRow('Товары', costSummary['items_total']),
          if (costSummary['delivery_fee'] != null &&
              costSummary['delivery_fee'] > 0)
            _buildCostRow('Доставка', costSummary['delivery_fee']),
          if (costSummary['service_fee'] != null &&
              costSummary['service_fee'] > 0)
            _buildCostRow('Сервисный сбор', costSummary['service_fee']),
          if (costSummary['discount'] != null && costSummary['discount'] > 0)
            _buildCostRow('Скидка', -costSummary['discount'], isDiscount: true),
          if (costSummary['bonus_used'] != null &&
              costSummary['bonus_used'] > 0)
            _buildCostRow('Бонусы', -costSummary['bonus_used'], isBonus: true),
          const Divider(height: 16),
          _buildCostRow('Итого', costSummary['total_sum'], isTotal: true),
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, num? amount,
      {bool isDiscount = false, bool isBonus = false, bool isTotal = false}) {
    if (amount == null) return const SizedBox.shrink();

    Color? textColor;
    if (isDiscount || isBonus) {
      textColor = Colors.green;
    } else if (isTotal) {
      textColor = Theme.of(context).colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
          Text(
            '${amount >= 0 ? '' : '−'}${amount.abs()} ₸',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfoCard(Map<String, dynamic> order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Информация о заказе',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Способ оплаты', order['payment_method']),
          _buildInfoRow('Время создания', _formatDateTime(order['created_at'])),
          _buildInfoRow('Номер заказа', '#${order['order_id']}'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusHistory(List<dynamic> statuses) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'История заказа',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < statuses.length; i++) ...[
            _buildStatusHistoryItem(statuses[i], i == 0),
            if (i < statuses.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusHistoryItem(Map<String, dynamic> status, bool isLatest) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: isLatest
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status['status'] ?? 'Неизвестный статус',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color:
                      isLatest ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
              if (status['description'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  status['description'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _formatDateTime(status['timestamp']),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Неизвестно';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} дн. назад';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ч. назад';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} мин. назад';
      } else {
        return 'Только что';
      }
    } catch (e) {
      return 'Неизвестно';
    }
  }
}
