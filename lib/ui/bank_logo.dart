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
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: ClipRect(
          child: Transform.scale(
            scale: BankCatalog.logoScale(bankCode),
            child: Image.asset(
              BankCatalog.logoAsset(bankCode),
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }
}
