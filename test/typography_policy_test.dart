import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the default w500 family uses the static Medium font', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(pubspec, contains('assets/fonts/NotoSansKR-Medium.otf'));
    expect(pubspec, contains('family: NotoSansKRMedium'));
    expect(pubspec, isNot(contains('assets/fonts/NotoSansKR.ttf')));
    expect(File('assets/fonts/NotoSansKR-Medium.otf').existsSync(), isTrue);
  });

  test('production Dart code never requests a weight below w500', () {
    final forbiddenPatterns = <RegExp>[
      RegExp(r'FontWeight\.(?:w100|w200|w300|w400|normal)\b'),
      RegExp(r'\bfontWeight\s*:\s*[1-4]00\b'),
      RegExp(r'\bweight\s*:\s*[1-4]00\b'),
      RegExp(r'''FontVariation\(\s*['"]wght['"]\s*,\s*[1-4]00(?:\.0)?\s*\)'''),
    ];
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        final line = lines[index];
        if (forbiddenPatterns.any((pattern) => pattern.hasMatch(line))) {
          violations.add('${entity.path}:${index + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'All production typography and weighted icons must use w500 or above.\n'
          '${violations.join('\n')}',
    );
  });
}
