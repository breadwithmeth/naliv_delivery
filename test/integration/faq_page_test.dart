import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/design/theme.dart';
import 'package:naliv_delivery/features/faq/ui/faq_page.dart';
import 'package:naliv_delivery/features/faq/data/faq_repository.dart';
import 'package:naliv_delivery/features/faq/models/faq.dart';
import 'package:naliv_delivery/features/faq/faq_navigation.dart';

import '../support/haptic_calls.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets(
        reduceMotion
            ? 'Reduce Motion reveals an FAQ answer in one frame without haptics'
            : 'FAQ reveals answers in place over multiple frames without haptics',
        (tester) async {
      final calls = recordHapticCalls(tester);
      final entries = FaqRepository.sections.first.entries;
      final question = find.text(entries.first.question);
      final answer = find.text(entries.first.answer);
      final nextQuestion = find.text(entries[1].question);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: const FaqPage(),
      ));
      await tester.pumpAndSettle();
      final header = tester.getTopLeft(question);
      final expanded = tester.getTopLeft(nextQuestion).dy;

      await tester.tap(question);
      await tester.pumpAndSettle();
      expect(answer, findsNothing);
      final collapsed = tester.getTopLeft(nextQuestion).dy;
      expect(collapsed, lessThan(expanded));

      await tester.tap(question);
      await tester.pump();
      if (!reduceMotion) {
        expect(tester.getTopLeft(nextQuestion).dy, collapsed);
        await tester.pump(const Duration(milliseconds: 80));
        final intermediate = tester.getTopLeft(nextQuestion).dy;
        expect(intermediate, greaterThan(collapsed));
        expect(intermediate, lessThan(expanded));
        await tester.pumpAndSettle();
      }
      expect(tester.getTopLeft(question), header);
      expect(tester.getTopLeft(nextQuestion).dy, expanded);
      expect(answer, findsOneWidget);
      expect(calls, isEmpty);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  }

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

    await tester.tap(find.byTooltip('Поиск'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  код для входа  ');
    await tester.pumpAndSettle();
    final loginHelp = find.text(
      'Что делать, если код для входа не пришёл в WhatsApp?',
    );
    expect(loginHelp, findsOneWidget);
    expect(find.text(target.question), findsNothing);
    await tester.tap(loginHelp);
    await tester.pumpAndSettle();
    expect(find.textContaining('Код для входа приходит в WhatsApp.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
