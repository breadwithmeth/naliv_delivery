import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/home/home_view_data.dart';
import 'package:naliv_delivery/features/home/ui/home_page.dart';

const _data = HomeViewData(
  phone: '+7 (777) 777-77-77',
  callCenterLabel: 'Звонок в Call Center',
  storeName: 'Градусы24 — Тестовый магазин',
  storeAddress: 'Тестовая улица, 24',
  signedIn: false,
  banners: [HomeBanner(title: 'Акции')],
  promoCard: HomePromoCard(
    id: 100,
    title: 'Кухня',
    subtitle: 'Готовые блюда',
  ),
  categories: [
    HomeCategory(id: 10, title: 'Слабоалкогольные напитки'),
    HomeCategory(id: 9, title: 'Еда и закуски'),
    HomeCategory(id: 8, title: 'Крепкие напитки'),
  ],
);

Widget _host(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: child,
    );

void main() {
  testWidgets('home exposes primary shopping and account actions',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var searched = false;
    var storeOpened = false;
    var selectedCategory = -1;
    var signedIn = false;

    await tester.pumpWidget(_host(HomePage(
      data: _data,
      onSearch: () => searched = true,
      onStore: () => storeOpened = true,
      onCategory: (category) => selectedCategory = category.id,
      onSignIn: () => signedIn = true,
    )));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Найти любимый напиток'));
    await tester.tap(find.text('Сменить'));
    expect(searched, isTrue);
    expect(storeOpened, isTrue);

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -750),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Слабоалкогольные напитки'));
    expect(selectedCategory, 10);

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -650),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Войти или зарегистрироваться'));
    expect(signedIn, isTrue);
    expect(tester.takeException(), isNull);
  });
}
