import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/shared/RefractiveGlassContainer.dart';

void main() {
  testWidgets('keeps the blur filter when shader filters are unsupported',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RefractiveGlassContainer(
            child: SizedBox(width: 180, height: 80),
          ),
        ),
      ),
    );

    // Allows the bundled fragment program to load. The widget-test renderer
    // then rejects ImageFilter.shader, exercising the runtime fallback rather
    // than only the pre-load placeholder.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
