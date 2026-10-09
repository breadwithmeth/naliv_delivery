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

  test('a malformed summary row does not erase another saved card', () {
    final account = ProfileAccount.fromJson({
      'user': {'name': 'Айжан'},
      'cards': [
        null,
        {'mask': '4400••••1234'},
        {'mask': '4400123456781234'},
      ],
    });
    expect(account.name, 'Айжан');
    expect(account.cardsSummary, contains('4400••••1234'));
    expect(account.cardsSummary, isNot(contains('4400123456781234')));
  });
}
