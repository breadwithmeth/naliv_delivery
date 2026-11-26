import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test/support/design_surfaces.dart';

/// One offline build: a complete shopping journey and direct inspection routes.
class ShoppingPilot extends StatefulWidget {
  const ShoppingPilot({super.key});

  @override
  State<ShoppingPilot> createState() => _ShoppingPilotState();
}

class _ShoppingPilotState extends State<ShoppingPilot> {
  String? _surface;

  void _start(String surface) {
    // Reset only the fixture's in-memory store, after the previous trial unmounted.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({...surfaceFixturePreferences}
      ..removeWhere((key, _) => key == 'auth_token' &&
          const {'sign_in', 'profile_guest', 'onboarding'}.contains(surface)));
    setState(() => _surface = surface);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Builder(builder: (context) {
          final surface = _surface;
          if (surface == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Градусы24 · пилот')),
              body: SafeArea(child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text('Проверка обновления', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text('Выберите магазин, добавьте товар и оформите тестовый заказ. Здесь нет сети, реальных списаний или отправки сообщений.'),
                  const SizedBox(height: 16),
                  FilledButton(onPressed: () => _start('active_route'), child: const Text('Пройти покупку')),
                  for (final (label, route) in const [
                    ('Каталог', 'quantity_pilot_catalog'),
                    ('Карточка товара', 'pilot_favorite_product'),
                    ('Категории', 'merchandising_store_1'),
                    ('Настройки · гость', 'profile_guest'),
                    ('Адреса', 'addresses'),
                    ('Оформление', 'checkout_delivery'),
                    ('Повтор после отказа', 'checkout_error'),
                    ('Профиль', 'profile'),
                    ('Чат', 'support'),
                    ('Сертификаты', 'certificates'),
                    ('Заказы', 'orders'),
                    ('Первый запуск', 'onboarding'),
                  ])
                    OutlinedButton(onPressed: () => _start(route), child: Text(label)),
                  const Divider(height: 40),
                  const Text('Тестовый номер +7 000 000 00 00: 000000 — ошибка проверки, 123456 — вход. Сообщения не отправляются.'),
                  const Text('Для оформления: SALE — скидка, GIFT — оплата сертификатом. Для активации в профиле: FIXT-GIFT-1500-0001.'),
                  TextButton(onPressed: () => _start('sign_in'), child: const Text('Открыть вход')),
                ],
              )),
            );
          }
          return Material(child: Column(children: [
            SafeArea(bottom: false, child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: () => setState(() => _surface = null),
                  icon: const Icon(Icons.arrow_back), label: const Text('К выбору')),
            )),
            Expanded(child: LayoutBuilder(builder: (context, constraints) => DesignSurfaceApp(
              surface: surface,
              brightness: MediaQuery.platformBrightnessOf(context),
              size: constraints.biggest,
              textScaler: MediaQuery.textScalerOf(context),
              viewInsets: MediaQuery.viewInsetsOf(context),
              onSurfaceChanged: (next) {
                if (next == 'home') setState(() => _surface = null);
              },
            ))),
          ]));
        }),
      );
}
