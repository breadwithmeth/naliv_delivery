import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/features/faq/data/faq_repository.dart';
import 'package:naliv_delivery/features/faq/models/faq.dart';
import 'package:naliv_delivery/features/faq/faq_navigation.dart';

void main() {
  FaqEntry entryMatching(String needle) => FaqRepository.sections
      .expand((section) => section.entries)
      .firstWhere((entry) => entry.question.contains(needle));

  testWidgets('shortcut reaches a late section through the feature route',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final section = FaqRepository.sections.last;
    final target = section.entries.first;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        routes: {
          FaqPage.routeName: (context) => FaqPage(
                initialSection:
                    ModalRoute.of(context)!.settings.arguments as FaqSection?,
              ),
        },
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => openFaqPage(
                context,
                initialSection: FaqSection.orderProblems,
              ),
              child: const Text('Помощь с заказом'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Помощь с заказом'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(target.question));
    await tester.pumpAndSettle();
    expect(find.text(target.answer), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  SMS  ');
    await tester.pumpAndSettle();
    expect(find.text(entryMatching('SMS').question), findsOneWidget);
    expect(find.text(target.question), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
