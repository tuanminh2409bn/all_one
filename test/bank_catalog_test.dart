import 'package:flutter_test/flutter_test.dart';

import 'package:all_one/core/bank_catalog.dart';

void main() {
  test('institutions sharing a brand resolve to the same new logo', () {
    expect(BankCatalog.logoAsset('제주'), BankCatalog.logoAsset('신한'));
    expect(BankCatalog.logoAsset('부산'), BankCatalog.logoAsset('경남'));
    expect(BankCatalog.logoAsset('전북'), BankCatalog.logoAsset('광주'));
    expect(BankCatalog.logoAsset('토스증권'), BankCatalog.logoAsset('토스뱅크'));
  });

  test('all 48 supplied logos are mapped and old asset names are gone', () {
    expect(BankCatalog.logoAssets, hasLength(48));
    expect(BankCatalog.logoAssets.toSet(), hasLength(48));
    for (final asset in BankCatalog.logoAssets) {
      expect(asset, startsWith('assets/images/logo_'));
      expect(asset, isNot(contains('_transparent')));
      expect(asset, isNot(contains('/bank_')));
      expect(asset, isNot(contains('/security_')));
    }
    for (final code in BankCatalog.codes) {
      if (BankCatalog.tryLogoAsset(code) != null) {
        expect(BankCatalog.logoScale(code), greaterThan(1));
      }
    }
  });

  test('institutions missing from the supplied set use a safe fallback', () {
    for (final code in ['우체국', '국세', '지방세', '국고', '관세']) {
      expect(BankCatalog.tryLogoAsset(code), isNull);
      expect(BankCatalog.codes, contains(code));
    }
  });
}
