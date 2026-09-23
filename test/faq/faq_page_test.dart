import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/pages/faq_page.dart' show FaqEntry, FaqRepository;

void main() {
  Future<void> pumpFaq(WidgetTester tester) => tester.pumpWidget(
        MaterialApp(theme: AppTheme.dark(), home: const FaqPage()),
      );

  FaqEntry entryMatching(String needle) => FaqRepository.sections
      .expand((section) => section.entries)
      .firstWhere((entry) => entry.question.contains(needle));

  testWidgets('renders the repository content with the first answer already open', (tester) async {
    await pumpFaq(tester);

    final first = FaqRepository.sections.first.entries.first;
    expect(find.text(first.question), findsOneWidget);
    // The design opens one answer; a wall of closed rows would not match it.
    expect(find.text(first.answer), findsOneWidget);
  });

  testWidgets('search narrows to matches and drops sections with nothing left', (tester) async {
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
}
