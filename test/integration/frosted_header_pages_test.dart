import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/faq/data/faq_repository.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/ui/app_top_bar.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
        'FAQ header is a plain header at rest and frosts once the list scrolls under it (${dark ? 'dark' : 'light'})',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 812));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: const FaqPage(),
      ));
      await tester.pumpAndSettle();

      bool frosted() =>
          find.byKey(const ValueKey('header-scrim')).evaluate().isNotEmpty;

      expect(frosted(), isFalse);
      final heading = find.text(FaqRepository.sections.first.title);
      expect(tester.getTopLeft(heading).dy,
          greaterThanOrEqualTo(tester.getBottomLeft(find.byType(AppTopBar)).dy),
          reason: 'the first heading must not start under the header');

      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(frosted(), isTrue);

      await tester.drag(
          find.byType(SingleChildScrollView), const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(frosted(), isFalse);
    });
  }
}
