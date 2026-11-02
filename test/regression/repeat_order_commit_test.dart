import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:naliv_delivery/model/cart_item.dart';
import 'package:naliv_delivery/services/repeat_order_service.dart';
import 'package:naliv_delivery/utils/address_storage_service.dart';
import 'package:naliv_delivery/utils/business_provider.dart';
import 'package:naliv_delivery/utils/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  for (final throws in [false, true]) {
    test(
        'repeat reports no restored address after ${throws ? 'throwing' : 'rejected'} address save',
        () async {
      final originalAddress = <String, dynamic>{
        'address': 'Исходный адрес 1',
        'lat': 52.28,
        'lon': 76.95,
      };
      final originalRow = CartItem(
        itemId: 8301,
        name: 'Исходный товар',
        price: 100,
        quantity: 1,
        stepQuantity: 1,
        selectedVariants: const [],
        promotions: const [],
      );
      final values = <String, Object>{
        'selected_business': jsonEncode({'id': 1, 'name': 'Исходный магазин'}),
        'cart_items': jsonEncode({
          'business_id': 1,
          'items': [originalRow.toJson()],
        }),
        'selected_address': jsonEncode(originalAddress),
      };
      final store = throws
          ? _ThrowingAddressPreferences(values)
          : OnboardingPreferences(values);
      store.install();
      if (!throws) store.rejectedKeys.add('selected_address');
      final cart = CartProvider();
      final business = BusinessProvider();
      addTearDown(cart.dispose);
      addTearDown(business.dispose);
      final unexpected = <String>[];
      final client = MockClient((request) async {
        unexpected.add('${request.method} ${request.url}');
        throw StateError('Inline repeat must not access the network');
      });
      addTearDown(client.close);
      addTearDown(() => expect(unexpected, isEmpty));

      final result = await http.runWithClient(
        () => RepeatOrderService.repeatOrderIntoCart(
          sourceOrder: {
            'order_id': 83,
            'business': {'id': 7, 'name': 'Магазин повторного заказа'},
            'delivery_type': 'DELIVERY',
            'delivery_address': {
              'address': 'Адрес повторного заказа 2',
              'lat': 52.29,
              'lon': 76.96,
            },
            'items': [
              {
                'item_id': 8302,
                'name': 'Повторённый товар',
                'price': 120,
                'amount': 2,
                'item_data': {
                  'item_id': 8302,
                  'name': 'Повторённый товар',
                  'price': 120,
                  'unit': 'шт',
                  'step_quantity': 1,
                  'amount': 10,
                },
              },
            ],
          },
          cartProvider: cart,
          businessProvider: business,
        ),
        () => client,
      );

      expect(result.deliveryType, 'DELIVERY');
      expect(result.addedItemsCount, 1);
      expect(result.skippedItems, isEmpty);
      expect(result.addressStatus, RepeatAddressStatus.failed);
      expect(result.canProceedToCheckout, isFalse);
      expect(cart.businessId, 7);
      expect(cart.items.single.itemId, 8302);
      expect(cart.getTotalPrice(), 240);
      expect(business.selectedBusinessId, 7);
      expect(await AddressStorageService.getSelectedAddress(), originalAddress);

      final restartedCart = CartProvider();
      final restartedBusiness = BusinessProvider();
      addTearDown(restartedCart.dispose);
      addTearDown(restartedBusiness.dispose);
      await restartedCart.ensureLoaded();
      await restartedBusiness.loadSavedBusiness();
      expect(restartedCart.businessId, 7);
      expect(restartedCart.items.single.itemId, 8302);
      expect(restartedBusiness.selectedBusinessId, 7);
      expect(await AddressStorageService.getSelectedAddress(), originalAddress);
      expect(
        result.restoredAddress,
        isNull,
        reason: 'Cart and store committed, but the delivery address did not; '
            'the result must not offer an unsaved address to automatic checkout.',
      );
    });
  }

  test(
      'repeating edited addresses preserves canonical label and latest details',
      () async {
    OnboardingPreferences().install();
    final cart = CartProvider();
    final business = BusinessProvider();
    addTearDown(cart.dispose);
    addTearDown(business.dispose);
    final unexpected = <String>[];
    final client = MockClient((request) async {
      unexpected.add('${request.method} ${request.url}');
      throw StateError('Inline repeat must not access the network');
    });
    addTearDown(client.close);
    addTearDown(() => expect(unexpected, isEmpty));
    const baseLabel = 'проспект Независимости, 10';
    expect(
        await AddressStorageService.saveSelectedAddress({
          'address': baseLabel,
          'street': 'проспект Независимости',
          'house': '10',
          'lat': 52.28,
          'lon': 76.95,
          'entrance': '1',
          'floor': '2',
          'apartment': '3',
          'comment': 'Первый комментарий',
        }),
        isTrue);

    await http.runWithClient(() async {
      for (final details in [
        (entrance: '2', floor: '4', apartment: '15', comment: 'Домофон 15'),
        (entrance: '3', floor: '5', apartment: '21', comment: 'Позвонить'),
      ]) {
        final saved = await AddressStorageService.getSelectedAddress();
        expect(
            await AddressStorageService.saveSelectedAddress({
              ...saved!,
              'entrance': details.entrance,
              'floor': details.floor,
              'apartment': details.apartment,
              'comment': details.comment,
            }),
            isTrue);
        final loaded = await AddressStorageService.getSelectedAddress();
        final result = await RepeatOrderService.repeatOrderIntoCart(
          sourceOrder: {
            'business': {'id': 7, 'name': 'Магазин'},
            'delivery_type': 'DELIVERY',
            'delivery_address': loaded,
            'items': [
              {
                'item_id': 8303,
                'name': 'Товар',
                'price': 100,
                'amount': 1,
                'item_data': {
                  'item_id': 8303,
                  'name': 'Товар',
                  'price': 100,
                  'unit': 'шт',
                  'step_quantity': 1,
                  'amount': 10,
                },
              },
            ],
          },
          cartProvider: cart,
          businessProvider: business,
        );
        expect(result.addressStatus, RepeatAddressStatus.restored);
        expect(result.canProceedToCheckout, isTrue);
        final persisted = await AddressStorageService.getSelectedAddress();
        for (final address in [result.restoredAddress!, persisted!]) {
          expect(address['address'], baseLabel);
          expect(address['street'], 'проспект Независимости');
          expect(address['house'], '10');
          expect(address['entrance'], details.entrance);
          expect(address['floor'], details.floor);
          expect(address['apartment'], details.apartment);
          expect(address['comment'], details.comment);
        }
      }
    }, () => client);
  });

  for (final address in [
    null,
    {'address': 'Нет координат'},
    {'address': 'Некорректные координаты', 'lat': 999, 'lon': 76.95},
  ]) {
    test(
        'delivery repeat without a usable address requires explicit recovery $address',
        () async {
      OnboardingPreferences().install();
      final cart = CartProvider();
      final business = BusinessProvider();
      addTearDown(cart.dispose);
      addTearDown(business.dispose);
      final result = await RepeatOrderService.repeatOrderIntoCart(
        sourceOrder: _sourceOrder(address: address),
        cartProvider: cart,
        businessProvider: business,
      );
      expect(cart.items.single.itemId, 8304);
      expect(result.addressStatus, RepeatAddressStatus.unavailable);
      expect(result.restoredAddress, isNull);
      expect(result.canProceedToCheckout, isFalse);
      expect(await AddressStorageService.getSelectedAddress(), isNull);
    });
  }

  test('pickup repeat does not replace a saved delivery address', () async {
    final original = {'address': 'Исходный адрес', 'lat': 52.28, 'lon': 76.95};
    OnboardingPreferences({'selected_address': jsonEncode(original)}).install();
    final cart = CartProvider();
    final business = BusinessProvider();
    addTearDown(cart.dispose);
    addTearDown(business.dispose);
    final result = await RepeatOrderService.repeatOrderIntoCart(
      sourceOrder: {..._sourceOrder(), 'delivery_type': 'PICKUP'},
      cartProvider: cart,
      businessProvider: business,
    );
    expect(result.addressStatus, RepeatAddressStatus.notRequired);
    expect(result.restoredAddress, isNull);
    expect(result.canProceedToCheckout, isTrue);
    expect(await AddressStorageService.getSelectedAddress(), original);
  });

  test('session change during store save prevents cart and address replacement',
      () async {
    final held = Completer<bool>();
    OnboardingPreferences()
      ..heldKey = 'selected_business'
      ..heldWrite = held
      ..install();
    final cart = CartProvider();
    final business = BusinessProvider();
    addTearDown(cart.dispose);
    addTearDown(business.dispose);
    var current = true;
    final repeat = RepeatOrderService.repeatOrderIntoCart(
      sourceOrder: _sourceOrder(),
      cartProvider: cart,
      businessProvider: business,
      isCurrent: () => current,
    );
    final refused = expectLater(repeat, throwsA(isA<RepeatOrderException>()));
    await Future<void>.delayed(Duration.zero);
    current = false;
    held.complete(true);
    await refused;
    expect(cart.items, isEmpty);
    expect(await AddressStorageService.getSelectedAddress(), isNull);
  });

  test('session change during committed cart write suppresses address effects',
      () async {
    final held = Completer<bool>();
    OnboardingPreferences()
      ..heldKey = 'cart_items'
      ..heldWrite = held
      ..install();
    final cart = CartProvider();
    final business = BusinessProvider();
    addTearDown(cart.dispose);
    addTearDown(business.dispose);
    var current = true;
    final repeat = RepeatOrderService.repeatOrderIntoCart(
      sourceOrder: _sourceOrder(),
      cartProvider: cart,
      businessProvider: business,
      isCurrent: () => current,
    );
    await Future<void>.delayed(Duration.zero);
    expect(business.selectedBusinessId, 7);
    current = false;
    held.complete(true);
    final result = await repeat;
    expect(cart.items.single.itemId, 8304);
    expect(result.addedItemsCount, 1);
    expect(result.canProceedToCheckout, isFalse);
    expect(result.restoredAddress, isNull);
    expect(await AddressStorageService.getSelectedAddress(), isNull);
  });
}

class _ThrowingAddressPreferences extends OnboardingPreferences {
  _ThrowingAddressPreferences(super.values);

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (key == 'flutter.selected_address') {
      return Future<bool>.error(StateError('Fixture address storage failure'));
    }
    return super.setValue(valueType, key, value);
  }
}

Map<String, dynamic> _sourceOrder({
  Map<String, dynamic>? address = const {
    'address': 'Адрес повторного заказа',
    'lat': 52.29,
    'lon': 76.96,
  },
}) =>
    {
      'business': {'id': 7, 'name': 'Магазин'},
      'delivery_type': 'DELIVERY',
      if (address != null) 'delivery_address': address,
      'items': [
        {
          'item_id': 8304,
          'name': 'Товар',
          'price': 100,
          'amount': 1,
          'item_data': {
            'item_id': 8304,
            'name': 'Товар',
            'price': 100,
            'unit': 'шт',
            'step_quantity': 1,
            'amount': 10,
          },
        },
      ],
    };
