import 'package:flutter_test/flutter_test.dart';

import 'package:all_one/core/bank_catalog.dart';

void main() {
  test('Shinhan and Jeju share the same sharp logo and render scale', () {
    expect(BankCatalog.logoAsset('제주'), BankCatalog.logoAsset('신한'));
    expect(BankCatalog.logoScale('제주'), BankCatalog.logoScale('신한'));
  });

  test('every catalog entry resolves to a logo asset', () {
    for (final code in BankCatalog.codes) {
      expect(
        BankCatalog.logoAsset(code),
        startsWith('assets/images/'),
        reason: 'Missing logo mapping for $code',
      );
      expect(
        BankCatalog.logoTileColor(code) >> 24,
        0xFF,
        reason: 'Missing opaque rounded-square tile color for $code',
      );
    }
  });

  test('Toss uses its transparent mark on the shared blue tile', () {
    expect(BankCatalog.logoAsset('토스뱅크'), endsWith('security_toss.png'));
    expect(BankCatalog.usesWhiteLogo('토스뱅크'), isTrue);
    expect(BankCatalog.usesWhiteLogo('토스증권'), isTrue);
  });
}
