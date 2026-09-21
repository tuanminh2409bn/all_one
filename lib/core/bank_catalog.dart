class BankCatalogEntry {
  const BankCatalogEntry({required this.code, required this.assetName});

  final String code;
  final String? assetName;
}

abstract final class BankCatalog {
  // The supplied PNGs share a 1254×1254 white canvas, but their colored
  // rounded-square artwork has different bounds. These scales normalize the
  // visible tile to roughly 82% of BankLogo's frame on every screen.
  static const _logoScalesByAsset = <String, double>{
    'logo_bank_of_america.png': 1.63,
    'logo_bank_of_china.png': 1.40,
    'logo_bnk.png': 1.79,
    'logo_bnp_paribas.png': 1.44,
    'logo_bookook_securities.png': 1.38,
    'logo_cape_securities.png': 1.57,
    'logo_china_construction_bank.png': 1.49,
    'logo_citi.png': 1.80,
    'logo_credit_union.png': 1.66,
    'logo_daishin_securities.png': 1.49,
    'logo_daol_securities.png': 1.38,
    'logo_db_financial.png': 1.47,
    'logo_deutsche_bank.png': 1.73,
    'logo_eugene_securities.png': 1.60,
    'logo_forestry_cooperative.png': 1.74,
    'logo_gwangju_jeonbuk.png': 1.81,
    'logo_hana.png': 1.35,
    'logo_hanwha_securities.png': 1.44,
    'logo_hsbc.png': 1.40,
    'logo_hyundai_motor_securities.png': 1.75,
    'logo_ibk.png': 1.54,
    'logo_icbc.png': 1.40,
    'logo_im.png': 1.46,
    'logo_jpmorgan.png': 1.44,
    'logo_kakao_bank.png': 1.44,
    'logo_kakao_pay_securities.png': 1.58,
    'logo_kb.png': 1.55,
    'logo_kbank.png': 1.25,
    'logo_kdb.png': 1.75,
    'logo_kiwoom_securities.png': 1.77,
    'logo_korea_investment_securities.png': 1.65,
    'logo_kyobo_securities.png': 1.63,
    'logo_ls_securities.png': 1.61,
    'logo_meritz_securities.png': 1.59,
    'logo_mirae_asset_securities.png': 1.43,
    'logo_nh.png': 2.20,
    'logo_saemaul.png': 1.65,
    'logo_samsung_securities.png': 1.45,
    'logo_sangsangin_securities.png': 1.33,
    'logo_savings_bank.png': 1.53,
    'logo_sc_first_bank.png': 1.48,
    'logo_shinhan.png': 1.48,
    'logo_shinyoung_securities.png': 1.59,
    'logo_sk_securities.png': 1.57,
    'logo_suhyup.png': 1.58,
    'logo_toss.png': 1.52,
    'logo_woori.png': 1.75,
    'logo_yuanta_securities.png': 1.63,
  };

  static const bankEntries = <BankCatalogEntry>[
    BankCatalogEntry(code: '신한', assetName: 'logo_shinhan.png'),
    BankCatalogEntry(code: '제주', assetName: 'logo_shinhan.png'),
    BankCatalogEntry(code: '국민', assetName: 'logo_kb.png'),
    BankCatalogEntry(code: '기업', assetName: 'logo_ibk.png'),
    BankCatalogEntry(code: '농협', assetName: 'logo_nh.png'),
    BankCatalogEntry(code: '산업', assetName: 'logo_kdb.png'),
    BankCatalogEntry(code: '수협', assetName: 'logo_suhyup.png'),
    BankCatalogEntry(code: '신협', assetName: 'logo_credit_union.png'),
    BankCatalogEntry(code: '우리', assetName: 'logo_woori.png'),
    BankCatalogEntry(code: '하나', assetName: 'logo_hana.png'),
    BankCatalogEntry(code: '한국씨티', assetName: 'logo_citi.png'),
    BankCatalogEntry(code: '카카오뱅크', assetName: 'logo_kakao_bank.png'),
    BankCatalogEntry(code: '케이뱅크', assetName: 'logo_kbank.png'),
    BankCatalogEntry(code: '토스뱅크', assetName: 'logo_toss.png'),
    BankCatalogEntry(code: '경남', assetName: 'logo_bnk.png'),
    BankCatalogEntry(code: '광주', assetName: 'logo_gwangju_jeonbuk.png'),
    BankCatalogEntry(code: '아이엠뱅크(대구)', assetName: 'logo_im.png'),
    BankCatalogEntry(code: '부산', assetName: 'logo_bnk.png'),
    BankCatalogEntry(code: '전북', assetName: 'logo_gwangju_jeonbuk.png'),
    BankCatalogEntry(code: '회원수협', assetName: 'logo_suhyup.png'),
    BankCatalogEntry(code: '새마을', assetName: 'logo_saemaul.png'),
    BankCatalogEntry(code: '우체국', assetName: null),
    BankCatalogEntry(code: '저축은행', assetName: 'logo_savings_bank.png'),
    BankCatalogEntry(code: '지역농·축협', assetName: 'logo_nh.png'),
    BankCatalogEntry(code: '도이치', assetName: 'logo_deutsche_bank.png'),
    BankCatalogEntry(code: '중국', assetName: 'logo_bank_of_china.png'),
    BankCatalogEntry(
      code: '중국건설',
      assetName: 'logo_china_construction_bank.png',
    ),
    BankCatalogEntry(code: '중국공상', assetName: 'logo_icbc.png'),
    BankCatalogEntry(code: 'BNP파리바', assetName: 'logo_bnp_paribas.png'),
    BankCatalogEntry(code: 'BOA', assetName: 'logo_bank_of_america.png'),
    BankCatalogEntry(code: 'HSBC', assetName: 'logo_hsbc.png'),
    BankCatalogEntry(code: 'JP모간', assetName: 'logo_jpmorgan.png'),
    BankCatalogEntry(code: 'SC', assetName: 'logo_sc_first_bank.png'),
    BankCatalogEntry(code: '산림조합', assetName: 'logo_forestry_cooperative.png'),
    BankCatalogEntry(code: '국세', assetName: null),
    BankCatalogEntry(code: '지방세', assetName: null),
    BankCatalogEntry(code: '국고', assetName: null),
    BankCatalogEntry(code: '관세', assetName: null),
  ];

  static const securitiesEntries = <BankCatalogEntry>[
    BankCatalogEntry(code: 'NH투자증권', assetName: 'logo_nh.png'),
    BankCatalogEntry(code: '교보증권', assetName: 'logo_kyobo_securities.png'),
    BankCatalogEntry(code: '다올투자증권', assetName: 'logo_daol_securities.png'),
    BankCatalogEntry(code: '대신증권', assetName: 'logo_daishin_securities.png'),
    BankCatalogEntry(code: '메리츠증권', assetName: 'logo_meritz_securities.png'),
    BankCatalogEntry(
      code: '미래에셋증권',
      assetName: 'logo_mirae_asset_securities.png',
    ),
    BankCatalogEntry(code: '부국증권', assetName: 'logo_bookook_securities.png'),
    BankCatalogEntry(code: '삼성증권', assetName: 'logo_samsung_securities.png'),
    BankCatalogEntry(
      code: '상상인증권',
      assetName: 'logo_sangsangin_securities.png',
    ),
    BankCatalogEntry(code: '신영증권', assetName: 'logo_shinyoung_securities.png'),
    BankCatalogEntry(code: '신한투자증권', assetName: 'logo_shinhan.png'),
    BankCatalogEntry(code: '에스케이증권', assetName: 'logo_sk_securities.png'),
    BankCatalogEntry(code: '유안타증권', assetName: 'logo_yuanta_securities.png'),
    BankCatalogEntry(code: '유진투자증권', assetName: 'logo_eugene_securities.png'),
    BankCatalogEntry(code: 'LS증권', assetName: 'logo_ls_securities.png'),
    BankCatalogEntry(
      code: '카카오페이증권',
      assetName: 'logo_kakao_pay_securities.png',
    ),
    BankCatalogEntry(code: '케이프투자증권', assetName: 'logo_cape_securities.png'),
    BankCatalogEntry(code: '키움증권', assetName: 'logo_kiwoom_securities.png'),
    BankCatalogEntry(code: '토스증권', assetName: 'logo_toss.png'),
    BankCatalogEntry(code: '하나증권', assetName: 'logo_hana.png'),
    BankCatalogEntry(code: '아이엠증권', assetName: 'logo_im.png'),
    BankCatalogEntry(
      code: '한국투자증권',
      assetName: 'logo_korea_investment_securities.png',
    ),
    BankCatalogEntry(code: '한화투자증권', assetName: 'logo_hanwha_securities.png'),
    BankCatalogEntry(
      code: '현대차증권',
      assetName: 'logo_hyundai_motor_securities.png',
    ),
    BankCatalogEntry(code: '우리투자증권', assetName: 'logo_woori.png'),
    BankCatalogEntry(code: 'BNK증권', assetName: 'logo_bnk.png'),
    BankCatalogEntry(code: 'DB금융투자', assetName: 'logo_db_financial.png'),
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

  static List<String> get logoAssets => List.unmodifiable(
    entries
        .map((entry) => entry.assetName)
        .whereType<String>()
        .map((assetName) => 'assets/images/$assetName')
        .toSet(),
  );

  static String? tryLogoAsset(String code) {
    for (final entry in entries) {
      if (entry.code != code) continue;
      final assetName = entry.assetName;
      return assetName == null ? null : 'assets/images/$assetName';
    }
    return null;
  }

  static String logoAsset(String code) {
    final asset = tryLogoAsset(code);
    if (asset != null) return asset;
    throw ArgumentError.value(code, 'code', 'Ngân hàng chưa có logo ảnh');
  }

  static double logoScale(String code) {
    final asset = tryLogoAsset(code);
    if (asset == null) return 1;
    return _logoScalesByAsset[asset.split('/').last] ?? 1;
  }
}
