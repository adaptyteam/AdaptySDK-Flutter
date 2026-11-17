import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _Observer extends AdaptyUIFlowsEventsObserver {
  final errors = <AdaptyError>[];

  @override
  void flowViewDidFinishPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyPurchaseResult purchaseResult) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {
    errors.add(error);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('the AdaptyUI codes match the native AdaptyUI error codes', () {
    expect(AdaptyErrorCode.platformNotSupported, 4001);
    expect(AdaptyErrorCode.adaptyNotActivated, 4002);
    expect(AdaptyErrorCode.adaptyUINotActivated, 4003);
    expect(AdaptyErrorCode.wrongComponentType, 4103);
    expect(AdaptyErrorCode.wrongAssetType, 4104);
    expect(AdaptyErrorCode.jsException, 4105);
    expect(AdaptyErrorCode.navigatorNotFound, 4106);
    expect(AdaptyErrorCode.invalidActionURL, 4107);
    expect(AdaptyErrorCode.unsupportedURLScheme, 4108);
    expect(AdaptyErrorCode.webKit, 4200);
  });

  test('an AdaptyUI failure of a request keeps its native code and message', () async {
    for (final (code, name) in [
      (AdaptyErrorCode.platformNotSupported, 'platformNotSupported'),
      (AdaptyErrorCode.adaptyUINotActivated, 'adaptyUINotActivated'),
    ]) {
      final message = 'AdaptyUIError.$name (Code: $code): AdaptyUI can not create the flow view.';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
        expect(call.method, 'adapty_ui_create_flow_view');
        return jsonEncode({
          'error': {
            'adapty_code': code,
            'message': message,
            'detail': jsonEncode({'adapty_code': code, 'message': message, 'detail': 'AdaptyUI can not create the flow view.'}),
          },
        });
      });

      await expectLater(
        AdaptyUI().createFlowView(flow: _flow()),
        throwsA(
          isA<AdaptyError>()
              .having((error) => error.code, 'code', code)
              .having((error) => error.message, 'message', message),
        ),
        reason: name,
      );
    }
  });

  test('a flow error event carries its AdaptyUI code to the observer', () async {
    final observer = _Observer();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    AdaptyUI().setFlowsEventsObserver(observer);

    const message = "AdaptyUIError.navigatorNotFound (Code: 4106): Navigator with ID 'modal' was not found.";
    final arguments = jsonEncode({
      'id': 'flow_view_did_receive_error',
      'view': {'id': 'view-id', 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
      'error': {
        'adapty_code': 4106,
        'message': message,
        'detail': "Navigator with ID 'modal' was not found in the view configuration.",
      },
    });

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('flow_view_did_receive_error', arguments)),
      (_) {},
    );

    expect(
      observer.errors.single,
      isA<AdaptyError>()
          .having((error) => error.code, 'code', AdaptyErrorCode.navigatorNotFound)
          .having((error) => error.message, 'message', message),
    );
  });
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
  'variations': <dynamic>[],
  'response_created_at': 0,
});
