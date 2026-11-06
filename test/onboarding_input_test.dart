// ignore_for_file: deprecated_member_use
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _Observer extends AdaptyUIOnboardingsEventsObserver {
  final received = <AdaptyOnboardingsStateUpdatedParams>[];

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {
    received.add(params);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Observer observer;

  /// Delivers an input as the native side does, so the raw JSON goes through `jsonDecode`
  /// and a failed decoding is handled by the channel handler.
  Future<void> deliverInput(String inputJson) {
    final arguments = '{'
        '"view":{"id":"view-id","placement_id":"placement-id","variation_id":"variation-id"},'
        '"meta":{"onboarding_id":"onboarding-id","screen_cid":"screen-id","screen_index":0,"total_screens":1},'
        '"action":{"element_id":"element-id","element_type":"input","value":$inputJson}'
        '}';

    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('onboarding_on_state_updated_action', arguments)),
      (_) {},
    );
  }

  Future<AdaptyOnboardingsInput> receivedInput(String inputJson) async {
    observer.received.clear();
    await deliverInput(inputJson);

    expect(observer.received, hasLength(1), reason: inputJson);
    return (observer.received.single as AdaptyOnboardingsInputParams).input;
  }

  setUp(() {
    observer = _Observer();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    AdaptyUI().setOnboardingsEventsObserver(observer);
  });

  tearDown(() {
    AdaptyUI().setOnboardingsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a text input arrives as a text input', () async {
    expect(
      await receivedInput('{"type":"text","value":"QA"}'),
      isA<AdaptyOnboardingsTextInput>().having((input) => input.value, 'value', 'QA'),
    );
  });

  test('an email input arrives as an email input', () async {
    expect(
      await receivedInput('{"type":"email","value":"qa@example.com"}'),
      isA<AdaptyOnboardingsEmailInput>().having((input) => input.value, 'value', 'qa@example.com'),
    );
  });

  // Android writes a whole number as 25.0 and iOS as 25, which jsonDecode reads as double and int.
  test('a number input arrives as a number input in either native shape', () async {
    for (final (json, expected) in [('25.0', 25.0), ('25', 25.0), ('25.5', 25.5), ('1.0E7', 1e7), ('1e+16', 1e16)]) {
      expect(
        await receivedInput('{"type":"number","value":$json}'),
        isA<AdaptyOnboardingsNumberInput>().having((input) => input.value, 'value', expected),
        reason: json,
      );
    }
  });

  test('an input outside the contract does not reach the observer', () async {
    for (final json in [
      '{"type":"phone","value":"1"}',
      '{"value":"1"}',
      '{"type":"text"}',
      '{"type":"text","value":1}',
      '{"type":"number","value":"25"}',
    ]) {
      await deliverInput(json);
      expect(observer.received, isEmpty, reason: json);
    }
  });

  test('toString names the input type and its value', () async {
    for (final (json, expected) in [
      ('{"type":"text","value":"QA"}', 'AdaptyOnboardingsTextInput(value: QA)'),
      ('{"type":"email","value":"qa@example.com"}', 'AdaptyOnboardingsEmailInput(value: qa@example.com)'),
      ('{"type":"number","value":25.5}', 'AdaptyOnboardingsNumberInput(value: 25.5)'),
    ]) {
      expect((await receivedInput(json)).toString(), expected);
    }
  });

  test('the params print their input', () async {
    await deliverInput('{"type":"email","value":"qa@example.com"}');

    expect(
      observer.received.single.toString(),
      'AdaptyOnboardingsInputParams(input: AdaptyOnboardingsEmailInput(value: qa@example.com))',
    );
  });
}
