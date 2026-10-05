import 'package:flutter_test/flutter_test.dart';
import 'package:naliv_delivery/features/profile/profile_account.dart';

void main() {
  test('missing account collections are unknown, not empty', () {
    final account = ProfileAccount.fromJson({
      'user': {'name': ' Айжан ', 'login': '+7000'}
    });
    expect(account.name, 'Айжан');
    expect(account.phone, '+7000');
    expect(account.addressSummary, isNull);
    expect(account.cardsSummary, isNull);
  });

  test('malformed account collection is rejected rather than undercounted', () {
    expect(
        () => ProfileAccount.fromJson({
              'user': {},
              'cards': [null],
            }),
        throwsFormatException);
  });
}
