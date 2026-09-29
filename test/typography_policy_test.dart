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

  test('only reference account metadata may use a weight below w500', () {
    final forbiddenPatterns = <RegExp>[
      RegExp(r'FontWeight\.(?:w100|w200|w300|w400|normal)\b'),
      RegExp(r'\bfontWeight\s*:\s*[1-4]00\b'),
      RegExp(r'\bweight\s*:\s*[1-4]00\b'),
      RegExp(r'''FontVariation\(\s*['"]wght['"]\s*,\s*[1-4]00(?:\.0)?\s*\)'''),
    ];
    final violations = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      var source = entity.readAsStringSync();
      if (entity.path == 'lib/ui/account_details_screen.dart') {
        // The four user-selected reference labels intentionally use Regular.
        final referenceStyle = RegExp(
          r'const _detailsReferenceRegular = TextStyle\([\s\S]*?\n\);',
        );
        final match = referenceStyle.firstMatch(source);
        expect(match, isNotNull);
        expect(match!.group(0), contains("fontFamily: 'NotoSansKRRegular'"));
        expect(match.group(0), contains('fontWeight: FontWeight.w400'));
        source = source.replaceRange(
          match.start,
          match.end,
          '\n' * '\n'.allMatches(match.group(0)!).length,
        );
      }
      final lines = source.split('\n');
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
          'Typography outside the reference metadata style must use w500 or above.\n'
          '${violations.join('\n')}',
    );
  });
}
