import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/message.dart';

void main() {
  group('sanitizeDisplayName', () {
    test('leaves a short, plain name untouched', () {
      expect(sanitizeDisplayName('Boris'), equals('Boris'));
    });

    test('trims leading and trailing whitespace', () {
      expect(sanitizeDisplayName('  Алиса  '), equals('Алиса'));
    });

    test('flattens an embedded newline to a space instead of merging '
        'the words it separated', () {
      expect(sanitizeDisplayName('Ali\nce'), equals('Ali ce'));
    });

    test('flattens other control characters (tab, NUL, DEL) to spaces', () {
      expect(sanitizeDisplayName('A\tb\x00c\x7fd'), equals('A b c d'));
    });

    test(
      'caps at kDisplayNameMaxLength Unicode code points, without '
      'splitting a surrogate pair',
      () {
        // 40 emoji, each a surrogate pair in UTF-16 (2 code units) but a
        // single rune/code point.
        final longName = '🐧' * 40;
        final result = sanitizeDisplayName(longName);
        expect(result.runes.length, equals(kDisplayNameMaxLength));
        expect(result, equals('🐧' * kDisplayNameMaxLength));
      },
    );

    test('is idempotent', () {
      const raw = '  Al\nice\x01!  ';
      final once = sanitizeDisplayName(raw);
      final twice = sanitizeDisplayName(once);
      expect(twice, equals(once));
    });

    test(
      'what is stored equals what encodeSystemEvent would carry — no '
      'silent truncation on top of an already-sanitized name',
      () {
        final longName = '🐧' * 40;
        final stored = sanitizeDisplayName(longName);

        final plaintext = encodeSystemEvent(SystemEventKind.joined, stored);
        final decoded = decodeSystemEvent(plaintext);

        expect(decoded!.name, equals(stored));
      },
    );
  });
}
