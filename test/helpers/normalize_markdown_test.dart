import 'package:flutter_test/flutter_test.dart';
import 'package:inter_knot/helpers/normalize_markdown.dart';

void main() {
  group('normalizeMarkdown', () {
    test('preserves blank lines from stored markdown', () {
      const input = 'first line\n\nsecond paragraph\n\n\nthird paragraph';

      expect(normalizeMarkdown(input), input);
    });

    test('still fixes malformed markdown image wrappers', () {
      const input = '![cover]([url](https://example.com/image.png)))';

      expect(
        normalizeMarkdown(input),
        '![cover](https://example.com/image.png)',
      );
    });
  });
}
