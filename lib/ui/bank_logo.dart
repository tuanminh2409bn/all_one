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
    final scaledSize = size * BankCatalog.logoScale(bankCode);
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        key: Key('bank-logo-frame-$bankCode'),
        borderRadius: BorderRadius.circular(size * .28),
        clipBehavior: Clip.antiAlias,
        child: ColoredBox(
          key: Key('bank-logo-tile-$bankCode'),
          color: Color(BankCatalog.logoTileColor(bankCode)),
          child: OverflowBox(
            minWidth: scaledSize,
            maxWidth: scaledSize,
            minHeight: scaledSize,
            maxHeight: scaledSize,
            child: SizedBox.square(
              dimension: scaledSize,
              child: Image.asset(
                BankCatalog.logoAsset(bankCode),
                fit: BoxFit.contain,
                color: BankCatalog.usesWhiteLogo(bankCode)
                    ? Colors.white
                    : null,
                colorBlendMode: BankCatalog.usesWhiteLogo(bankCode)
                    ? BlendMode.srcIn
                    : null,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
