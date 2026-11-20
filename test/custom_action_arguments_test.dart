import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('flutter.adapty.com/adapty');

class _Observer extends AdaptyUIFlowsEventsObserver {
  final actions = <AdaptyUIAction>[];

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
    actions.add(action);
  }

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {}

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {}

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Observer observer;

  /// Delivers a flow action as the native side does, so the raw JSON goes through `jsonDecode`
  /// and a failed decoding is handled by the channel handler.
  Future<void> deliverAction(String actionJson, {String viewId = 'view-id'}) {
    final arguments =
        '{'
        '"view":{"id":"$viewId","placement_id":"placement-id","variation_id":"variation-id"},'
        '"action":$actionJson'
        '}';

    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      _channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('flow_view_did_perform_action', arguments)),
      (_) {},
    );
  }

  Future<CustomAction> receivedCustomAction(String actionJson) async {
    observer.actions.clear();
    await deliverAction(actionJson);

    expect(observer.actions, hasLength(1), reason: actionJson);
    return observer.actions.single as CustomAction;
  }

  setUp(() {
    observer = _Observer();
    // Installs the incoming method call handler without going through the native side.
    Adapty().setupAfterHotRestart();
    AdaptyUI().setFlowsEventsObserver(observer);
  });

  tearDown(() {
    AdaptyUI().setFlowsEventsObserver(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  test('a custom action carries the arguments the flow passed, nested values included', () async {
    final action = await receivedCustomAction(
      '{"type":"custom","value":"login",'
      '"arguments":{"s":"a","i":1,"d":1.5,"b":true,"list":[1,null,"x"],"obj":{"k":"v"}}}',
    );

    expect(action.action, 'login');
    expect(action.arguments, {
      's': 'a',
      'i': 1,
      'd': 1.5,
      'b': true,
      'list': [1, null, 'x'],
      'obj': {'k': 'v'},
    });
    expect(action.arguments!['i'], isA<int>());
    expect(action.arguments!['d'], isA<double>());
  });

  test('a custom action without arguments has null arguments', () async {
    final action = await receivedCustomAction('{"type":"custom","value":"login"}');

    expect(action.action, 'login');
    expect(action.arguments, isNull);
  });

  test('null arguments decode to null', () async {
    final action = await receivedCustomAction('{"type":"custom","value":"login","arguments":null}');

    expect(action.action, 'login');
    expect(action.arguments, isNull);
  });

  test('empty arguments stay an empty map', () async {
    final action = await receivedCustomAction('{"type":"custom","value":"login","arguments":{}}');

    expect(action.action, 'login');
    expect(action.arguments, isNotNull);
    expect(action.arguments, isEmpty);
  });

  test('an embedded flow view receives the arguments through its listener', () async {
    const viewId = 'flutter_native_0';
    final listener = _Observer();
    AdaptyUI().registerFlowEventsListener(listener, viewId);
    addTearDown(() => AdaptyUI().unregisterFlowEventsListener(viewId));
    // The proxy calls both the view's listener and the global observer: without the global one,
    // only the listener can record the action.
    AdaptyUI().setFlowsEventsObserver(null);

    await deliverAction('{"type":"custom","value":"login","arguments":{"plan":"annual","step":2}}', viewId: viewId);

    final action = listener.actions.single as CustomAction;
    expect(action.action, 'login');
    expect(action.arguments, {'plan': 'annual', 'step': 2});
  });

  test('CustomAction keeps its positional constructor', () {
    expect(const CustomAction('x').arguments, isNull);
    expect(const CustomAction('x').action, 'x');
    expect(CustomAction('x', arguments: {'a': 1}).arguments, {'a': 1});
  });

  test('arguments that are not an object do not drop the custom action', () async {
    for (final json in ['[]', '"x"']) {
      final action = await receivedCustomAction('{"type":"custom","value":"login","arguments":$json}');

      expect(action.action, 'login', reason: json);
      expect(action.arguments, isNull, reason: json);
    }
  });
}
