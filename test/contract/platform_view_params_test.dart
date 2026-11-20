// What the SDK gives the native side when it creates an embedded flow or onboarding view: the creation parameters of
// the platform view, which both natives read as the request that creates such a view, without its method. On each
// platform they are valid under the bridge contract (but the fields of the other platform the baseline accepts), equal
// to what the native decoders read, and the same as the golden case under contract/pseudo/<view>/.
//
// The golden cases are written with ADAPTY_CONTRACT_UPDATE=1, and the writer refuses parameters that are not what the
// table says.
// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/baseline.dart';
import '../../tool/contract/src/contract_schema.dart';
import '../../tool/contract/src/corpus.dart';
import '../../tool/contract/src/schema_validator.dart' show normalizeJson;
import '../support/contract/contract_runtime.dart';
import '../support/fake_platform_views.dart';
import 'support/api_calls.dart';
import 'support/golden_cases.dart';

const _cross = 'crossplatform/src/main/java/com/adapty/internal/crossplatform';

/// The native side reads the creation parameters of a flow view as the request that creates one.
final _flowViewDecoders =
    '${repositoryRefs.ios} Sources.AdaptyPlugin/PlatformViewSupport/AdaptyPlugin+NativeViewRequest.swift:23-25 as '
    'Sources.AdaptyPlugin/Requests/Request.AdaptyUICreateFlowView.swift:53-71 (no enable_safe_area_paddings, no '
    'product_purchase_parameters); ${repositoryRefs.android} $_cross/ui/FlowUiManager.kt:182 as $_cross/ui/CreateFlowViewArgs.kt:8-19, '
    '$_cross/CreateFlowViewArgsTypeAdapterFactory.kt:16-29; $flowDecoders; the Flutter host on iOS also reads '
    'flow.placement.developer_id and flow.variation_id for the error of a view that is not shown: '
    'ios/adapty_flutter/Sources/adapty_flutter/SwiftAdaptyPaywallNativeView.swift:232-241';

/// The native decoders of the custom assets of a flow view.
final _customAssetDecoders =
    'custom_assets: ${repositoryRefs.ios} Sources.AdaptyPlugin/Codable.AdaptyUI/AdaptyUI.AdaptyCustomAssets.Identifiable.swift:29-93; '
    '${repositoryRefs.android} $_cross/AdaptyCustomAssetTypeAdapterFactory.kt:31-115, $_cross/FileLocationArgsDeserializer.kt:16-28';

/// The native side reads the creation parameters of an onboarding view as the request that creates one.
final _onboardingViewDecoders =
    '${repositoryRefs.ios} Sources.AdaptyPlugin/PlatformViewSupport/AdaptyPlugin+NativeViewRequest.swift:64-66 as '
    'Sources.AdaptyPlugin/Requests/Request.AdaptyUICreateOnboardingView.swift:20-23; ${repositoryRefs.android} '
    '$_cross/ui/OnboardingUiManager.kt:77 as $_cross/ui/CreateOnboardingViewArgs.kt:6-9; $onboardingDecoders';

/// The properties of the request that creates a view that its creation parameters never carry, with the reason.
const _neverSent = {
  'flow_platform_view': {
    'preload_products':
        'the widget does not preload products; without the key Android reads false '
        '($_cross/CreateFlowViewArgsTypeAdapterFactory.kt:23-24) and iOS builds the view without a preload',
    'load_timeout':
        'the widget has no load timeout; without the key both natives use their default '
        '($_cross/ui/FlowUiManager.kt:191; ios Request.AdaptyUICreateFlowView.swift loadTimeout is optional)',
  },
  'onboarding_platform_view': <String, String>{},
};

/// The view type each embedded view registers on the native side.
const _viewTypes = {
  'flow_platform_view': 'adaptyui_flow_platform_view',
  'onboarding_platform_view': 'adaptyui_onboarding_platform_view',
};

/// One case of the creation parameters of an embedded view: the widget, built once the contract runtime is in place,
/// and the parameters it has to give on each platform, with the keys a native does not act on ([ignoredBy], JSON
/// Pointer to the platforms that ignore the key).
final class _ViewCase {
  const _ViewCase(this.view, this.caseName, this.build, this.params, {this.ignoredBy = const {}, this.moreDecoders});

  final String view;
  final String caseName;
  final Future<Widget> Function() build;
  final Map<String, Object?> Function(ContractPlatform platform) params;
  final Map<String, Set<ContractPlatform>> ignoredBy;

  /// The native decoders of what only this case gives, if any.
  final String? moreDecoders;

  /// `pseudo/<view>/<case>`, as the baseline names a case.
  String get name => 'pseudo/$view/$caseName';

  String get decoders =>
      [view == 'flow_platform_view' ? _flowViewDecoders : _onboardingViewDecoders, ?moreDecoders].join('; ');
}

Future<AdaptyFlow> _flow() => Adapty().getFlow(placementId: 'placement-id');

Future<AdaptyOnboarding> _onboarding() => Adapty().getOnboarding(placementId: 'placement-id');

const _safeAreaIgnored = {
  '/enable_safe_area_paddings': {ContractPlatform.ios},
};

final _cases = [
  _ViewCase(
    'flow_platform_view',
    'default',
    () async => AdaptyUIFlowPlatformView(flow: await _flow()),
    (platform) => {'flow': flowSentBack(platform), 'enable_safe_area_paddings': false},
    ignoredBy: _safeAreaIgnored,
  ),
  _ViewCase(
    'flow_platform_view',
    'product_purchase_parameters',
    () async => AdaptyUIFlowPlatformView(
      flow: await _flow(),
      productPurchaseParams: {
        const AdaptyProductIdentifier(vendorProductId: 'com.app.yearly', adaptyProductId: 'adapty-yearly'):
            purchaseParameters,
      },
    ),
    (platform) => {
      'flow': flowSentBack(platform),
      'enable_safe_area_paddings': false,
      'product_purchase_parameters': const {'adapty-yearly': purchaseParametersSent},
    },
    ignoredBy: {
      ..._safeAreaIgnored,
      '/product_purchase_parameters': {ContractPlatform.ios},
    },
  ),
  _ViewCase(
    'flow_platform_view',
    'full',
    () async => AdaptyUIFlowPlatformView(
      flow: await _flow(),
      locale: 'fr',
      customLayoutId: 'layout-2',
      androidEnableSafeArea: true,
      customTags: const {'USERNAME': 'John'},
      // A local time with microseconds, the same instant in any timezone: it goes out in UTC, to the millisecond.
      customTimers: {'sale_end': DateTime.utc(2026, 8, 24, 9, 34, 24, 727, 123).toLocal()},
      customAssets: {
        'brand_color': const AdaptyCustomAsset.color(color: Color(0xFF112233)),
        'hero': const AdaptyCustomAsset.localImageAsset(assetId: 'assets/hero.png'),
        'intro': const AdaptyCustomAsset.localVideoFile(path: '/tmp/intro.mp4'),
        'badge': AdaptyCustomAsset.localImageData(data: base64Decode(onePixelPng)),
        'poster': const AdaptyCustomAsset.localImageFile(path: '/tmp/poster.png'),
        'teaser': const AdaptyCustomAsset.localVideoAsset(assetId: 'assets/teaser.mp4'),
        'backdrop': const AdaptyCustomAsset.linearGradient(
          gradient: LinearGradient(
            colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
            stops: [0, 1],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      },
    ),
    (platform) => {
      'flow': flowSentBack(platform),
      'locale': 'fr',
      'custom_layout_id': 'layout-2',
      'enable_safe_area_paddings': true,
      'custom_tags': const {'USERNAME': 'John'},
      'custom_timers': const {'sale_end': '2026-08-24T09:34:24.727Z'},
      'custom_assets': const [
        {'id': 'brand_color', 'type': 'color', 'value': '#112233FF'},
        {'id': 'hero', 'type': 'image', 'asset_id': 'assets/hero.png'},
        {'id': 'intro', 'type': 'video', 'path': '/tmp/intro.mp4'},
        {
          'id': 'badge',
          'type': 'image',
          'value': 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
        },
        {'id': 'poster', 'type': 'image', 'path': '/tmp/poster.png'},
        {'id': 'teaser', 'type': 'video', 'asset_id': 'assets/teaser.mp4'},
        {
          'id': 'backdrop',
          'type': 'linear-gradient',
          'values': [
            {'color': '#000000FF', 'p': 0.0},
            {'color': '#FFFFFFFF', 'p': 1.0},
          ],
          'points': {'x0': 0.5, 'y0': 0.0, 'x1': 0.5, 'y1': 1.0},
        },
      ],
    },
    ignoredBy: _safeAreaIgnored,
    moreDecoders: _customAssetDecoders,
  ),
  _ViewCase(
    'onboarding_platform_view',
    'default',
    () async => AdaptyUIOnboardingPlatformView(onboarding: await _onboarding()),
    (platform) => {'onboarding': onboardingSentBack(platform), 'external_urls_presentation': 'browser_in_app'},
  ),
  _ViewCase(
    'onboarding_platform_view',
    'external_browser',
    () async => AdaptyUIOnboardingPlatformView(
      onboarding: await _onboarding(),
      externalUrlsPresentation: AdaptyWebPresentation.externalBrowser,
    ),
    (platform) => {'onboarding': onboardingSentBack(platform), 'external_urls_presentation': 'browser_out_app'},
  ),
];

/// A repository at a new temporary directory with [files] (path under `contract/pseudo/` to content).
String _repo(Map<String, String> files) {
  final root = Directory.systemTemp.createTempSync('platform_view_cases_');
  addTearDown(() => root.deleteSync(recursive: true));
  for (final MapEntry(:key, :value) in files.entries) {
    File('${root.path}/${PlatformViewCases.directory}/$key')
      ..createSync(recursive: true)
      ..writeAsStringSync(value);
  }
  return root.path;
}

String _case(Object? payload, {String native = 'both'}) => jsonEncode({
  'provenance': {'source': 'golden', 'native': native},
  'expect': null,
  'notes': 'written by hand for this test',
  'payload': payload,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final schema = ContractSchema.load('.');
  final corpus = Corpus.load('.');
  late final views = PlatformViewCases.load('.');
  final items = baselineItems(corpus.baseline);
  final accepted = {
    for (final entry in corpus.baseline)
      if (entry.decision == 'accepted') entry.id,
  };

  final recorded = <_ViewCase, Map<ContractPlatform, Map<String, Object?>>>{};
  tearDownAll(() {
    if (!updateGoldenCases) return;
    for (final MapEntry(key: c, value: platforms) in recorded.entries) {
      writeGoldenCase(
        directory: '${PlatformViewCases.directory}/${c.view}',
        name: c.name,
        caseName: c.caseName,
        expected: {
          for (final platform in ContractPlatform.values) platform: (payload: c.params(platform), notes: c.decoders),
        },
        recorded: platforms,
        refs: repositoryRefs,
      );
    }
  });

  group('reading the cases', () {
    test('a case is read for its platform, or for both from a file they share', () {
      final read = PlatformViewCases.load(
        _repo({
          'flow_platform_view/default.ios.json': _case({'flow': 1}, native: 'ios@test'),
          'flow_platform_view/default.android.json': _case({'flow': 2}, native: 'android@test'),
          'onboarding_platform_view/default.json': _case({'onboarding': 3}),
        }),
      );
      expect(read.problems, isEmpty);
      expect(read.fixture('flow_platform_view', 'default', ContractPlatform.ios)?.payload, {'flow': 1});
      expect(read.fixture('flow_platform_view', 'default', ContractPlatform.android)?.payload, {'flow': 2});
      expect(read.fixture('onboarding_platform_view', 'default', ContractPlatform.android)?.payload, {'onboarding': 3});
      expect(read.fixture('onboarding_platform_view', 'other', ContractPlatform.ios), isNull);
      expect(read.cases.map((c) => (c.kind, c.name)).toSet(), {
        (CorpusKind.request, 'flow_platform_view'),
        (CorpusKind.request, 'onboarding_platform_view'),
      });
    });

    test('a directory that is not an embedded view, a file that is not a case and a case twice are problems', () {
      final read = PlatformViewCases.load(
        _repo({
          'paywall_platform_view/default.json': _case({}),
          'flow_platform_view/Default.json': _case({}),
          'flow_platform_view/broken.json': '{"payload": {}}',
          'onboarding_platform_view/default.json': _case({}),
          'onboarding_platform_view/default.ios.json': _case({}, native: 'ios@test'),
        }),
      );
      expect(read.problems, [
        'contract/pseudo/flow_platform_view/Default.json: not a case file name (<case>[.ios|.android].json)',
        'contract/pseudo/flow_platform_view/broken.json: provenance is missing',
        'contract/pseudo/onboarding_platform_view/default.ios.json: the case "default" also has a file both platforms '
            'share',
        'contract/pseudo/paywall_platform_view: not an embedded view of the SDK',
      ]);
    });
  });

  group('the table', () {
    test('every case of contract/pseudo is read and is a case of the table', () {
      expect(views.problems, isEmpty);
      final names = {for (final c in _cases) c.name};
      for (final fixture in views.cases) {
        expect(names, contains('pseudo/${fixture.name}/${fixture.caseName}'), reason: fixture.path);
      }
    });

    test('every embedded view has cases, and every case its own name', () {
      expect(_cases.map((c) => c.view).toSet(), platformViewRequests.keys.toSet());
      final names = _cases.map((c) => c.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('every item of the baseline that names an embedded view names a case of the table', () {
      final names = {for (final c in _cases) c.name};
      for (final item in items.where((i) => i.caseName.startsWith('pseudo/'))) {
        expect(names, contains(item.caseName), reason: '$item');
      }
    });

    test('an onboarding view without the way to open external links is not valid on iOS, and is on Android', () {
      final entry = schema.requestEntry(platformViewRequests['onboarding_platform_view']!);

      final onIos = schema.validate(entry, {'onboarding': onboardingSentBack(ios)}, platform: ios).violations;
      final onAndroid = schema.validate(entry, {'onboarding': onboardingSentBack(android)}, platform: android);

      expect(onIos, [
        isA<Violation>()
            .having((v) => v.keyword, 'keyword', 'required')
            .having((v) => v.detail, 'detail', contains('external_urls_presentation')),
      ]);
      expect(onAndroid.violations, isEmpty);
    });

    test('the properties of the request a view never gives are the listed ones', () {
      for (final MapEntry(key: view, value: listed) in _neverSent.entries) {
        final entry = schema.requestEntry(platformViewRequests[view]!);
        final properties = (schema.resolve(entry.pointer)! as Map<String, Object?>)['properties']! as Map;
        final given = {
          for (final c in _cases.where((c) => c.view == view))
            for (final platform in ContractPlatform.values) ...c.params(platform).keys,
        };
        expect(
          properties.keys.where((key) => key != 'method' && !given.contains(key)).toSet(),
          listed.keys.toSet(),
          reason: view,
        );
      }
    });
  });

  group('each case', () {
    for (final c in _cases) {
      for (final platform in ContractPlatform.values) {
        testWidgets('${c.name} on ${platform.name}', (tester) async {
          installContractRuntime(platform: platform);
          final fake = FakePlatformViews.install(tester);

          await tester.pumpWidget(Directionality(textDirection: TextDirection.ltr, child: await c.build()));

          final created = fake.created.single;
          expect(created.viewType, _viewTypes[c.view]);
          final params = normalizeJson(jsonDecode(created.params! as String))! as Map<String, Object?>;
          expect(params, c.params(platform));

          // Valid for the platform, but for what the baseline takes away, and only by an item that names this case: an
          // item of a request case does not stand for a view. What an accepted entry takes away is a key of the other
          // platform the table says this native does not act on. Every item that names this case is still there.
          final entry = schema.requestEntry(platformViewRequests[c.view]!);
          final shown = <String>{};
          for (final violation in schema.validate(entry, params, platform: platform).violations) {
            final item = items
                .where((i) => i.caseName == c.name && i.matches(entry.name, platform, violation))
                .firstOrNull;
            expect(item, isNotNull, reason: 'no item of ${c.name} takes away ${entry.name}: $violation');
            if (accepted.contains(item!.id)) {
              expect(c.ignoredBy[violation.instancePath], contains(platform), reason: '$item');
            }
            shown.add('$item');
          }
          for (final item in items.where((i) => i.caseName == c.name && i.platform == platform)) {
            expect(shown, contains('$item'), reason: 'the baseline item is not shown by its case any more');
          }

          if (updateGoldenCases) {
            (recorded[c] ??= {})[platform] = params;
            return;
          }
          final golden = views.fixture(c.view, c.caseName, platform);
          expect(golden, isNotNull, reason: 'no golden case; write it with ADAPTY_CONTRACT_UPDATE=1');
          expect(golden!.payload, params, reason: golden.path);
        });
      }
    }
  });
}
