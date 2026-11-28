/// The methods of a flow view and of an onboarding view send the same request as the method of `AdaptyUI()` they stand
/// for, with the values they were given, and hand back what it hands back.
// The onboarding API is deprecated; using it is exactly what these tests do.
// ignore_for_file: deprecated_member_use_from_same_package
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/models/adapty_onboarding.dart' show AdaptyOnboardingJSONBuilder;
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_transport.dart';
import 'support/test_runtime.dart';

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
    'grids': [
      {'platforms': 'all', 'devices': 'all', 'custom_id': 'configured-grid-id', 'cells': <dynamic>[]},
    ],
  },
  'response_created_at': 0,
});

AdaptyOnboarding _onboarding() => AdaptyOnboardingJSONBuilder.fromJsonValue({
  'placement': {
    'developer_id': 'placement-id',
    'audience_name': 'Audience',
    'revision': 1,
    'ab_test_name': 'Experiment',
    'placement_audience_version_id': 'placement-audience-version-id',
  },
  'onboarding_id': 'onboarding-id',
  'onboarding_name': 'Onboarding',
  'variation_id': 'variation-id',
  'response_created_at': 0,
  'onboarding_builder': {'config_url': 'https://example.com/config'},
  'request_locale': 'en',
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTransport transport;

  setUp(() {
    transport = FakeTransport();
    installTestRuntime(transport: transport);
  });

  /// The requests the SDK sent with the wire name [method], in order.
  List<Map<String, dynamic>> sent(String method) => [
    for (final (name, arguments) in transport.calls)
      if (name == method) arguments,
  ];

  group('a flow view', () {
    late AdaptyUIFlowView view;

    setUp(() async {
      transport.reply('adapty_ui_create_flow_view', {
        'id': 'view-1',
        'placement_id': 'placement-id',
        'variation_id': 'variation-id',
      });
      view = await AdaptyUI().createFlowView(flow: _flow());
    });

    test('present sends the request of AdaptyUI().presentFlowView with the style it is given', () async {
      await AdaptyUI().presentFlowView(view, iosPresentationStyle: AdaptyUIIOSPresentationStyle.pageSheet);
      await view.present(iosPresentationStyle: AdaptyUIIOSPresentationStyle.pageSheet);
      await AdaptyUI().presentFlowView(view);
      await view.present();

      final requests = sent('adapty_ui_present_flow_view');
      expect(requests, hasLength(4));
      expect(requests[1], requests[0]);
      expect(requests[0], {'id': 'view-1', 'ios_presentation_style': 'page_sheet'});
      expect(requests[3], requests[2]);
      expect(requests[2], {'id': 'view-1', 'ios_presentation_style': 'full_screen'});
    });

    test('showDialog sends the request of AdaptyUI().showDialog for its id and hands back the action', () async {
      transport.reply('adapty_ui_show_dialog', 'secondary');

      final fromAdaptyUI = await AdaptyUI().showDialog(
        view.id,
        title: 'Leave?',
        content: 'Your progress will be lost.',
        primaryActionTitle: 'Stay',
        secondaryActionTitle: 'Leave',
      );
      final fromView = await view.showDialog(
        title: 'Leave?',
        content: 'Your progress will be lost.',
        primaryActionTitle: 'Stay',
        secondaryActionTitle: 'Leave',
      );

      final requests = sent('adapty_ui_show_dialog');
      expect(requests, hasLength(2));
      expect(requests[1], requests[0]);
      expect(requests[0], {
        'id': 'view-1',
        'configuration': {
          'title': 'Leave?',
          'content': 'Your progress will be lost.',
          'default_action_title': 'Stay',
          'secondary_action_title': 'Leave',
        },
      });
      expect([fromAdaptyUI, fromView], [AdaptyUIDialogActionType.secondary, AdaptyUIDialogActionType.secondary]);
    });
  });

  group('an onboarding view', () {
    late AdaptyUIOnboardingView view;

    setUp(() async {
      transport.reply('adapty_ui_create_onboarding_view', {
        'id': 'onboarding-view-1',
        'placement_id': 'placement-id',
        'variation_id': 'variation-id',
      });
      view = await AdaptyUI().createOnboardingView(onboarding: _onboarding());
    });

    test('present sends the request of AdaptyUI().presentOnboardingView with the style it is given', () async {
      await AdaptyUI().presentOnboardingView(view, iosPresentationStyle: AdaptyUIIOSPresentationStyle.pageSheet);
      await view.present(iosPresentationStyle: AdaptyUIIOSPresentationStyle.pageSheet);
      await AdaptyUI().presentOnboardingView(view);
      await view.present();

      final requests = sent('adapty_ui_present_onboarding_view');
      expect(requests, hasLength(4));
      expect(requests[1], requests[0]);
      expect(requests[0], {'id': 'onboarding-view-1', 'ios_presentation_style': 'page_sheet'});
      expect(requests[3], requests[2]);
      expect(requests[2], {'id': 'onboarding-view-1', 'ios_presentation_style': 'full_screen'});
    });

    test('dismiss sends the request of AdaptyUI().dismissOnboardingView', () async {
      await AdaptyUI().dismissOnboardingView(view);
      await view.dismiss();

      final requests = sent('adapty_ui_dismiss_onboarding_view');
      expect(requests, hasLength(2));
      expect(requests[1], requests[0]);
      expect(requests[0], {'id': 'onboarding-view-1', 'destroy': true});
    });

    test('showDialog sends the request of AdaptyUI().showDialog for its id and hands back the action', () async {
      transport.reply('adapty_ui_show_dialog', 'primary');

      final fromAdaptyUI = await AdaptyUI().showDialog(
        view.id,
        title: 'Skip?',
        content: 'You can come back later.',
        primaryActionTitle: 'Skip',
      );
      final fromView = await view.showDialog(
        title: 'Skip?',
        content: 'You can come back later.',
        primaryActionTitle: 'Skip',
      );

      final requests = sent('adapty_ui_show_dialog');
      expect(requests, hasLength(2));
      expect(requests[1], requests[0]);
      expect(requests[0], {
        'id': 'onboarding-view-1',
        'configuration': {'title': 'Skip?', 'content': 'You can come back later.', 'default_action_title': 'Skip'},
      });
      expect([fromAdaptyUI, fromView], [AdaptyUIDialogActionType.primary, AdaptyUIDialogActionType.primary]);
    });
  });
}
