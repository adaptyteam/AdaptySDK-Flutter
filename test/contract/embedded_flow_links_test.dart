// What the default handling sends to the native side for a link of a flow shown by AdaptyUIFlowPlatformView, replayed
// from the corpus over the contract native of each platform.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/adaptyui_events_proxy.dart'
    show AdaptyEmbeddedFlowActions, adaptyEmbeddedViewIdPrefix;
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart' show ContractPlatform;
import '../../tool/contract/src/corpus.dart';
import '../support/collecting_error_sink.dart' show settle;
import '../support/contract/contract_runtime.dart';

final _corpus = Corpus.load('.');

/// The id of the embedded view of this file.
const _viewId = '${adaptyEmbeddedViewIdPrefix}7';

/// The positive cases of `flow_view_did_perform_action` in the corpus whose action is a link, by their path.
final _links = [
  for (final f in _corpus.fixtures)
    if (f.kind == CorpusKind.event &&
        f.name == 'flow_view_did_perform_action' &&
        !f.isNegative &&
        _actionOf(f)['type'] == 'open_url')
      f,
]..sort((a, b) => a.path.compareTo(b.path));

/// The action in the payload of [fixture].
Map<String, Object?> _actionOf(CorpusFixture fixture) =>
    (fixture.payload! as Map<String, Object?>)['action']! as Map<String, Object?>;

/// The case name of [fixture] as an event of the embedded view [_viewId].
String _embeddedCase(CorpusFixture fixture) => '${fixture.caseName}_of_embedded_view';

/// The corpus of this repository with every link case also as an event of the view [_viewId], made by the test from
/// the case: the payload of the case with the id of the view changed.
final _embeddedCorpus = Corpus(
  fixtures: [
    ..._corpus.fixtures,
    for (final f in _links)
      CorpusFixture(
        kind: f.kind,
        name: f.name,
        caseName: _embeddedCase(f),
        platform: f.platform,
        path: '${f.path} (of the view $_viewId, made by the test)',
        provenance: f.provenance,
        expect: null,
        notes: f.notes,
        payload: {
          ...f.payload! as Map<String, Object?>,
          'view': {...(f.payload! as Map<String, Object?>)['view']! as Map<String, Object?>, 'id': _viewId},
        },
      ),
  ],
  baseline: _corpus.baseline,
  problems: const [],
);

/// The platforms that send [fixture].
List<ContractPlatform> _platformsOf(CorpusFixture fixture) =>
    fixture.platform == null ? ContractPlatform.values : [fixture.platform!];

/// The golden case of `adapty_ui_open_url` that each link case of the corpus has to be opened with, by the name of the
/// link case: the URL of the link and the place it opens in.
const _goldenCaseOf = {'open_url': 'in_app', 'open_url_out_of_app': 'default'};

/// The golden request of `adapty_ui_open_url` on [platform] for the link case [fixture].
Map<String, Object?> _openUrlGolden(CorpusFixture fixture, ContractPlatform platform) =>
    _corpus.fixture(CorpusKind.request, 'adapty_ui_open_url', _goldenCaseOf[fixture.caseName]!, platform)!.payload!
        as Map<String, Object?>;

/// The state of an AdaptyUIFlowPlatformView without onDidPerformAction as the SDK sees it: it gets the events of its
/// view and leaves the actions to the default handling.
final class _WidgetWithoutCallback extends AdaptyUIFlowsEventsObserver implements AdaptyEmbeddedFlowActions {
  final actions = <AdaptyUIAction>[];

  @override
  bool get handlesActions => false;

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) => actions.add(action);

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

  test('every link case of the corpus has the golden case of the same URL and place, in and out of the app', () {
    expect(_links.map((f) => f.caseName).toSet(), _goldenCaseOf.keys.toSet());
    for (final f in _links) {
      for (final p in _platformsOf(f)) {
        final golden = _openUrlGolden(f, p);
        expect(golden['url'], _actionOf(f)['value'], reason: '${f.path} on ${p.name}');
        expect(golden['open_in'], _actionOf(f)['open_in'], reason: '${f.path} on ${p.name}');
      }
    }
    expect(
      {
        for (final f in _links)
          for (final p in _platformsOf(f)) _openUrlGolden(f, p)['open_in'],
      },
      {'browser_in_app', 'browser_out_app'},
    );
  });

  group('a link of an embedded view whose widget has no callback, with no observer set,', () {
    for (final fixture in _links) {
      for (final platform in _platformsOf(fixture)) {
        test('${fixture.caseName} on ${platform.name} is opened once, with the request of its golden case', () async {
          final rt = installContractRuntime(platform: platform, corpus: _embeddedCorpus);
          final widget = _WidgetWithoutCallback();
          AdaptyUI().registerFlowEventsListener(widget, _viewId);

          await rt.native.sendEvent(fixture.name, caseName: _embeddedCase(fixture));
          await settle(rt.runtime);

          expect(rt.native.calls.map((call) => call.method), ['adapty_ui_open_url']);
          expect(rt.native.calls.single.normalizedArguments, _openUrlGolden(fixture, platform));
          expect(widget.actions, isEmpty);
        });
      }
    }
  });
}
