import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Custom linear gradient assets beyond plain `Alignment` points: directional and mixed alignments, non-finite
// values, and the `transform` and `tileMode` settings that flows ignore.

const _channel = MethodChannel('flutter.adapty.com/adapty');
const _colors = [Color(0xFF0000FF), Color(0x80010203)];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('directional and mixed alignments resolve left-to-right', () {
    test('AlignmentDirectional.centerStart -> centerEnd', () {
      expect(_points(AlignmentDirectional.centerStart, AlignmentDirectional.centerEnd), _isPoints(0, 0.5, 1, 0.5));
    });

    test('AlignmentDirectional.topStart -> bottomEnd', () {
      expect(_points(AlignmentDirectional.topStart, AlignmentDirectional.bottomEnd), _isPoints(0, 0, 1, 1));
    });

    test('AlignmentDirectional.topCenter -> bottomCenter', () {
      expect(_points(AlignmentDirectional.topCenter, AlignmentDirectional.bottomCenter), _isPoints(0.5, 0, 0.5, 1));
    });

    test('a mixed alignment from add() -> Alignment.bottomRight', () {
      final mixed = Alignment.topLeft.add(AlignmentDirectional.centerStart);
      expect(mixed, isNot(anyOf(isA<Alignment>(), isA<AlignmentDirectional>())));

      // x = -1 + (-1) = -2, so the start point lies outside the element, as Flutter itself would draw it.
      expect(_points(mixed, Alignment.bottomRight), _isPoints(-0.5, 0, 1, 1));
    });

    test('a mixed alignment from AlignmentGeometry.lerp() -> Alignment.centerRight', () {
      final lerped = AlignmentGeometry.lerp(Alignment.centerLeft, AlignmentDirectional.centerEnd, 0.5)!;
      expect(lerped, isNot(anyOf(isA<Alignment>(), isA<AlignmentDirectional>())));

      expect(_points(lerped, Alignment.centerRight), _isPoints(0.5, 0.5, 1, 0.5));
    });

    test('Alignment.topLeft -> AlignmentDirectional.bottomEnd', () {
      expect(_points(Alignment.topLeft, AlignmentDirectional.bottomEnd), _isPoints(0, 0, 1, 1));
    });

    test('AlignmentDirectional.topEnd -> Alignment.bottomLeft', () {
      expect(_points(AlignmentDirectional.topEnd, Alignment.bottomLeft), _isPoints(1, 0, 0, 1));
    });

    test('a directional gradient sends exactly what its left-to-right Alignment twin sends', () {
      final directional = _asset(
        const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: _colors,
        ),
      );
      final plain = _asset(const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _colors));

      expect(jsonEncode(directional.jsonValue), jsonEncode(plain.jsonValue));
    });
  });

  group('plain Alignment gradients send the same JSON as 4.1.0', () {
    const values = '"values":[{"color":"#0000FFFF","p":0.0},{"color":"#01020380","p":1.0}]';
    final snapshots = <String, (LinearGradient, String)>{
      'default centerLeft -> centerRight': (
        const LinearGradient(colors: _colors),
        '{"type":"linear-gradient",$values,"points":{"x0":0.0,"y0":0.5,"x1":1.0,"y1":0.5}}',
      ),
      'topLeft -> bottomRight': (
        const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _colors),
        '{"type":"linear-gradient",$values,"points":{"x0":0.0,"y0":0.0,"x1":1.0,"y1":1.0}}',
      ),
      'Alignment(-0.5, 0) -> Alignment(0.5, 0)': (
        const LinearGradient(begin: Alignment(-0.5, 0), end: Alignment(0.5, 0), colors: _colors),
        '{"type":"linear-gradient",$values,"points":{"x0":0.25,"y0":0.5,"x1":0.75,"y1":0.5}}',
      ),
      'FractionalOffset(0.25, 0.75) -> FractionalOffset(1, 0)': (
        const LinearGradient(begin: FractionalOffset(0.25, 0.75), end: FractionalOffset(1, 0), colors: _colors),
        '{"type":"linear-gradient",$values,"points":{"x0":0.25,"y0":0.75,"x1":1.0,"y1":0.0}}',
      ),
    };

    for (final MapEntry(key: name, value: (gradient, json)) in snapshots.entries) {
      test(name, () {
        expect(jsonEncode(_asset(gradient).jsonValue), json);
      });
    }
  });

  group('non-finite values are rejected', () {
    final nonFinite = <String, LinearGradient>{
      'a NaN stop': const LinearGradient(colors: _colors, stops: [0.0, double.nan]),
      'an Infinity stop': const LinearGradient(colors: _colors, stops: [0.0, double.infinity]),
      'a -Infinity stop': const LinearGradient(colors: _colors, stops: [double.negativeInfinity, 1.0]),
      'NaN in begin': const LinearGradient(begin: Alignment(double.nan, 0), colors: _colors),
      'Infinity in begin': const LinearGradient(begin: Alignment(0, double.infinity), colors: _colors),
      '-Infinity in end': const LinearGradient(end: Alignment(double.negativeInfinity, 0), colors: _colors),
      'NaN in end': const LinearGradient(end: Alignment(0, double.nan), colors: _colors),
      'Infinity in a directional alignment': const LinearGradient(
        begin: AlignmentDirectional(double.infinity, 0),
        colors: _colors,
      ),
    };

    for (final MapEntry(key: name, value: gradient) in nonFinite.entries) {
      test('jsonValue throws ArgumentError for $name', () {
        expect(() => _asset(gradient).jsonValue, throwsArgumentError);
      });
    }

    test('jsonValue still throws ArgumentError when stops and colors differ in length', () {
      expect(
        () => _asset(const LinearGradient(colors: _colors, stops: [0.0])).jsonValue,
        throwsA(
          isArgumentError.having((e) => e.message, 'message', 'Stops and colors arrays must have the same length'),
        ),
      );
    });
  });

  // At the default log level a warning is printed. The set of settings already warned about lives for the whole
  // test process and cannot be reset from here, so no two tests in this file use the same transform or tileMode.
  group('transform and tileMode are ignored with a one-time warning', () {
    final ignored = <String, (LinearGradient, String)>{
      'GradientRotation(pi / 4)': (
        const LinearGradient(colors: _colors, transform: GradientRotation(math.pi / 4)),
        'transform: GradientRotation',
      ),
      'a custom GradientTransform': (
        const LinearGradient(colors: _colors, transform: _CustomTransform()),
        'transform: _CustomTransform',
      ),
      'TileMode.repeated': (
        const LinearGradient(colors: _colors, tileMode: TileMode.repeated),
        'tileMode: TileMode.repeated',
      ),
      'TileMode.mirror': (
        const LinearGradient(colors: _colors, tileMode: TileMode.mirror),
        'tileMode: TileMode.mirror',
      ),
      'TileMode.decal': (const LinearGradient(colors: _colors, tileMode: TileMode.decal), 'tileMode: TileMode.decal'),
    };

    for (final MapEntry(key: name, value: (gradient, setting)) in ignored.entries) {
      test('$name logs one warning and sends the plain gradient', () async {
        final plainJson = jsonEncode(_asset(const LinearGradient(colors: _colors)).jsonValue);
        final asset = _asset(gradient);

        final sent = <String>[];
        final lines = await _printed(() {
          for (var i = 0; i < 3; i++) {
            sent.add(jsonEncode(asset.jsonValue));
          }
        });

        expect(sent, everyElement(plainJson));
        expect(lines, [_isWarning(setting)]);
      });
    }

    test('a repeat of the same setting does not log again, whatever gradient carries it', () async {
      final first = await _printed(
        () => _asset(LinearGradient(colors: _colors, transform: _RepeatedTransform())).jsonValue,
      );
      final again = await _printed(() {
        // New gradients with new transform instances, as a widget's build() would create them.
        _asset(LinearGradient(colors: _colors, transform: _RepeatedTransform())).jsonValue;
        _asset(
          LinearGradient(colors: const [Color(0xFFFFFFFF), Colors.black], transform: _RepeatedTransform()),
        ).jsonValue;
      });

      expect(first, [_isWarning('transform: _RepeatedTransform')]);
      expect(again, isEmpty);
    });

    testWidgets('the embedded view warns once across rebuilds, for a gradient created in build()', (tester) async {
      final host = GlobalKey<_HostState>();
      final lines = await _printed(() async {
        await tester.pumpWidget(
          _Host(
            key: host,
            assets: () => {'bg_gradient': _asset(LinearGradient(colors: _colors, transform: _PerBuildTransform()))},
          ),
        );
        for (var i = 0; i < 5; i++) {
          host.currentState!.rebuild();
          await tester.pump();
        }
      });

      expect(tester.takeException(), isNull);
      expect(lines, [_isWarning('transform: _PerBuildTransform')]);
    });

    test('a default LinearGradient logs nothing', () async {
      final lines = await _printed(() {
        _asset(const LinearGradient(colors: _colors)).jsonValue;
        _asset(const LinearGradient(colors: _colors, tileMode: TileMode.clamp)).jsonValue;
      });

      expect(lines, isEmpty);
    });
  });

  group('createFlowView', () {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;

    setUp(() {
      calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(_channel, (call) async {
        calls.add(call);
        return jsonEncode({
          'success': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
        });
      });
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(_channel, null);
    });

    test('sends a directional gradient to the native side', () async {
      final view = await AdaptyUI().createFlowView(
        flow: _flow(),
        customAssets: {
          'bg_gradient': _asset(
            const LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: _colors,
            ),
          ),
        },
      );

      expect(view.id, 'view-id');
      expect(calls, hasLength(1));
      expect(calls.single.method, 'adapty_ui_create_flow_view');

      final request = jsonDecode(calls.single.arguments as String) as Map<String, dynamic>;
      final asset = (request['custom_assets'] as List<dynamic>).single as Map<String, dynamic>;
      expect(asset['id'], 'bg_gradient');
      expect(asset['points'], _isPoints(0, 0.5, 1, 0.5));
    });

    test('fails with AdaptyError.wrongParam naming the asset when stops and colors differ in length', () async {
      await expectLater(
        AdaptyUI().createFlowView(
          flow: _flow(),
          customAssets: {
            'ok_color': const AdaptyCustomAsset.color(color: Color(0xFF00FF00)),
            'broken_gradient': _asset(const LinearGradient(colors: _colors, stops: [0.0])),
          },
        ),
        throwsA(
          isA<AdaptyError>()
              .having((error) => error.code, 'code', AdaptyErrorCode.wrongParam)
              .having(
                (error) => error.message,
                'message',
                allOf(contains('broken_gradient'), isNot(contains('ok_color'))),
              )
              .having((error) => error.detail, 'detail', contains('Stops and colors arrays must have the same length')),
        ),
      );

      expect(calls, isEmpty);
    });

    test('fails with AdaptyError.wrongParam naming the asset for a NaN stop', () async {
      await expectLater(
        AdaptyUI().createFlowView(
          flow: _flow(),
          customAssets: {
            'nan_gradient': _asset(const LinearGradient(colors: _colors, stops: [0.0, double.nan])),
          },
        ),
        throwsA(
          isA<AdaptyError>()
              .having((error) => error.code, 'code', AdaptyErrorCode.wrongParam)
              .having((error) => error.message, 'message', 'Failed to encode custom asset "nan_gradient"'),
        ),
      );

      expect(calls, isEmpty);
    });
  });

  // On the host neither Platform.isIOS nor Platform.isAndroid holds: the view builds its creation params and then
  // renders an empty SizedBox. When building the params throws, Flutter replaces the view with an ErrorWidget.
  group('AdaptyUIFlowPlatformView', () {
    Future<void> pumpFlowView(WidgetTester tester, LinearGradient gradient) =>
        tester.pumpWidget(AdaptyUIFlowPlatformView(flow: _flow(), customAssets: {'bg_gradient': _asset(gradient)}));

    final rendersEmptyBox = find.descendant(of: find.byType(AdaptyUIFlowPlatformView), matching: find.byType(SizedBox));

    testWidgets('builds with a plain gradient', (tester) async {
      await pumpFlowView(tester, const LinearGradient(colors: _colors));

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(rendersEmptyBox, findsOneWidget);
    });

    testWidgets('builds with a directional gradient', (tester) async {
      await pumpFlowView(
        tester,
        const LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: _colors,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(rendersEmptyBox, findsOneWidget);
    });

    testWidgets('builds with a mixed alignment gradient', (tester) async {
      await pumpFlowView(
        tester,
        LinearGradient(
          begin: Alignment.topLeft.add(AlignmentDirectional.centerStart),
          end: Alignment.bottomRight,
          colors: _colors,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(rendersEmptyBox, findsOneWidget);
    });

    testWidgets('still fails the build when stops and colors differ in length', (tester) async {
      await pumpFlowView(tester, const LinearGradient(colors: _colors, stops: [0.0]));

      expect(tester.takeException(), isArgumentError);
      expect(find.byType(ErrorWidget), findsOneWidget);
    });

    testWidgets('fails the build for a NaN stop', (tester) async {
      await pumpFlowView(tester, const LinearGradient(colors: _colors, stops: [0.0, double.nan]));

      expect(tester.takeException(), isArgumentError);
      expect(find.byType(ErrorWidget), findsOneWidget);
    });
  });
}

AdaptyCustomAsset _asset(LinearGradient gradient) => AdaptyCustomAsset.linearGradient(gradient: gradient);

Map<String, dynamic> _points(AlignmentGeometry begin, AlignmentGeometry end) =>
    _asset(LinearGradient(begin: begin, end: end, colors: _colors)).jsonValue['points'] as Map<String, dynamic>;

Matcher _isPoints(double x0, double y0, double x1, double y1) =>
    equals({'x0': closeTo(x0, 1e-9), 'y0': closeTo(y0, 1e-9), 'x1': closeTo(x1, 1e-9), 'y1': closeTo(y1, 1e-9)});

/// A line printed by `AdaptyLogger` at the warn level for an ignored gradient [setting].
Matcher _isWarning(String setting) => endsWith(
  '] - WARN: AdaptyCustomAsset.linearGradient($setting): flows do not support this setting, so it is ignored.',
);

/// Every line [body] prints.
Future<List<String>> _printed(FutureOr<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    () async => body(),
    zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => lines.add(line)),
  );
  return lines;
}

class _CustomTransform extends GradientTransform {
  const _CustomTransform();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => null;
}

/// Not const, so every instance is a distinct object.
class _RepeatedTransform extends GradientTransform {
  _RepeatedTransform();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => null;
}

/// Not const, so every build creates a distinct object.
class _PerBuildTransform extends GradientTransform {
  _PerBuildTransform();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) => null;
}

class _Host extends StatefulWidget {
  const _Host({super.key, required this.assets});

  final Map<String, AdaptyCustomAsset> Function() assets;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  void rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => AdaptyUIFlowPlatformView(flow: _flow(), customAssets: widget.assets());
}

AdaptyFlow _flow() => AdaptyFlowJSONBuilder.fromJsonValue({
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'Experiment',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'flow_id': 'flow-id',
  'flow_name': 'Flow',
  'variation_id': 'variation-id',
  'remote_configs': <dynamic>[],
  'variations': <dynamic>[],
  'ui_schema': {
    'layouts': [
      {'flow_layout_id': 'flow-layout-id'},
    ],
    'grids': <dynamic>[],
  },
  'response_created_at': 0,
});
