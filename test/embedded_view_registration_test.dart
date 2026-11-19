// ignore_for_file: deprecated_member_use_from_same_package
// An embedded flow or onboarding view listens for the events of its native view under `flutter_native_<id>`, where
// the id is the one Flutter gave the platform view, and stops listening when the widget goes away.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart';
import 'package:adapty_flutter/src/models/adapty_onboarding.dart' show AdaptyOnboardingJSONBuilder;
import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_platform_views.dart';
import 'support/fake_transport.dart';
import 'support/test_platform_info.dart';
import 'support/test_runtime.dart';

const _flowViewType = 'adaptyui_flow_platform_view';
const _onboardingViewType = 'adaptyui_onboarding_platform_view';

class _FlowObserver extends AdaptyUIFlowsEventsObserver {
  final appeared = <String>[];

  @override
  void flowViewDidAppear(AdaptyUIFlowView view) => appeared.add(view.id);

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

  testWidgets('an embedded flow view registers its observer under flutter_native_<id>', (tester) async {
    final transport = FakeTransport();
    installTestRuntime(transport: transport, platform: _uiKit);
    final views = FakePlatformViews.install(tester);
    final appeared = <String, List<String>>{'first': [], 'second': []};

    await tester.pumpWidget(
      _hostedPair(
        AdaptyUIFlowPlatformView(flow: _flow(), onDidAppear: (view) => appeared['first']!.add(view.id)),
        AdaptyUIFlowPlatformView(flow: _flow(), onDidAppear: (view) => appeared['second']!.add(view.id)),
      ),
    );
    final [firstId, secondId] = _idsOf(views, _flowViewType);
    expect(firstId, isNot(secondId));

    await transport.deliver('flow_view_did_appear', {'view': _view('flutter_native_$secondId')});
    await transport.deliver('flow_view_did_appear', {'view': _view('flutter_native_$firstId')});

    expect(appeared, {
      'first': ['flutter_native_$firstId'],
      'second': ['flutter_native_$secondId'],
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an embedded onboarding view registers the same way', (tester) async {
    final transport = FakeTransport();
    installTestRuntime(transport: transport, platform: _uiKit);
    final views = FakePlatformViews.install(tester);
    final loaded = <String, List<int>>{'first': [], 'second': []};

    await tester.pumpWidget(
      _hostedPair(
        AdaptyUIOnboardingPlatformView(
          onboarding: _onboarding(),
          onDidFinishLoading: (meta) => loaded['first']!.add(meta.screenIndex),
        ),
        AdaptyUIOnboardingPlatformView(
          onboarding: _onboarding(),
          onDidFinishLoading: (meta) => loaded['second']!.add(meta.screenIndex),
        ),
      ),
    );
    final [firstId, secondId] = _idsOf(views, _onboardingViewType);
    expect(firstId, isNot(secondId));

    await transport.deliver('onboarding_did_finish_loading', {
      'view': _view('flutter_native_$secondId'),
      'meta': _meta(screenIndex: 2),
    });
    await transport.deliver('onboarding_did_finish_loading', {
      'view': _view('flutter_native_$firstId'),
      'meta': _meta(screenIndex: 1),
    });

    expect(loaded, {
      'first': [1],
      'second': [2],
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposing the widget removes its observer', (tester) async {
    final transport = FakeTransport();
    installTestRuntime(transport: transport, platform: _uiKit);
    final views = FakePlatformViews.install(tester);
    final global = _FlowObserver();
    AdaptyUI().setFlowsEventsObserver(global);
    final appeared = <String, List<String>>{'kept': [], 'removed': []};
    final kept = AdaptyUIFlowPlatformView(
      key: const ValueKey('kept'),
      flow: _flow(),
      onDidAppear: (view) => appeared['kept']!.add(view.id),
    );

    await tester.pumpWidget(
      _hostedPair(
        kept,
        AdaptyUIFlowPlatformView(
          key: const ValueKey('removed'),
          flow: _flow(),
          onDidAppear: (view) => appeared['removed']!.add(view.id),
        ),
      ),
    );
    final [keptId, removedId] = _idsOf(views, _flowViewType);
    await tester.pumpWidget(_hostedPair(kept, null));
    expect(views.disposed, [removedId]);

    await transport.deliver('flow_view_did_appear', {'view': _view('flutter_native_$removedId')});
    await transport.deliver('flow_view_did_appear', {'view': _view('flutter_native_$keptId')});

    expect(appeared, {
      'kept': ['flutter_native_$keptId'],
      'removed': <String>[],
    });
    expect(global.appeared, ['flutter_native_$removedId', 'flutter_native_$keptId']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('disposing an onboarding widget removes its observer', (tester) async {
    final transport = FakeTransport();
    installTestRuntime(transport: transport, platform: _uiKit);
    final views = FakePlatformViews.install(tester);
    final loaded = <String, List<int>>{'kept': [], 'removed': []};
    final kept = AdaptyUIOnboardingPlatformView(
      key: const ValueKey('kept'),
      onboarding: _onboarding(),
      onDidFinishLoading: (meta) => loaded['kept']!.add(meta.screenIndex),
    );

    await tester.pumpWidget(
      _hostedPair(
        kept,
        AdaptyUIOnboardingPlatformView(
          key: const ValueKey('removed'),
          onboarding: _onboarding(),
          onDidFinishLoading: (meta) => loaded['removed']!.add(meta.screenIndex),
        ),
      ),
    );
    final [keptId, removedId] = _idsOf(views, _onboardingViewType);
    await tester.pumpWidget(_hostedPair(kept, null));
    expect(views.disposed, [removedId]);

    await transport.deliver('onboarding_did_finish_loading', {
      'view': _view('flutter_native_$removedId'),
      'meta': _meta(screenIndex: 2),
    });
    await transport.deliver('onboarding_did_finish_loading', {
      'view': _view('flutter_native_$keptId'),
      'meta': _meta(screenIndex: 1),
    });

    expect(loaded, {
      'kept': [1],
      'removed': <int>[],
    });
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an error that arrived before the widget registered is replayed to it', (tester) async {
    final transport = FakeTransport();
    installTestRuntime(transport: transport, platform: _uiKit);
    final views = FakePlatformViews.install(tester);

    // Flutter numbers platform views one after another, so the view built after this one gets the next id.
    await tester.pumpWidget(_hosted(AdaptyUIFlowPlatformView(flow: _flow())));
    final nextId = _idsOf(views, _flowViewType).single + 1;
    await tester.pumpWidget(const SizedBox());

    await transport.deliver('flow_view_did_receive_error', {
      'view': _view('flutter_native_$nextId'),
      'error': {'adapty_code': 4003, 'message': 'AdaptyUI is not activated', 'detail': 'detail'},
    });
    final errors = <(String, int)>[];
    await tester.pumpWidget(
      _hosted(
        AdaptyUIFlowPlatformView(flow: _flow(), onDidReceiveError: (view, error) => errors.add((view.id, error.code))),
      ),
    );

    expect(_idsOf(views, _flowViewType).last, nextId);
    expect(errors, [('flutter_native_$nextId', AdaptyErrorCode.adaptyUINotActivated)]);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the observer of a flow view is removed in the runtime where it was registered', (tester) async {
    final registeredIn = FakeTransport();
    installTestRuntime(transport: registeredIn, platform: _uiKit);
    final views = FakePlatformViews.install(tester);
    final appeared = <AdaptyUIFlowView>[];

    await tester.pumpWidget(_hosted(AdaptyUIFlowPlatformView(flow: _flow(), onDidAppear: appeared.add)));
    final id = _idsOf(views, _flowViewType).single;
    await registeredIn.deliver('flow_view_did_appear', {'view': _view('flutter_native_$id')});
    expect(appeared, hasLength(1));
    appeared.clear();
    installTestRuntime(platform: _uiKit);
    await tester.pumpWidget(const SizedBox());
    await registeredIn.deliver('flow_view_did_appear', {'view': _view('flutter_native_$id')});

    expect(appeared, isEmpty);
  });

  testWidgets('a flow view rebuilt under another runtime is still removed where it was registered', (tester) async {
    final registeredIn = FakeTransport();
    installTestRuntime(transport: registeredIn, platform: _uiKit);
    final views = FakePlatformViews.install(tester);
    final appeared = <String>[];

    await tester.pumpWidget(
      _hosted(AdaptyUIFlowPlatformView(flow: _flow(), onDidAppear: (view) => appeared.add(view.id))),
    );
    final id = _idsOf(views, _flowViewType).single;
    final rebuiltUnder = FakeTransport();
    installTestRuntime(transport: rebuiltUnder, platform: _uiKit);
    await tester.pumpWidget(
      _hosted(AdaptyUIFlowPlatformView(flow: _flow(), onDidAppear: (view) => appeared.add(view.id))),
    );
    expect(_idsOf(views, _flowViewType), [id]);
    await tester.pumpWidget(const SizedBox());
    await registeredIn.deliver('flow_view_did_appear', {'view': _view('flutter_native_$id')});
    await rebuiltUnder.deliver('flow_view_did_appear', {'view': _view('flutter_native_$id')});

    expect(appeared, isEmpty);
  });

  testWidgets('the observer of an onboarding view is removed in the runtime where it was registered', (tester) async {
    final registeredIn = FakeTransport();
    installTestRuntime(transport: registeredIn, platform: _uiKit);
    final views = FakePlatformViews.install(tester);
    final loaded = <AdaptyUIOnboardingMeta>[];

    await tester.pumpWidget(
      _hosted(AdaptyUIOnboardingPlatformView(onboarding: _onboarding(), onDidFinishLoading: loaded.add)),
    );
    final id = _idsOf(views, _onboardingViewType).single;
    await registeredIn.deliver('onboarding_did_finish_loading', {
      'view': _view('flutter_native_$id'),
      'meta': _meta(screenIndex: 1),
    });
    expect(loaded, hasLength(1));
    loaded.clear();
    installTestRuntime(platform: _uiKit);
    await tester.pumpWidget(const SizedBox());
    await registeredIn.deliver('onboarding_did_finish_loading', {
      'view': _view('flutter_native_$id'),
      'meta': _meta(screenIndex: 1),
    });

    expect(loaded, isEmpty);
  });

  testWidgets('an onboarding view rebuilt under another runtime is still removed where it was registered', (
    tester,
  ) async {
    final registeredIn = FakeTransport();
    installTestRuntime(transport: registeredIn, platform: _uiKit);
    final views = FakePlatformViews.install(tester);
    final loaded = <int>[];

    await tester.pumpWidget(
      _hosted(
        AdaptyUIOnboardingPlatformView(
          onboarding: _onboarding(),
          onDidFinishLoading: (meta) => loaded.add(meta.screenIndex),
        ),
      ),
    );
    final id = _idsOf(views, _onboardingViewType).single;
    final rebuiltUnder = FakeTransport();
    installTestRuntime(transport: rebuiltUnder, platform: _uiKit);
    await tester.pumpWidget(
      _hosted(
        AdaptyUIOnboardingPlatformView(
          onboarding: _onboarding(),
          onDidFinishLoading: (meta) => loaded.add(meta.screenIndex),
        ),
      ),
    );
    expect(_idsOf(views, _onboardingViewType), [id]);
    await tester.pumpWidget(const SizedBox());
    await registeredIn.deliver('onboarding_did_finish_loading', {
      'view': _view('flutter_native_$id'),
      'meta': _meta(screenIndex: 1),
    });
    await rebuiltUnder.deliver('onboarding_did_finish_loading', {
      'view': _view('flutter_native_$id'),
      'meta': _meta(screenIndex: 2),
    });

    expect(loaded, isEmpty);
  });
}

const _uiKit = TestPlatformInfo(isIOS: false, isAndroid: false, viewKind: AdaptyPlatformViewKind.uiKit, logTag: 'i');

/// The ids of the views of [viewType] created so far, in order.
List<int> _idsOf(FakePlatformViews views, String viewType) => [
  for (final view in views.created)
    if (view.viewType == viewType) view.id,
];

Widget _hosted(Widget view) => Directionality(textDirection: TextDirection.ltr, child: view);

Widget _hostedPair(Widget first, Widget? second) => _hosted(
  Column(
    children: [
      Expanded(child: first),
      if (second != null) Expanded(child: second),
    ],
  ),
);

Map<String, dynamic> _view(String id) => {'id': id, 'placement_id': 'placement-id', 'variation_id': 'variation-id'};

Map<String, dynamic> _meta({required int screenIndex}) => {
  'onboarding_id': 'onboarding-id',
  'screen_cid': 'screen-$screenIndex',
  'screen_index': screenIndex,
  'total_screens': 3,
};

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
