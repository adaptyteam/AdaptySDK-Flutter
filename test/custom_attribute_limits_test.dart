/// The custom attributes a profile update accepts: a string value of 1 to 50 characters, a key of up to 30 letters,
/// digits, dashes, points and underscores, and no more than 30 attributes with a value. Anything else fails at once
/// with a wrong parameter, before the update goes anywhere.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

const _valueMessage = 'The value must not be empty and not more than 50 characters.';
const _keyMessage =
    'The key must be string not more than 30 characters. Only letters, numbers, dashes, points and underscores allowed';
const _countMessage = 'The total number of custom attributes must be no more than 30';

Matcher _wrongParam(String message) => throwsA(
  isA<AdaptyError>()
      .having((e) => e.code, 'code', AdaptyErrorCode.wrongParam)
      .having((e) => e.message, 'message', message)
      .having((e) => e.detail, 'detail', 'AdaptyError.wrongParam($message)'),
);

/// A builder with [count] string attributes, `key_1` to `key_<count>`.
AdaptyProfileParametersBuilder _withAttributes(int count) {
  final builder = AdaptyProfileParametersBuilder();
  for (var i = 1; i <= count; i++) {
    builder.setCustomStringAttribute('value', 'key_$i');
  }
  return builder;
}

void main() {
  group('a string value', () {
    test('of 50 characters is accepted', () {
      final builder = AdaptyProfileParametersBuilder()..setCustomStringAttribute('v' * 50, 'tier');

      expect(builder.build().customAttributes, {'tier': 'v' * 50});
    });

    test('of 51 characters fails', () {
      expect(
        () => AdaptyProfileParametersBuilder().setCustomStringAttribute('v' * 51, 'tier'),
        _wrongParam(_valueMessage),
      );
    });

    test('that is empty fails', () {
      expect(() => AdaptyProfileParametersBuilder().setCustomStringAttribute('', 'tier'), _wrongParam(_valueMessage));
    });
  });

  group('a key', () {
    test('of 30 characters is accepted for a string, a number and a removal', () {
      final key = 'k' * 30;
      final builder = AdaptyProfileParametersBuilder()
        ..setCustomStringAttribute('gold', key)
        ..setCustomDoubleAttribute(1.5, '${'d' * 29}1')
        ..removeCustomAttribute('${'r' * 29}1');

      expect(builder.build().customAttributes, {key: 'gold', '${'d' * 29}1': 1.5, '${'r' * 29}1': null});
    });

    test('of letters, digits, a dash, a point and an underscore is accepted', () {
      final builder = AdaptyProfileParametersBuilder()..setCustomStringAttribute('gold', 'Tier-2.level_A');

      expect(builder.build().customAttributes, {'Tier-2.level_A': 'gold'});
    });

    test('of 31 characters fails for a string, a number and a removal', () {
      final key = 'k' * 31;

      expect(() => AdaptyProfileParametersBuilder().setCustomStringAttribute('gold', key), _wrongParam(_keyMessage));
      expect(() => AdaptyProfileParametersBuilder().setCustomDoubleAttribute(1.5, key), _wrongParam(_keyMessage));
      expect(() => AdaptyProfileParametersBuilder().removeCustomAttribute(key), _wrongParam(_keyMessage));
    });

    test('with a space fails for a string, a number and a removal', () {
      expect(
        () => AdaptyProfileParametersBuilder().setCustomStringAttribute('gold', 'loyalty tier'),
        _wrongParam(_keyMessage),
      );
      expect(
        () => AdaptyProfileParametersBuilder().setCustomDoubleAttribute(1.5, 'loyalty tier'),
        _wrongParam(_keyMessage),
      );
      expect(() => AdaptyProfileParametersBuilder().removeCustomAttribute('loyalty tier'), _wrongParam(_keyMessage));
    });

    test('that is empty fails', () {
      expect(() => AdaptyProfileParametersBuilder().setCustomStringAttribute('gold', ''), _wrongParam(_keyMessage));
    });
  });

  group('the number of attributes', () {
    test('the 30th attribute is accepted', () {
      final builder = _withAttributes(30);

      expect(builder.build().customAttributes, hasLength(30));
    });

    test('the 31st attribute fails, a string or a number', () {
      expect(() => _withAttributes(30).setCustomStringAttribute('value', 'key_31'), _wrongParam(_countMessage));
      expect(() => _withAttributes(30).setCustomDoubleAttribute(1.5, 'key_31'), _wrongParam(_countMessage));
    });

    test('a new value for a key already set does not count as another attribute', () {
      final builder = _withAttributes(30)..setCustomStringAttribute('other', 'key_30');

      expect(builder.build().customAttributes, hasLength(30));
      expect(builder.build().customAttributes['key_30'], 'other');
    });

    test('a removal does not count: it is accepted over 30 attributes and frees a place', () {
      final builder = _withAttributes(30)..removeCustomAttribute('key_31');
      expect(builder.build().customAttributes, hasLength(31));

      builder
        ..removeCustomAttribute('key_1')
        ..setCustomStringAttribute('value', 'key_32');

      expect(builder.build().customAttributes['key_1'], isNull);
      expect(builder.build().customAttributes['key_32'], 'value');
    });
  });
}
