import 'package:flutter/material.dart';

import '../core/bank_catalog.dart';

abstract final class BankLogoSize {
  static const double account = 58;
  static const double picker = 50;
  static const double sourceAccount = 54;
  static const double suggestion = 24;
}

class BankLogo extends StatelessWidget {
  const BankLogo({super.key, required this.bankCode, required this.size});

  final String bankCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = BankCatalog.tryLogoAsset(bankCode);
    final scaledSize = size * BankCatalog.logoScale(bankCode);
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        key: Key('bank-logo-frame-$bankCode'),
        borderRadius: BorderRadius.circular(size * .28),
        clipBehavior: Clip.antiAlias,
        child: asset == null
            ? _FallbackBankLogo(bankCode: bankCode, size: size)
            : OverflowBox(
                minWidth: scaledSize,
                maxWidth: scaledSize,
                minHeight: scaledSize,
                maxHeight: scaledSize,
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  cacheWidth: 256,
                  cacheHeight: 256,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                  gaplessPlayback: true,
                ),
              ),
      ),
    );
  }
}

class _FallbackBankLogo extends StatelessWidget {
  const _FallbackBankLogo({required this.bankCode, required this.size});

  final String bankCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isPostOffice = bankCode == '우체국';
    return ColoredBox(
      key: Key('bank-logo-fallback-$bankCode'),
      color: isPostOffice ? const Color(0xFFEF3B32) : const Color(0xFFF2F4F6),
      child: Icon(
        isPostOffice
            ? Icons.local_post_office_rounded
            : Icons.account_balance_rounded,
        color: isPostOffice ? Colors.white : const Color(0xFF2464AA),
        size: size * .58,
      ),
    );
  }
}
