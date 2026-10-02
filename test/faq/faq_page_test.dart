import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/features/faq/data/faq_repository.dart';
import 'package:naliv_delivery/features/faq/models/faq.dart';
import 'package:naliv_delivery/features/faq/faq_navigation.dart';

void main() {
  Future<void> pumpFaq(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: const FaqPage()),
      );

  FaqEntry entryMatching(String needle) => FaqRepository.sections
      .expand((section) => section.entries)
      .firstWhere((entry) => entry.question.contains(needle));

  testWidgets('answers expand and collapse without leaving stale content',
      (tester) async {
    await pumpFaq(tester);
    final section = FaqRepository.sections.first;
    final first = section.entries.first;
    final second = section.entries[1];

    await tester.ensureVisible(find.text(second.question));
    await tester.tap(find.text(second.question));
    await tester.pumpAndSettle();
    expect(find.text(second.answer), findsOneWidget);
    expect(find.text(first.answer), findsNothing);

    await tester.ensureVisible(find.text(second.question));
    await tester.tap(find.text(second.question));
    await tester.pumpAndSettle();
    expect(find.text(second.answer), findsNothing);
  });

  testWidgets('search narrows to matches and drops sections with nothing left',
      (tester) async {
    await pumpFaq(tester);
    final target = entryMatching('SMS');
    final unrelated = FaqRepository.sections.last;

    await tester.enterText(find.byType(TextField), 'sms');
    await tester.pumpAndSettle();

    expect(find.text(target.question), findsOneWidget);
    expect(find.text(unrelated.title), findsNothing);

    // A different question that does not match the query must be gone entirely — this is the
    // filter contract, and it is what a naive `contains` on the section title would break.
    final other = FaqRepository.sections
        .expand((section) => section.entries)
        .firstWhere((entry) => entry.question != target.question);
    expect(find.text(other.question), findsNothing);
  });

  testWidgets('a search with no matches shows the empty state', (tester) async {
    await pumpFaq(tester);

    await tester.enterText(find.byType(TextField), 'зззззз');
    await tester.pumpAndSettle();

    expect(find.text('Ничего не найдено'), findsOneWidget);
  });

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
