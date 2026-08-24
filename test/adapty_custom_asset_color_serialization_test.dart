import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptyCustomAsset color serialization', () {
    test('serializes solid colors as #RRGGBBAA', () {
      final cases = <Color, String>{
        const Color(0xFF0000FF): '#0000FFFF',
        const Color(0x80010203): '#01020380',
      };

      for (final MapEntry(key: color, value: expected) in cases.entries) {
        final asset = AdaptyCustomAsset.color(color: color);

        expect(asset.jsonValue['value'], expected);
      }
    });

    test('serializes linear gradient stop colors as #RRGGBBAA', () {
      final asset = AdaptyCustomAsset.linearGradient(
        gradient: const LinearGradient(
          colors: [Color(0xFF0000FF), Color(0x80010203)],
          stops: [0.25, 0.75],
        ),
      );

      final values = asset.jsonValue['values'] as List<dynamic>;
      final serializedColors = values
          .cast<Map<String, dynamic>>()
          .map((value) => value['color'])
          .toList();

      expect(serializedColors, ['#0000FFFF', '#01020380']);
    });
  });
}
