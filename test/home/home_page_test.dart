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
    HomeCategory(id: 7, title: 'Табак'),
    HomeCategory(id: 2, title: 'Безалкогольные напитки'),
    HomeCategory(id: 1, title: 'Прочее'),
  ],
);

Widget _host(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: child,
    );

void main() {
  testWidgets('375px home geometry follows the measured first viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(const HomePage(data: _data)));
    expect(tester.takeException(), isNull);

    Rect rect(String key) => tester.getRect(find.byKey(ValueKey(key)));

    expect(rect('home-header'), const Rect.fromLTWH(16, 24, 343, 57));
    expect(rect('home-store-card'), const Rect.fromLTWH(16, 93, 343, 57));
    expect(rect('home-search-field'), const Rect.fromLTWH(16, 162, 343, 38));
    expect(rect('home-banner-carousel'), const Rect.fromLTWH(0, 224, 375, 114));
    expect(rect('home-promo-card'), const Rect.fromLTWH(16, 362, 343, 160));
    expect(rect('home-category-grid'), const Rect.fromLTWH(16, 546, 343, 296));
    expect(rect('home-bonus-card'), const Rect.fromLTWH(16, 842, 343, 199));
  });
}
