import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:naliv_delivery/utils/business_provider.dart';

import '../support/preferences_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  test(
      'rejected store change preserves persisted selection and published state',
      () async {
    final store = OnboardingPreferences({
      'selected_business': jsonEncode({'id': 1, 'name': 'Первый магазин'}),
    })
      ..install();
    final provider = BusinessProvider();
    await provider.loadSavedBusiness();
    final observedIds = <int?>[];
    provider.addListener(() => observedIds.add(provider.selectedBusinessId));
    store.rejectedKeys.add('selected_business');
    expect(
        await provider.setSelectedBusiness({'id': 2, 'name': 'Другой магазин'}),
        isFalse);
    expect(provider.selectedBusinessId, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('selected_business')!)['id'], 1);
    expect(observedIds, isEmpty);
    provider.dispose();
  });

  test(
      'concurrent choices publish in persisted order and leave the last store selected',
      () async {
    final held = Completer<bool>();
    OnboardingPreferences()
      ..heldKey = 'selected_business'
      ..heldWrite = held
      ..install();
    final provider = BusinessProvider();
    final observedIds = <int?>[];
    provider.addListener(() => observedIds.add(provider.selectedBusinessId));
    final first = provider.setSelectedBusiness({'id': 1, 'name': 'Первый'});
    final second = provider.setSelectedBusiness({'id': 2, 'name': 'Второй'});
    await Future<void>.delayed(Duration.zero);
    expect(provider.selectedBusiness, isNull);
    held.complete(true);
    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(observedIds, [1, 2]);
    expect(provider.selectedBusinessId, 2);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('selected_business')!)['id'], 2);
    provider.dispose();
  });
}
