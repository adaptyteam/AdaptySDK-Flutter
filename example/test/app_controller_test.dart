import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adapty_flow.dart' show AdaptyFlowJSONBuilder;
import 'package:adapty_flutter/src/models/adapty_profile.dart' show AdaptyProfileJSONBuilder;
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_flow_view.dart' show AdaptyUIFlowViewJSONBuilder;
import 'package:flutter_test/flutter_test.dart';

import '../lib/app/app_adapty_service.dart';
import '../lib/app/app_constants.dart';
import '../lib/app/app_controller.dart';
import '../lib/app/user_manager.dart';

void main() {
  late _FakeAdaptyService adapty;
  late _FakeAdaptyUIService adaptyUI;
  late _FakeUserManager userManager;
  late AppController controller;

  setUp(() {
    adapty = _FakeAdaptyService();
    adaptyUI = _FakeAdaptyUIService();
    userManager = _FakeUserManager();
    controller = AppController(userManager: userManager, adapty: adapty, adaptyUI: adaptyUI)
      ..isInitialized = true
      ..userId = 'old-user';
  });

  tearDown(() async {
    controller.dispose();
    await adapty.dispose();
  });

  Future<({AdaptyProfile profile, AdaptyFlow flow})> seedOldState() async {
    final oldProfile = _profile(id: 'old-profile', customerUserId: 'old-user', premium: true);
    final oldFlow = _flow('old-flow');
    adapty.getProfileHandler = () async => oldProfile;
    adapty.getFlowHandler = () async => oldFlow;

    await controller.reloadProfile();
    await controller.loadFlow();

    expect(controller.isPremiumUser, isTrue);
    return (profile: oldProfile, flow: oldFlow);
  }

  test('placeholder configuration marks the controller invalid without asserting', () async {
    final fresh = AppController(userManager: userManager, adapty: adapty, adaptyUI: adaptyUI);
    addTearDown(fresh.dispose);

    await fresh.initialize();

    expect(AppConstants.hasValidConfiguration, isFalse, reason: 'the checked-in constants are placeholders');
    expect(fresh.configurationInvalid, isTrue);
    expect(fresh.isInitialized, isFalse);
    expect(fresh.canUseSdk, isFalse);
    expect(fresh.errorMessage, isNull);
  });

  test('modal flow view is built with the configured locale and records the resolved one', () async {
    adapty.getFlowHandler = () async => _flow('flow');
    adaptyUI.createFlowViewHandler = () async => _flowView(locale: 'fr');

    await controller.presentFlowModally();

    expect(adaptyUI.createFlowViewCalls, 1);
    expect(adaptyUI.lastLocale, AppConstants.flowLocale);
    expect(controller.flowViewLocale, 'fr');
  });

  test('recordFlowView stores the view locale and notifies once per change', () {
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.recordFlowView(_flowView(locale: 'es'));
    controller.recordFlowView(_flowView(locale: 'es'));

    expect(controller.flowViewLocale, 'es');
    expect(notifications, 1);
  });

  test('identity transition resets the recorded view locale', () async {
    await seedOldState();
    controller.recordFlowView(_flowView(locale: 'es'));

    await controller.login('new-user');

    expect(controller.userId, 'new-user');
    expect(controller.flowViewLocale, isNull);
  });

  test('native identify failure retains the current identity state', () async {
    final old = await seedOldState();
    adapty.identifyHandler = (_) async => throw StateError('identify failed');

    await controller.login('new-user');

    expect(controller.userId, 'old-user');
    expect(controller.profile, same(old.profile));
    expect(controller.flow, same(old.flow));
    expect(controller.isPremiumUser, isTrue);
    expect(controller.errorMessage, contains('Identity:'));
    expect(controller.isUpdatingIdentity, isFalse);
  });

  test('native logout failure retains the current identity state', () async {
    final old = await seedOldState();
    adapty.logoutHandler = () async => throw StateError('logout failed');

    await controller.logout();

    expect(controller.userId, 'old-user');
    expect(controller.profile, same(old.profile));
    expect(controller.flow, same(old.flow));
    expect(controller.isPremiumUser, isTrue);
    expect(controller.errorMessage, contains('Identity:'));
  });

  test('older profile success cannot clear a newer failed-identify error', () async {
    await seedOldState();
    final profileRequest = Completer<AdaptyProfile>();
    final callsBefore = adapty.getProfileCalls;
    adapty.getProfileHandler = () => profileRequest.future;

    final profileRefresh = controller.reloadProfile();
    await _drainUntil(() => adapty.getProfileCalls == callsBefore + 1);

    adapty.identifyHandler = (_) async => throw StateError('identify failed');
    await controller.login('new-user');
    expect(controller.errorMessage, contains('Identity:'));

    profileRequest.complete(_profile(id: 'refreshed-old-profile', customerUserId: 'old-user'));
    await profileRefresh;

    expect(controller.errorMessage, contains('Identity:'));
  });

  test('older Profile operation cannot erase a newer Flow error', () async {
    await seedOldState();
    final profileRequest = Completer<AdaptyProfile>();
    final callsBefore = adapty.getProfileCalls;
    adapty.getProfileHandler = () => profileRequest.future;

    final profileRefresh = controller.reloadProfile();
    await _drainUntil(() => adapty.getProfileCalls == callsBefore + 1);

    adapty.getFlowHandler = () async => throw StateError('newer Flow failed');
    await controller.loadFlow();
    expect(controller.errorMessage, contains('Flow:'));

    profileRequest.complete(_profile(id: 'refreshed-old-profile', customerUserId: 'old-user'));
    await profileRefresh;

    expect(controller.errorMessage, contains('Flow:'));
  });

  test('report and clear own the banner over an older Flow completion', () async {
    await seedOldState();
    final flowRequest = Completer<AdaptyFlow>();
    final callsBefore = adapty.getFlowCalls;
    adapty.getFlowHandler = () => flowRequest.future;

    final flowRefresh = controller.loadFlow();
    await _drainUntil(() => adapty.getFlowCalls == callsBefore + 1);

    controller.reportError(StateError('newer observer error'));
    expect(controller.errorMessage, contains('newer observer error'));
    controller.clearError();
    expect(controller.errorMessage, isNull);

    flowRequest.completeError(StateError('older Flow failed'));
    await flowRefresh;

    expect(controller.errorMessage, isNull);
  });

  test('successful identify fails closed when both refreshes fail', () async {
    final old = await seedOldState();
    final snapshots = <_Snapshot>[];
    controller.addListener(() {
      snapshots.add(_Snapshot(controller.userId, controller.profile, controller.flow));
    });
    adapty.getProfileHandler = () async => throw StateError('profile offline');
    adapty.getFlowHandler = () async => throw StateError('flow offline');

    await controller.login('new-user');

    expect(controller.userId, 'new-user');
    expect(controller.profile, isNull);
    expect(controller.flow, isNull);
    expect(controller.isPremiumUser, isFalse);
    expect(controller.errorMessage, contains('Profile:'));
    expect(controller.errorMessage, contains('Flow:'));
    expect(
      snapshots.where((snapshot) => snapshot.userId == 'new-user'),
      everyElement(
        isA<_Snapshot>()
            .having((snapshot) => snapshot.profile, 'profile', isNot(same(old.profile)))
            .having((snapshot) => snapshot.flow, 'flow', isNot(same(old.flow))),
      ),
    );

    controller.applyProfileFromFlow(old.profile);
    expect(controller.profile, isNull, reason: 'a late profile for the previous customer must be ignored');
  });

  test('successful logout fails closed when both refreshes fail', () async {
    await seedOldState();
    adapty.getProfileHandler = () async => throw StateError('profile offline');
    adapty.getFlowHandler = () async => throw StateError('flow offline');

    await controller.logout();

    expect(controller.userId, isNull);
    expect(controller.profile, isNull);
    expect(controller.flow, isNull);
    expect(controller.isPremiumUser, isFalse);
    expect(controller.errorMessage, contains('Profile:'));
    expect(controller.errorMessage, contains('Flow:'));
  });

  test('profile failure followed by Flow success keeps the profile error', () async {
    await seedOldState();
    final newFlow = _flow('new-flow');
    adapty.getProfileHandler = () async => throw StateError('profile failed');
    adapty.getFlowHandler = () async => newFlow;

    await controller.login('new-user');

    expect(controller.profile, isNull);
    expect(controller.flow, same(newFlow));
    expect(controller.errorMessage, startsWith('Profile:'));
    expect(controller.errorMessage, isNot(contains('Flow:')));
  });

  test('paired refresh aggregates both failures in deterministic order', () async {
    await seedOldState();
    adapty.getProfileHandler = () async => throw StateError('profile failed');
    adapty.getFlowHandler = () async => throw StateError('flow failed');

    await controller.login('new-user');

    final message = controller.errorMessage!;
    expect(message.indexOf('Profile:'), lessThan(message.indexOf('Flow:')));
  });

  test('successful paired refresh clears an old error', () async {
    await seedOldState();
    controller.reportError(StateError('old error'));
    final newProfile = _profile(id: 'new-profile', customerUserId: 'new-user');
    final newFlow = _flow('new-flow');
    adapty.getProfileHandler = () async => newProfile;
    adapty.getFlowHandler = () async => newFlow;

    await controller.login('new-user');

    expect(controller.profile, same(newProfile));
    expect(controller.flow, same(newFlow));
    expect(controller.errorMessage, isNull);
  });

  test('Flow profile supersedes a pending paired profile reload and Flow still loads', () async {
    await seedOldState();
    final profileRequest = Completer<AdaptyProfile>();
    final flowRequest = Completer<AdaptyFlow>();
    final profileCallsBefore = adapty.getProfileCalls;
    final flowCallsBefore = adapty.getFlowCalls;
    adapty.getProfileHandler = () => profileRequest.future;
    adapty.getFlowHandler = () => flowRequest.future;

    final login = controller.login('new-user');
    await _drainUntil(() => adapty.getProfileCalls == profileCallsBefore + 1);

    final flowProfile = _profile(id: 'flow-profile', customerUserId: 'new-user', premium: true);
    controller.applyProfileFromFlow(flowProfile);
    profileRequest.complete(_profile(id: 'stale-profile', customerUserId: 'new-user'));

    await _drainUntil(() => adapty.getFlowCalls == flowCallsBefore + 1);
    expect(controller.profile, same(flowProfile));
    expect(controller.isPremiumUser, isTrue);
    expect(controller.isReloadingProfile, isFalse);
    expect(controller.isLoadingFlow, isTrue);

    final newFlow = _flow('new-flow');
    flowRequest.complete(newFlow);
    await login;

    expect(controller.profile, same(flowProfile));
    expect(controller.flow, same(newFlow));
    expect(controller.isReloadingProfile, isFalse);
    expect(controller.isLoadingFlow, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('restored profile supersedes a pending same-user profile reload', () async {
    await seedOldState();
    final profileRequest = Completer<AdaptyProfile>();
    final profileCallsBefore = adapty.getProfileCalls;
    adapty.getProfileHandler = () => profileRequest.future;

    final reload = controller.reloadProfile();
    await _drainUntil(() => adapty.getProfileCalls == profileCallsBefore + 1);

    final restoredProfile = _profile(id: 'restored-profile', customerUserId: 'old-user', premium: true);
    adapty.restorePurchasesHandler = () async => restoredProfile;
    await controller.restorePurchases();

    expect(controller.profile, same(restoredProfile));
    expect(controller.isRestoringPurchases, isFalse);
    expect(controller.isReloadingProfile, isTrue);

    profileRequest.complete(_profile(id: 'stale-profile', customerUserId: 'old-user'));
    await reload;

    expect(controller.profile, same(restoredProfile));
    expect(controller.isPremiumUser, isTrue);
    expect(controller.isRestoringPurchases, isFalse);
    expect(controller.isReloadingProfile, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('newer Flow profile suppresses a pending restore success', () async {
    await seedOldState();
    final restoreRequest = Completer<AdaptyProfile>();
    adapty.restorePurchasesHandler = () => restoreRequest.future;

    final restore = controller.restorePurchases();
    expect(controller.isRestoringPurchases, isTrue);

    final flowProfile = _profile(id: 'flow-profile', customerUserId: 'old-user', premium: true);
    controller.applyProfileFromFlow(flowProfile);
    restoreRequest.complete(_profile(id: 'stale-restored-profile', customerUserId: 'old-user'));
    await restore;

    expect(controller.profile, same(flowProfile));
    expect(controller.isPremiumUser, isTrue);
    expect(controller.errorMessage, isNull);
    expect(controller.isRestoringPurchases, isFalse);
  });

  test('newer Flow profile suppresses a pending restore error', () async {
    await seedOldState();
    final restoreRequest = Completer<AdaptyProfile>();
    adapty.restorePurchasesHandler = () => restoreRequest.future;

    final restore = controller.restorePurchases();
    expect(controller.isRestoringPurchases, isTrue);

    final flowProfile = _profile(id: 'flow-profile', customerUserId: 'old-user', premium: true);
    controller.applyProfileFromFlow(flowProfile);
    restoreRequest.completeError(StateError('stale restore failed'));
    await restore;

    expect(controller.profile, same(flowProfile));
    expect(controller.errorMessage, isNull);
    expect(controller.isRestoringPurchases, isFalse);
  });

  test('older restore completion cannot clear a newer restore loading state', () async {
    final old = await seedOldState();
    final firstRequest = Completer<AdaptyProfile>();
    final secondRequest = Completer<AdaptyProfile>();
    var calls = 0;
    adapty.restorePurchasesHandler = () {
      calls += 1;
      return calls == 1 ? firstRequest.future : secondRequest.future;
    };

    final firstRestore = controller.restorePurchases();
    final secondRestore = controller.restorePurchases();
    expect(calls, 2);

    firstRequest.complete(_profile(id: 'stale-restored-profile', customerUserId: 'old-user'));
    await firstRestore;

    expect(controller.profile, same(old.profile));
    expect(controller.isRestoringPurchases, isTrue);

    final restoredProfile = _profile(id: 'fresh-restored-profile', customerUserId: 'old-user', premium: true);
    secondRequest.complete(restoredProfile);
    await secondRestore;

    expect(controller.profile, same(restoredProfile));
    expect(controller.isRestoringPurchases, isFalse);
  });

  test('older restore result cannot overwrite a newer restore result', () async {
    await seedOldState();
    final firstRequest = Completer<AdaptyProfile>();
    final secondRequest = Completer<AdaptyProfile>();
    var calls = 0;
    adapty.restorePurchasesHandler = () {
      calls += 1;
      return calls == 1 ? firstRequest.future : secondRequest.future;
    };

    final firstRestore = controller.restorePurchases();
    final secondRestore = controller.restorePurchases();
    expect(calls, 2);

    final restoredProfile = _profile(id: 'fresh-restored-profile', customerUserId: 'old-user', premium: true);
    secondRequest.complete(restoredProfile);
    await secondRestore;

    firstRequest.complete(_profile(id: 'stale-restored-profile', customerUserId: 'old-user'));
    await firstRestore;

    expect(controller.profile, same(restoredProfile));
    expect(controller.isPremiumUser, isTrue);
    expect(controller.isRestoringPurchases, isFalse);
  });

  test('accepted Flow profile suppresses a stale pending Profile error', () async {
    await seedOldState();
    final profileRequest = Completer<AdaptyProfile>();
    final flowRequest = Completer<AdaptyFlow>();
    final profileCallsBefore = adapty.getProfileCalls;
    final flowCallsBefore = adapty.getFlowCalls;
    adapty.getProfileHandler = () => profileRequest.future;
    adapty.getFlowHandler = () => flowRequest.future;

    final login = controller.login('new-user');
    await _drainUntil(() => adapty.getProfileCalls == profileCallsBefore + 1);

    final flowProfile = _profile(id: 'flow-profile', customerUserId: 'new-user', premium: true);
    controller.applyProfileFromFlow(flowProfile);
    profileRequest.completeError(StateError('stale Profile failed'));

    await _drainUntil(() => adapty.getFlowCalls == flowCallsBefore + 1);
    expect(controller.profile, same(flowProfile));
    expect(controller.errorMessage, isNull);
    expect(controller.isLoadingFlow, isTrue);

    final newFlow = _flow('new-flow');
    flowRequest.complete(newFlow);
    await login;

    expect(controller.profile, same(flowProfile));
    expect(controller.flow, same(newFlow));
    expect(controller.errorMessage, isNull);
    expect(controller.isReloadingProfile, isFalse);
    expect(controller.isLoadingFlow, isFalse);
  });

  test('mismatched Flow profile does not supersede a pending current-user profile result', () async {
    final old = await seedOldState();
    final profileRequest = Completer<AdaptyProfile>();
    final profileCallsBefore = adapty.getProfileCalls;
    adapty.getProfileHandler = () => profileRequest.future;

    final reload = controller.reloadProfile();
    await _drainUntil(() => adapty.getProfileCalls == profileCallsBefore + 1);

    controller.applyProfileFromFlow(_profile(id: 'wrong-profile', customerUserId: 'other-user', premium: true));
    expect(controller.profile, same(old.profile));

    final currentProfile = _profile(id: 'current-profile', customerUserId: 'old-user');
    profileRequest.complete(currentProfile);
    await reload;

    expect(controller.profile, same(currentProfile));
    expect(controller.isPremiumUser, isFalse);
    expect(controller.isReloadingProfile, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('late pre-transition profile result and Flow error are ignored', () async {
    await seedOldState();
    final oldProfileRequest = Completer<AdaptyProfile>();
    final oldFlowRequest = Completer<AdaptyFlow>();
    final newProfile = _profile(id: 'new-profile', customerUserId: 'new-user');
    final newFlow = _flow('new-flow');
    var profileCalls = 0;
    var flowCalls = 0;
    adapty
      ..getProfileHandler = () {
        profileCalls += 1;
        return profileCalls == 1 ? oldProfileRequest.future : Future.value(newProfile);
      }
      ..getFlowHandler = () {
        flowCalls += 1;
        return flowCalls == 1 ? oldFlowRequest.future : Future.value(newFlow);
      };

    final oldProfileLoad = controller.reloadProfile();
    final oldFlowLoad = controller.loadFlow();
    await controller.login('new-user');

    oldProfileRequest.complete(_profile(id: 'late-old', customerUserId: 'old-user', premium: true));
    oldFlowRequest.completeError(StateError('late old Flow error'));
    await Future.wait([oldProfileLoad, oldFlowLoad]);

    expect(controller.profile, same(newProfile));
    expect(controller.flow, same(newFlow));
    expect(controller.errorMessage, isNull);
    expect(controller.isReloadingProfile, isFalse);
    expect(controller.isLoadingFlow, isFalse);
  });

  test('stale profile finalizer cannot clear a newer loading state', () async {
    await seedOldState();
    final oldProfileRequest = Completer<AdaptyProfile>();
    final newProfileRequest = Completer<AdaptyProfile>();
    var profileCalls = 0;
    adapty
      ..getProfileHandler = () {
        profileCalls += 1;
        return profileCalls == 1 ? oldProfileRequest.future : newProfileRequest.future;
      }
      ..getFlowHandler = () async => _flow('new-flow');

    final oldLoad = controller.reloadProfile();
    final login = controller.login('new-user');
    await _drainUntil(() => profileCalls == 2);

    oldProfileRequest.complete(_profile(id: 'late-old', customerUserId: 'old-user'));
    await oldLoad;

    expect(controller.isReloadingProfile, isTrue);

    newProfileRequest.complete(_profile(id: 'new-profile', customerUserId: 'new-user'));
    await login;

    expect(controller.isReloadingProfile, isFalse);
  });

  test('stale Flow error and finalizer cannot affect a newer loading state', () async {
    await seedOldState();
    final oldFlowRequest = Completer<AdaptyFlow>();
    final newFlowRequest = Completer<AdaptyFlow>();
    var flowCalls = 0;
    adapty.getProfileHandler = () async => _profile(id: 'new-profile', customerUserId: 'new-user');
    adapty.getFlowHandler = () {
      flowCalls += 1;
      return flowCalls == 1 ? oldFlowRequest.future : newFlowRequest.future;
    };

    final oldLoad = controller.loadFlow();
    final login = controller.login('new-user');
    await _drainUntil(() => flowCalls == 2);

    oldFlowRequest.completeError(StateError('stale Flow failed'));
    await oldLoad;

    expect(controller.isLoadingFlow, isTrue);
    expect(controller.errorMessage, isNull);

    final newFlow = _flow('new-flow');
    newFlowRequest.complete(newFlow);
    await login;

    expect(controller.isLoadingFlow, isFalse);
    expect(controller.flow, same(newFlow));
    expect(controller.errorMessage, isNull);
  });

  test('older same-identity profile request cannot overwrite a newer request', () async {
    final old = await seedOldState();
    final firstRequest = Completer<AdaptyProfile>();
    final secondRequest = Completer<AdaptyProfile>();
    var calls = 0;
    adapty.getProfileHandler = () {
      calls += 1;
      return calls == 1 ? firstRequest.future : secondRequest.future;
    };

    final firstLoad = controller.reloadProfile();
    final secondLoad = controller.reloadProfile();
    await _drainUntil(() => calls == 2);

    firstRequest.complete(_profile(id: 'stale-profile', customerUserId: 'old-user'));
    await firstLoad;

    expect(controller.profile, same(old.profile));
    expect(controller.isReloadingProfile, isTrue);

    final freshProfile = _profile(id: 'fresh-profile', customerUserId: 'old-user');
    secondRequest.complete(freshProfile);
    await secondLoad;

    expect(controller.profile, same(freshProfile));
    expect(controller.isReloadingProfile, isFalse);
  });

  test('older same-identity Flow request cannot publish a late error', () async {
    final old = await seedOldState();
    final firstRequest = Completer<AdaptyFlow>();
    final secondRequest = Completer<AdaptyFlow>();
    var calls = 0;
    adapty.getFlowHandler = () {
      calls += 1;
      return calls == 1 ? firstRequest.future : secondRequest.future;
    };

    final firstLoad = controller.loadFlow();
    final secondLoad = controller.loadFlow();
    await _drainUntil(() => calls == 2);

    firstRequest.completeError(StateError('stale Flow error'));
    await firstLoad;

    expect(controller.flow, same(old.flow));
    expect(controller.errorMessage, isNull);
    expect(controller.isLoadingFlow, isTrue);

    final freshFlow = _flow('fresh-flow');
    secondRequest.complete(freshFlow);
    await secondLoad;

    expect(controller.flow, same(freshFlow));
    expect(controller.errorMessage, isNull);
    expect(controller.isLoadingFlow, isFalse);
  });

  test('persistence failure remains visible and refresh still completes', () async {
    await seedOldState();
    final newProfile = _profile(id: 'new-profile', customerUserId: 'new-user');
    final newFlow = _flow('new-flow');
    final profileCallsBefore = adapty.getProfileCalls;
    final flowCallsBefore = adapty.getFlowCalls;
    userManager.loginHandler = (_) async => throw StateError('disk unavailable');
    adapty.getProfileHandler = () async => newProfile;
    adapty.getFlowHandler = () async => newFlow;

    await controller.login('new-user');

    expect(controller.userId, 'new-user');
    expect(controller.profile, same(newProfile));
    expect(controller.flow, same(newFlow));
    expect(controller.errorMessage, contains('Local identity:'));
    expect(adapty.getProfileCalls, profileCallsBefore + 1);
    expect(adapty.getFlowCalls, flowCallsBefore + 1);
  });

  test('persistence and refresh failures are aggregated', () async {
    await seedOldState();
    userManager.loginHandler = (_) async => throw StateError('disk unavailable');
    adapty.getProfileHandler = () async => throw StateError('profile failed');
    adapty.getFlowHandler = () async => throw StateError('flow failed');

    await controller.login('new-user');

    final message = controller.errorMessage!;
    expect(message, contains('Local identity:'));
    expect(message, contains('Profile:'));
    expect(message, contains('Flow:'));
    expect(message.indexOf('Local identity:'), lessThan(message.indexOf('Profile:')));
    expect(message.indexOf('Profile:'), lessThan(message.indexOf('Flow:')));
  });

  test('a second identity transition is rejected while the first is pending', () async {
    await seedOldState();
    final identifyCompleter = Completer<void>();
    adapty.identifyHandler = (_) => identifyCompleter.future;
    adapty.getProfileHandler = () async => _profile(id: 'new-profile', customerUserId: 'first-user');
    adapty.getFlowHandler = () async => _flow('new-flow');

    final firstLogin = controller.login('first-user');
    expect(controller.isUpdatingIdentity, isTrue);
    expect(controller.canUseSdk, isFalse);

    await controller.login('second-user');
    expect(adapty.identifyCalls, 1);

    identifyCompleter.complete();
    await firstLogin;

    expect(controller.userId, 'first-user');
    expect(controller.isUpdatingIdentity, isFalse);
  });
}

Future<void> _drainUntil(bool Function() predicate) async {
  for (var attempt = 0; attempt < 20; attempt += 1) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('Expected asynchronous state was not reached');
}

final class _Snapshot {
  const _Snapshot(this.userId, this.profile, this.flow);

  final String? userId;
  final AdaptyProfile? profile;
  final AdaptyFlow? flow;
}

final class _FakeAdaptyService implements AppAdaptyService {
  final StreamController<AdaptyProfile> _profiles = StreamController<AdaptyProfile>.broadcast();

  Future<AdaptyProfile> Function()? getProfileHandler;
  Future<AdaptyFlow> Function()? getFlowHandler;
  Future<void> Function(String)? identifyHandler;
  Future<void> Function()? logoutHandler;
  Future<AdaptyProfile> Function()? restorePurchasesHandler;

  int getProfileCalls = 0;
  int getFlowCalls = 0;
  int identifyCalls = 0;

  @override
  Stream<AdaptyProfile> get didUpdateProfileStream => _profiles.stream;

  @override
  Future<void> activate(AdaptyConfiguration configuration) async {}

  @override
  Future<AdaptyFlow> getFlow({required String placementId}) {
    getFlowCalls += 1;
    return getFlowHandler?.call() ?? Future<AdaptyFlow>.error(StateError('getFlow handler not set'));
  }

  @override
  Future<AdaptyProfile> getProfile() {
    getProfileCalls += 1;
    return getProfileHandler?.call() ?? Future<AdaptyProfile>.error(StateError('getProfile handler not set'));
  }

  @override
  Future<void> identify(String customerUserId) {
    identifyCalls += 1;
    return identifyHandler?.call(customerUserId) ?? Future<void>.value();
  }

  @override
  Future<bool> isActivated() async => true;

  @override
  Future<void> logout() => logoutHandler?.call() ?? Future<void>.value();

  @override
  Future<AdaptyProfile> restorePurchases() =>
      restorePurchasesHandler?.call() ?? Future<AdaptyProfile>.error(UnimplementedError());

  @override
  void setupAfterHotRestart() {}

  Future<void> dispose() => _profiles.close();
}

final class _FakeAdaptyUIService implements AppAdaptyUIService {
  Future<AdaptyUIFlowView> Function()? createFlowViewHandler;
  String? lastLocale;
  int createFlowViewCalls = 0;

  @override
  Future<AdaptyUIFlowView> createFlowView({required AdaptyFlow flow, String? locale}) {
    createFlowViewCalls += 1;
    lastLocale = locale;
    return createFlowViewHandler?.call() ?? Future<AdaptyUIFlowView>.error(UnimplementedError());
  }

  @override
  Future<void> openUrl(String url, {required AdaptyWebPresentation openIn}) async {}

  @override
  void setFlowsEventsObserver(AdaptyUIFlowsEventsObserver? observer) {}
}

final class _FakeUserManager implements UserManager {
  Future<void> Function(String)? loginHandler;
  Future<void> Function()? logoutHandler;
  String? storedUserId = 'old-user';

  @override
  Future<String?> currentUserId() async => storedUserId;

  @override
  Future<void> login(String userId) async {
    if (loginHandler != null) {
      await loginHandler!(userId);
      return;
    }
    storedUserId = userId;
  }

  @override
  Future<void> logout() async {
    if (logoutHandler != null) {
      await logoutHandler!();
      return;
    }
    storedUserId = null;
  }
}

AdaptyProfile _profile({required String id, required String? customerUserId, bool premium = false}) {
  return AdaptyProfileJSONBuilder.fromJsonValue({
    'profile_id': id,
    'segment_hash': 'segment',
    if (customerUserId != null) 'customer_user_id': customerUserId,
    'timestamp': 1,
    'is_test_user': true,
    if (premium)
      'paid_access_levels': {
        'premium': {
          'id': 'premium',
          'is_active': true,
          'vendor_product_id': 'premium_monthly',
          'store': 'app_store',
          'activated_at': '2026-01-01T00:00:00Z',
          'is_lifetime': false,
          'will_renew': true,
          'is_in_grace_period': false,
          'is_refund': false,
        },
      },
  });
}

AdaptyUIFlowView _flowView({String? locale}) {
  return AdaptyUIFlowViewJSONBuilder.fromJsonValue({
    'id': 'view',
    'placement_id': 'recipes-placement',
    'variation_id': 'variation',
    if (locale != null) 'locale': locale,
  });
}

AdaptyFlow _flow(String id) {
  return AdaptyFlowJSONBuilder.fromJsonValue({
    'placement': {
      'developer_id': 'recipes-placement',
      'audience_name': 'All users',
      'revision': 1,
      'ab_test_name': 'Recipes',
      'placement_audience_version_id': 'audience-version',
    },
    'flow_id': id,
    'flow_name': 'Recipes Flow',
    'variation_id': 'variation',
    'response_created_at': 1,
  });
}
