import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/item.dart' as ItemModel;
// import '../models/CartItem.dart';
import '../utils/cart_provider.dart';

class ItemOptionsDialog extends StatefulWidget {
  final ItemModel.Item item;

  const ItemOptionsDialog({
    super.key,
    required this.item,
  });

  @override
  State<ItemOptionsDialog> createState() => _ItemOptionsDialogState();
}

class _ItemOptionsDialogState extends State<ItemOptionsDialog> {
  Map<int, ItemModel.ItemOptionItem?> selectedOptions = {};
  late double quantity;

  @override
  void initState() {
    super.initState();
    // Инициализируем выбранные опции значениями по умолчанию
    if (widget.item.options != null) {
      for (var option in widget.item.options!) {
        if (option.required == 1 && option.optionItems.isNotEmpty) {
          selectedOptions[option.optionId] = option.optionItems.first;
        }
      }
    }
    // Устанавливаем начальное количество равным step-у
    double step = 1.0;
    if (selectedOptions.isNotEmpty) {
      final first = selectedOptions.values.first;
      if (first != null) {
        step = first.parentItemAmount.toDouble();
      }
    }
    quantity = step;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок с изображением и названием товара
            Row(
              children: [
                // Изображение товара
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: widget.item.hasImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.item.image!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.inventory_2_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: 12),
                // Название и цена
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_calculateTotalPrice().toStringAsFixed(0)} ₸',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Опции товара
            if (widget.item.hasOptions) ...[
              const Text(
                'Выберите опции:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ...widget.item.options!.map((option) => _buildOption(option)),
              const SizedBox(height: 16),
            ],

            // Количество
            Row(
              children: [
                const Text(
                  'Количество:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    IconButton(
                      // Уменьшаем на шаг: parent_item_amount или 1
                      onPressed: () {
                        double step = 1.0;
                        if (selectedOptions.isNotEmpty) {
                          final first = selectedOptions.values.first;
                          if (first != null) {
                            step = first.parentItemAmount.toDouble();
                          }
                        }
                        // Не позволяем уменьшить ниже одного шага
                        if (quantity > step) {
                          setState(() => quantity = quantity - step);
                        }
                      },
                      icon: const Icon(Icons.remove),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Theme.of(context).colorScheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        () {
                          // Получаем текущий step
                          double step = 1.0;
                          if (selectedOptions.isNotEmpty) {
                            final first = selectedOptions.values.first;
                            if (first != null) {
                              step = first.parentItemAmount.toDouble();
                            }
                          }
                          // Если step != 1.0, показываем дробные значения
                          return step == 1.0
                              ? quantity.toStringAsFixed(0)
                              : quantity.toStringAsFixed(2);
                        }(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      // Увеличиваем на шаг: parent_item_amount или 1
                      onPressed: () {
                        double step = 1.0;
                        if (selectedOptions.isNotEmpty) {
                          final first = selectedOptions.values.first;
                          if (first != null) {
                            step = first.parentItemAmount.toDouble();
                          }
                        }
                        setState(() => quantity = quantity + step);
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Кнопки действий
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Отмена'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canAddToCart() ? _addToCart : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    ),
                    child: const Text('В корзину'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(ItemModel.ItemOption option) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              option.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (option.required == 1)
              Text(
                ' *',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (option.selection == 'SINGLE' || option.selection == 'single')
          _buildSingleSelectionOption(option)
        else
          _buildMultipleSelectionOption(option),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSingleSelectionOption(ItemModel.ItemOption option) {
    return Column(
      children: option.optionItems.map((optionItem) {
        return RadioListTile<ItemModel.ItemOptionItem>(
          title: Text(
            _getOptionItemName(optionItem),
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: optionItem.price > 0
              ? Text(
                  '+${optionItem.price.toStringAsFixed(0)} ₸',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : null,
          value: optionItem,
          groupValue: selectedOptions[option.optionId],
          onChanged: (value) {
            setState(() {
              selectedOptions[option.optionId] = value;
              // Сброс количества при изменении опции
              quantity = 0.0;
            });
          },
          dense: true,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }

  Widget _buildMultipleSelectionOption(ItemModel.ItemOption option) {
    // Для множественного выбора (пока не реализовано)
    return Text(
      'Множественный выбор пока не поддерживается',
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  String _getOptionItemName(ItemModel.ItemOptionItem optionItem) {
    // Здесь можно добавить логику для получения названия опции
    // Пока возвращаем ID товара
    return ' ${optionItem.item_name}';
  }

  double _calculateTotalPrice() {
    double total = widget.item.price;

    for (var selectedOption in selectedOptions.values) {
      if (selectedOption != null) {
        if (selectedOption.priceType == 'ADD') {
          total += selectedOption.price;
        } else if (selectedOption.priceType == 'REPLACE') {
          // Заменяем базовую цену
          total = selectedOption.price;
        }
      }
    }

    return total * quantity;
  }

  bool _canAddToCart() {
    if (widget.item.options == null) return true;

    // Проверяем, что все обязательные опции выбраны
    for (var option in widget.item.options!) {
      if (option.required == 1 && selectedOptions[option.optionId] == null) {
        return false;
      }
    }

    return true;
  }

  void _addToCart() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Собираем Map вариантов для новой модели
    List<Map<String, dynamic>> variantMaps = [];
    for (var option in widget.item.options ?? []) {
      final selected = selectedOptions[option.optionId];
      if (selected != null) {
        variantMaps.add({
          'variant_id': selected.relationId,
          'parent_item_amount': selected.parentItemAmount,
          'required': option.required,
          'price': selected.price,
        });
      }
    }
    // Собираем промоакции: парсим SUBTRACT из описания, PERCENT -> DISCOUNT
    List<Map<String, dynamic>> promoMaps = [];
    for (var p in widget.item.promotions ?? []) {
      String type = p.discountType == 'PERCENT' ? 'DISCOUNT' : p.discountType;
      int base = 0;
      int add = 0;
      double discount = 0;
      if (type == 'SUBTRACT') {
        // Описание в формате 'X+Y'
        final parts = (p.description ?? '').split('+');
        if (parts.length >= 2) {
          base = int.tryParse(parts[0]) ?? 0;
          add = int.tryParse(parts[1]) ?? 0;
        }
      } else if (type == 'DISCOUNT') {
        discount = p.discountValue;
      }
      promoMaps.add({
        'type': type,
        'baseAmount': base,
        'addAmount': add,
        'discount': discount,
      });
    }
    // Добавляем в корзину с новой сигнатурой
    cartProvider.addItemWithOptions(
      widget.item.itemId,
      widget.item.name,
      widget.item.image ?? '',
      widget.item.price,
      quantity,
      variantMaps,
      promoMaps,
    );

    Navigator.of(context).pop();

    // Показываем уведомление
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.item.name} добавлен в корзину'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
