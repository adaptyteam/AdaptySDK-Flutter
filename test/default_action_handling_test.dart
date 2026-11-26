// The default handling of flow actions is the same whichever way it is reached: by the SDK when no flows observer is
// set, or by an observer of the app that keeps the flowViewDidPerformAction it inherits.
import 'dart:convert';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/collecting_error_sink.dart';
import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

/// Keeps the action handling it inherits from [AdaptyUIFlowsEventsObserver].
class _InheritingObserver extends AdaptyUIFlowsEventsObserver {
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

/// The actions of a flow, by a name for the test.
const _actions = {
  'close': {'type': 'close'},
  'a link opened in the app': {'type': 'open_url', 'value': 'https://adapty.io', 'open_in': 'browser_in_app'},
  'a link opened out of the app': {'type': 'open_url', 'value': 'https://adapty.io', 'open_in': 'browser_out_app'},
  'a custom action': {'type': 'custom', 'value': 'custom-1'},
  'the Android system back': {'type': 'system_back'},
};

/// The views an action can come from: one created by createFlowView and one shown by AdaptyUIFlowPlatformView.
const _views = ['view-1', 'flutter_native_3'];

/// What the SDK does when [action] of the view [viewId] reaches the default handling, with [observer] set as the flows
/// observer (none when null): each call of the native side, as its name and its JSON arguments, and each record of an
/// error, as its kind, context, place and error, with every call failing when [failing].
Future<(List<String>, List<String>)> _handle(
  String viewId,
  Map<String, Object> action, {
  required AdaptyUIFlowsEventsObserver? observer,
  required bool failing,
}) async {
  final transport = FakeTransport();
  final errors = CollectingErrorSink();
  final rt = installTestRuntime(transport: transport, errorSink: errors);
  if (failing) {
    transport.replyError('adapty_ui_dismiss_flow_view', code: 3001, message: 'the view is not found');
    transport.replyError('adapty_ui_open_url', code: 2003, message: 'the url is not valid');
  }
  if (observer != null) AdaptyUI().setFlowsEventsObserver(observer);

  await transport.deliver('flow_view_did_perform_action', {
    'view': {'id': viewId, 'placement_id': 'placement-id', 'variation_id': 'variation-id'},
    'action': action,
  });
  await settle(rt);

  return (
    [for (final (method, arguments) in transport.calls) '$method ${jsonEncode(arguments)}'],
    [for (final r in errors.records) '${r.kind.name} ${r.context} ${r.where}: ${r.error}'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final viewId in _views) {
    for (final MapEntry(key: name, value: action) in _actions.entries) {
      for (final failing in [false, true]) {
        test('$name of $viewId${failing ? ', with the call failing,' : ''} makes the same calls and records with no '
            'observer as with an observer that keeps the inherited handling', () async {
          final byDefault = await _handle(viewId, action, observer: null, failing: failing);
          final inherited = await _handle(viewId, action, observer: _InheritingObserver(), failing: failing);

          expect(inherited.$1, byDefault.$1);
          expect(inherited.$2, byDefault.$2);
        });
      }
    }
  }

  test('the default handling makes a call for a close of a created view and for a link, and only for them, and '
      'reports each failed call once', () async {
    final handled = {
      for (final viewId in _views)
        for (final MapEntry(key: name, value: action) in _actions.entries)
          '$name of $viewId': await _handle(viewId, action, observer: null, failing: true),
    };

    const dismiss = ('adapty_ui_dismiss_flow_view', 'backgroundCallFailed default_observer.dismiss');
    const open = ('adapty_ui_open_url', 'backgroundCallFailed default_observer.open_url');
    expect(
      {
        for (final MapEntry(:key, value: (calls, records)) in handled.entries)
          key: [
            for (final (i, call) in calls.indexed)
              (call.split(' ').first, i < records.length ? records[i].split(' Adapty.').first : null),
          ],
      },
      {
        'close of view-1': [dismiss],
        'a link opened in the app of view-1': [open],
        'a link opened out of the app of view-1': [open],
        'a custom action of view-1': isEmpty,
        'the Android system back of view-1': isEmpty,
        'close of flutter_native_3': isEmpty,
        'a link opened in the app of flutter_native_3': [open],
        'a link opened out of the app of flutter_native_3': [open],
        'a custom action of flutter_native_3': isEmpty,
        'the Android system back of flutter_native_3': isEmpty,
      },
    );
    expect([for (final (calls, records) in handled.values) calls.length - records.length], everyElement(0));
  });
}
