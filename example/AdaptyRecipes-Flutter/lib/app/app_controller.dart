import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';

import 'app_constants.dart';
import 'user_manager.dart';

class AppController extends ChangeNotifier {
  AppController({required UserManager userManager}) : _userManager = userManager;

  final UserManager _userManager;
  final Adapty _adapty = Adapty();
  final AdaptyUI _adaptyUI = AdaptyUI();

  StreamSubscription<AdaptyProfile>? _profileSubscription;
  _ModalFlowObserver? _modalFlowObserver;

  bool configurationInvalid = false;
  bool isInitializing = false;
  bool isInitialized = false;
  bool isLoadingFlow = false;
  bool isReloadingProfile = false;
  bool isRestoringPurchases = false;
  bool isPresentingFlow = false;

  String? userId;
  String? errorMessage;
  AdaptyProfile? profile;
  AdaptyFlow? flow;

  bool get canUseSdk => isInitialized && !isInitializing && !configurationInvalid;

  bool get isPremiumUser => profile?.accessLevels[AppConstants.accessLevelId]?.isActive ?? false;

  Future<void> initialize() async {
    if (isInitializing || isInitialized) {
      return;
    }

    configurationInvalid = !AppConstants.debugAssertValidConfiguration();
    if (configurationInvalid) {
      notifyListeners();
      return;
    }

    isInitializing = true;
    errorMessage = null;
    notifyListeners();

    try {
      userId = await _userManager.currentUserId();

      var isActivated = false;
      if (kDebugMode) {
        isActivated = await _adapty.isActivated();
      }

      if (isActivated) {
        _adapty.setupAfterHotRestart();
      } else {
        final configuration = AdaptyConfiguration(apiKey: AppConstants.adaptyApiKey)
          ..withCustomerUserIdIfPresent(userId)
          ..withLogLevel(AdaptyLogLevel.info)
          ..withActivateUI(true);

        await _adapty.activate(configuration: configuration);
      }

      _profileSubscription = _adapty.didUpdateProfileStream.listen(_applyProfile);

      await reloadProfile();
      await loadFlow();

      isInitialized = true;
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> reloadProfile() async {
    if (configurationInvalid) {
      return;
    }

    isReloadingProfile = true;
    errorMessage = null;
    notifyListeners();

    try {
      _applyProfile(await _adapty.getProfile(), notify: false);
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isReloadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> loadFlow() async {
    if (configurationInvalid) {
      return;
    }

    isLoadingFlow = true;
    errorMessage = null;
    notifyListeners();

    try {
      flow = await _adapty.getFlow(placementId: AppConstants.placementId);
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isLoadingFlow = false;
      notifyListeners();
    }
  }

  Future<void> login(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !canUseSdk) {
      return;
    }

    errorMessage = null;
    notifyListeners();

    try {
      await _userManager.login(trimmed);
      userId = trimmed;
      notifyListeners();

      await _adapty.identify(trimmed);
      await reloadProfile();
    } catch (error) {
      errorMessage = _messageFor(error);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (!canUseSdk) {
      return;
    }

    errorMessage = null;
    notifyListeners();

    try {
      await _userManager.logout();
      userId = null;
      notifyListeners();

      await _adapty.logout();
      await reloadProfile();
    } catch (error) {
      errorMessage = _messageFor(error);
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    if (!canUseSdk) {
      return;
    }

    isRestoringPurchases = true;
    errorMessage = null;
    notifyListeners();

    try {
      _applyProfile(await _adapty.restorePurchases(), notify: false);
    } catch (error) {
      errorMessage = _messageFor(error);
    } finally {
      isRestoringPurchases = false;
      notifyListeners();
    }
  }

  Future<void> presentFlowModally() async {
    if (!canUseSdk || isPresentingFlow || _modalFlowObserver != null) {
      return;
    }

    isPresentingFlow = true;
    errorMessage = null;
    notifyListeners();

    try {
      final currentFlow = flow ?? await _adapty.getFlow(placementId: AppConstants.placementId);
      flow = currentFlow;

      final view = await _adaptyUI.createFlowView(flow: currentFlow);
      final observer = _ModalFlowObserver(
        viewId: view.id,
        adaptyUI: _adaptyUI,
        onDisappear: _clearModalFlowObserver,
        onProfile: _applyProfile,
        onError: reportError,
      );
      _modalFlowObserver = observer;
      _adaptyUI.setFlowsEventsObserver(observer);
      await view.present();
    } catch (error) {
      _clearModalFlowObserver();
      errorMessage = _messageFor(error);
    } finally {
      isPresentingFlow = false;
      notifyListeners();
    }
  }

  void applyProfileFromFlow(AdaptyProfile value) {
    _applyProfile(value);
  }

  void reportError(Object error) {
    errorMessage = _messageFor(error);
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void _applyProfile(AdaptyProfile value, {bool notify = true}) {
    profile = value;
    if (notify) {
      notifyListeners();
    }
  }

  String _messageFor(Object error) {
    if (error is AdaptyError) {
      final detail = error.detail;
      return 'Adapty error ${error.code}: ${error.message}${detail == null ? '' : '\n$detail'}';
    }

    return error.toString();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _clearModalFlowObserver();
    super.dispose();
  }

  void _clearModalFlowObserver() {
    if (_modalFlowObserver == null) {
      return;
    }

    _modalFlowObserver = null;
    _adaptyUI.setFlowsEventsObserver(null);
  }
}

class _ModalFlowObserver extends AdaptyUIFlowsEventsObserver {
  _ModalFlowObserver({
    required this.viewId,
    required AdaptyUI adaptyUI,
    required VoidCallback onDisappear,
    required ValueChanged<AdaptyProfile> onProfile,
    required void Function(Object error) onError,
  }) : _adaptyUI = adaptyUI,
       _onDisappear = onDisappear,
       _onProfile = onProfile,
       _onError = onError;

  final String viewId;
  final AdaptyUI _adaptyUI;
  final VoidCallback _onDisappear;
  final ValueChanged<AdaptyProfile> _onProfile;
  final void Function(Object error) _onError;

  @override
  void flowViewDidDisappear(AdaptyUIFlowView view) {
    if (_isCurrentView(view)) {
      _onDisappear();
    }
  }

  @override
  void flowViewDidPerformAction(AdaptyUIFlowView view, AdaptyUIAction action) {
    if (!_isCurrentView(view)) {
      return;
    }

    switch (action) {
      case const CloseAction():
      case const AndroidSystemBackAction():
        unawaited(view.dismiss());
        break;
      case OpenUrlAction(:final url, :final openIn):
        unawaited(_adaptyUI.openUrl(url, openIn: openIn));
        break;
      default:
        break;
    }
  }

  @override
  void flowViewDidFinishPurchase(
    AdaptyUIFlowView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) {
    if (_isCurrentView(view) && purchaseResult is AdaptyPurchaseResultSuccess) {
      _onProfile(purchaseResult.profile);
    }
  }

  @override
  void flowViewDidFinishRestore(AdaptyUIFlowView view, AdaptyProfile profile) {
    if (_isCurrentView(view)) {
      _onProfile(profile);
    }
  }

  @override
  void flowViewDidFailPurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product, AdaptyError error) {
    if (_isCurrentView(view)) {
      _onError(error);
    }
  }

  @override
  void flowViewDidFailRestore(AdaptyUIFlowView view, AdaptyError error) {
    if (_isCurrentView(view)) {
      _onError(error);
    }
  }

  @override
  void flowViewDidReceiveError(AdaptyUIFlowView view, AdaptyError error) {
    if (_isCurrentView(view)) {
      unawaited(view.dismiss());
      _onError(error);
    }
  }

  @override
  void flowViewDidFailLoadingProducts(AdaptyUIFlowView view, AdaptyError error) {
    if (_isCurrentView(view)) {
      _onError(error);
    }
  }

  @override
  void flowViewDidFinishWebPaymentNavigation(AdaptyUIFlowView view, AdaptyPaywallProduct? product, AdaptyError? error) {
    if (_isCurrentView(view) && error != null) {
      _onError(error);
    }
  }

  bool _isCurrentView(AdaptyUIFlowView view) => view.id == viewId;
}

extension on AdaptyConfiguration {
  void withCustomerUserIdIfPresent(String? customerUserId) {
    final value = customerUserId?.trim();
    if (value == null || value.isEmpty) {
      return;
    }

    withCustomerUserId(value);
  }
}
