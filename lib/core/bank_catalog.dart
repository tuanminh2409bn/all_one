class BankCatalogEntry {
  const BankCatalogEntry({required this.code, required this.assetName});

  final String code;
  final String assetName;
}

abstract final class BankCatalog {
  static const _logoScales = <String, double>{
    // Shinhan and Jeju use the same clean emblem. Keep their rendered
    // diameter aligned with the other banks instead of scaling either source
    // independently.
    '신한': .94,
    '제주': .94,
    '국민': 1.41,
    '기업': 1.82,
    '농협': 1.85,
    '산업': 1.53,
    '수협': 1.32,
    '신협': 1.46,
    '우리': 1.78,
    '하나': 1.41,
    '한국씨티': 1.47,
    '카카오뱅크': 1.04,
    '케이뱅크': 1.75,
    '토스뱅크': 1.71,
    '경남': 1.61,
    '광주': 1.56,
    '아이엠뱅크(대구)': 1.38,
    '부산': 1.61,
    '전북': 1.56,
    '회원수협': 1.51,
    '새마을': 1.34,
    '우체국': 1.16,
    '저축은행': 1.56,
    '지역농·축협': 1.46,
    '도이치': 1.57,
    '중국': 1.59,
    '중국건설': 1.56,
    '중국공상': 1.31,
    'BNP파리바': 1.74,
    'BOA': 1.81,
    'HSBC': 1.62,
    'JP모간': 1.42,
    'SC': 1.62,
    '산림조합': 1.32,
    '국세': 1.74,
    '지방세': 1.74,
    '국고': 1.74,
    '관세': 1.74,
    '신한투자증권': 1.76,
    '교보증권': 1.23,
    '다올투자증권': 1.89,
    '대신증권': 1.59,
    '미래에셋증권': 1.51,
    '삼성증권': 1.84,
    '상상인증권': 1.53,
    '신영증권': 1.61,
    '유안타증권': 1.83,
    '카카오페이증권': 1.76,
    '케이프투자증권': 1.53,
    '키움증권': 1.72,
    '토스증권': 2.20,
    '하나증권': 1.14,
    '한국투자증권': 1.53,
    '한화투자증권': 1.34,
    '현대차증권': 1.68,
    'DB금융투자': 1.71,
  };

  static const bankEntries = <BankCatalogEntry>[
    BankCatalogEntry(code: '신한', assetName: 'bank_shinhan_transparent.png'),
    BankCatalogEntry(code: '제주', assetName: 'bank_shinhan_transparent.png'),
    BankCatalogEntry(code: '국민', assetName: 'bank_kb_transparent.png'),
    BankCatalogEntry(code: '기업', assetName: 'bank_ibk_transparent.png'),
    BankCatalogEntry(code: '농협', assetName: 'bank_nh_transparent.png'),
    BankCatalogEntry(code: '산업', assetName: 'bank_kdb_transparent.png'),
    BankCatalogEntry(code: '수협', assetName: 'bank_suhyup_transparent.png'),
    BankCatalogEntry(code: '신협', assetName: 'bank_shinhyup_transparent.png'),
    BankCatalogEntry(code: '우리', assetName: 'bank_woori_transparent.png'),
    BankCatalogEntry(code: '하나', assetName: 'bank_hana_transparent.png'),
    BankCatalogEntry(code: '한국씨티', assetName: 'bank_citi_transparent.png'),
    BankCatalogEntry(code: '카카오뱅크', assetName: 'bank_kakao_transparent.png'),
    BankCatalogEntry(code: '케이뱅크', assetName: 'bank_kbank_transparent.png'),
    BankCatalogEntry(code: '토스뱅크', assetName: 'bank_toss_transparent.png'),
    BankCatalogEntry(code: '경남', assetName: 'bank_kyongnam_transparent.png'),
    BankCatalogEntry(code: '광주', assetName: 'bank_gwangju_transparent.png'),
    BankCatalogEntry(code: '아이엠뱅크(대구)', assetName: 'bank_im_transparent.png'),
    BankCatalogEntry(code: '부산', assetName: 'bank_busan_transparent.png'),
    BankCatalogEntry(code: '전북', assetName: 'bank_jeonbuk_transparent.png'),
    BankCatalogEntry(
      code: '회원수협',
      assetName: 'bank_membersuhyup_transparent.png',
    ),
    BankCatalogEntry(code: '새마을', assetName: 'bank_saemaul_transparent.png'),
    BankCatalogEntry(code: '우체국', assetName: 'bank_post_transparent.png'),
    BankCatalogEntry(code: '저축은행', assetName: 'bank_savings_transparent.png'),
    BankCatalogEntry(code: '지역농·축협', assetName: 'bank_localnh_transparent.png'),
    BankCatalogEntry(code: '도이치', assetName: 'bank_deutsche_transparent.png'),
    BankCatalogEntry(code: '중국', assetName: 'bank_china_transparent.png'),
    BankCatalogEntry(code: '중국건설', assetName: 'bank_ccb_transparent.png'),
    BankCatalogEntry(code: '중국공상', assetName: 'bank_icbc_transparent.png'),
    BankCatalogEntry(code: 'BNP파리바', assetName: 'bank_bnp_transparent.png'),
    BankCatalogEntry(code: 'BOA', assetName: 'bank_boa_transparent.png'),
    BankCatalogEntry(code: 'HSBC', assetName: 'bank_hsbc_transparent.png'),
    BankCatalogEntry(code: 'JP모간', assetName: 'bank_jpmorgan_transparent.png'),
    BankCatalogEntry(code: 'SC', assetName: 'bank_sc_transparent.png'),
    BankCatalogEntry(code: '산림조합', assetName: 'bank_forestry_transparent.png'),
    BankCatalogEntry(code: '국세', assetName: 'bank_nationaltax_transparent.png'),
    BankCatalogEntry(code: '지방세', assetName: 'bank_localtax_transparent.png'),
    BankCatalogEntry(code: '국고', assetName: 'bank_treasury_transparent.png'),
    BankCatalogEntry(code: '관세', assetName: 'bank_customs_transparent.png'),
  ];

  static const securitiesEntries = <BankCatalogEntry>[
    BankCatalogEntry(code: '신한투자증권', assetName: 'security_shinhan.png'),
    BankCatalogEntry(code: '교보증권', assetName: 'security_kyobo.png'),
    BankCatalogEntry(code: '다올투자증권', assetName: 'security_daol.png'),
    BankCatalogEntry(code: '대신증권', assetName: 'security_daishin.png'),
    BankCatalogEntry(code: '미래에셋증권', assetName: 'security_mirae_asset.png'),
    BankCatalogEntry(code: '삼성증권', assetName: 'security_samsung.png'),
    BankCatalogEntry(code: '상상인증권', assetName: 'security_sangsangin.png'),
    BankCatalogEntry(code: '신영증권', assetName: 'security_shinyoung.png'),
    BankCatalogEntry(code: '유안타증권', assetName: 'security_yuanta.png'),
    BankCatalogEntry(code: '카카오페이증권', assetName: 'security_kakao_pay.png'),
    BankCatalogEntry(code: '케이프투자증권', assetName: 'security_cape.png'),
    BankCatalogEntry(code: '키움증권', assetName: 'security_kiwoom.png'),
    BankCatalogEntry(code: '토스증권', assetName: 'security_toss.png'),
    BankCatalogEntry(code: '하나증권', assetName: 'security_hana.png'),
    BankCatalogEntry(
      code: '한국투자증권',
      assetName: 'security_korea_investment.png',
    ),
    BankCatalogEntry(code: '한화투자증권', assetName: 'security_hanwha.png'),
    BankCatalogEntry(code: '현대차증권', assetName: 'security_hyundai_motor.png'),
    BankCatalogEntry(code: 'DB금융투자', assetName: 'security_db_financial.png'),
  ];

  static const entries = <BankCatalogEntry>[
    ...bankEntries,
    ...securitiesEntries,
  ];

  static List<String> get bankCodes =>
      List.unmodifiable(bankEntries.map((entry) => entry.code));

  static List<String> get securitiesCodes =>
      List.unmodifiable(securitiesEntries.map((entry) => entry.code));

  static List<String> get codes =>
      List.unmodifiable(entries.map((entry) => entry.code));

  static String? tryLogoAsset(String code) {
    for (final entry in entries) {
      if (entry.code == code) return 'assets/images/${entry.assetName}';
    }
    return null;
  }

  static String logoAsset(String code) {
    final asset = tryLogoAsset(code);
    if (asset != null) return asset;
    throw ArgumentError.value(code, 'code', 'Ngân hàng chưa có logo');
  }

  static double logoScale(String code) => _logoScales[code] ?? 1;
}
