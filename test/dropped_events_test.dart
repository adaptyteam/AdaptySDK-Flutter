import 'dart:async';
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _Widget extends AdaptyUIFlowsEventsObserver {
  final errors = <AdaptyError>[];

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) => errors.add(error);
}

Map<String, dynamic> _view(String id) => {'id': id, 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final usedIds = <String>{};

  /// Delivers the event and returns the decoded reply the native side gets.
  Future<Object?> sendEvent(String method, Map<String, dynamic> arguments) async {
    ByteData? reply;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, jsonEncode(arguments))),
      (data) => reply = data,
    );
    await pumpEventQueue();
    return const StandardMethodCodec().decodeEnvelope(reply!);
  }

  Future<List<String>> capturingLogs(Future<void> Function() body) async {
    final logs = <String>[];
    await runZoned(body, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));
    return logs;
  }

  setUp(() {
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      (call) async => jsonEncode({'success': true}),
    );
  });

  tearDown(() {
    for (final id in usedIds) {
      AdaptyUI().unregisterFlowEventsListener(id);
    }
    usedIds.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('an unknown event is logged as a warning and ignored', () async {
    Object? reply = 'not delivered';

    final logs = await capturingLogs(() async {
      reply = await sendEvent('not_a_known_event', {'view': _view('view-1')});
    });

    expect(reply, isNull);
    expect(logs, [
      allOf(contains(' - WARN: '), endsWith('Adapty received an unknown event "not_a_known_event" and ignored it')),
    ]);
  });

  test('the 17th pending embedded view error evicts the oldest with a warning', () async {
    final logs = await capturingLogs(() async {
      for (var i = 200; i <= 216; i++) {
        usedIds.add('flutter_native_$i');
        await sendEvent('flow_view_did_receive_error', {
          'view': _view('flutter_native_$i'),
          'error': {'adapty_code': 4001, 'message': 'the platform is not supported'},
        });
      }
    });

    final oldest = _Widget();
    final oldestKept = _Widget();
    AdaptyUI().registerFlowEventsListener(oldest, 'flutter_native_200');
    AdaptyUI().registerFlowEventsListener(oldestKept, 'flutter_native_201');

    expect(logs, [
      allOf(
        contains(' - WARN: '),
        endsWith(
          'Adapty dropped an error of the embedded flow view flutter_native_200: '
          'at most 16 errors of embedded flow views without a widget are kept',
        ),
      ),
    ]);
    expect(oldest.errors, isEmpty);
    expect(oldestKept.errors, hasLength(1));
  });
}
