import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/foundation.dart';

import 'app_adapty_service.dart';
import 'app_constants.dart';
import 'user_manager.dart';

class AppController extends ChangeNotifier {
  AppController({required UserManager userManager, AppAdaptyService? adapty, AppAdaptyUIService? adaptyUI})
    : _userManager = userManager,
      _adapty = adapty ?? DefaultAppAdaptyService(),
      _adaptyUI = adaptyUI ?? DefaultAppAdaptyUIService();

  final UserManager _userManager;
  final AppAdaptyService _adapty;
  final AppAdaptyUIService _adaptyUI;

  StreamSubscription<AdaptyProfile>? _profileSubscription;
  _ModalFlowObserver? _modalFlowObserver;

  bool configurationInvalid = false;
  bool isInitializing = false;
  bool isInitialized = false;
  bool isLoadingFlow = false;
  bool isReloadingProfile = false;
  bool isRestoringPurchases = false;
  bool isPresentingFlow = false;
  bool isUpdatingIdentity = false;

  int _identityRevision = 0;
  int _profileRequestSequence = 0;
  int _profileUpdateSequence = 0;
  int _flowRequestSequence = 0;
  int _errorOperationSequence = 0;

  String? userId;
  String? errorMessage;
  AdaptyProfile? profile;
  AdaptyFlow? flow;

  bool get canUseSdk => isInitialized && !isInitializing && !isUpdatingIdentity && !configurationInvalid;

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

    final errorOperation = _claimErrorOperation();
    isInitializing = true;
    _setErrorIfOwned(errorOperation, null);
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

        await _adapty.activate(configuration);
      }

      _profileSubscription = _adapty.didUpdateProfileStream.listen(_applyProfile);

      await _refreshProfileAndFlow(errorOperation: errorOperation);

      isInitialized = true;
    } catch (error) {
      _setErrorIfOwned(errorOperation, _messageFor(error));
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> reloadProfile() async {
    if (configurationInvalid || isUpdatingIdentity) {
      return;
    }

    final errorOperation = _claimErrorOperation();
    _setErrorIfOwned(errorOperation, null);
    notifyListeners();

    final revision = _identityRevision;
    final result = await _loadProfile(revision);
    if (result.isCurrent && _setErrorIfOwned(errorOperation, result.error)) {
      notifyListeners();
    }
  }

  Future<void> loadFlow() async {
    if (configurationInvalid || isUpdatingIdentity) {
      return;
    }

    final errorOperation = _claimErrorOperation();
    _setErrorIfOwned(errorOperation, null);
    notifyListeners();

    final revision = _identityRevision;
    final result = await _loadFlow(revision);
    if (result.isCurrent && _setErrorIfOwned(errorOperation, result.error)) {
      notifyListeners();
    }
  }

  Future<void> login(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || !canUseSdk || isPresentingFlow || _modalFlowObserver != null) {
      return;
    }

    await _updateIdentity(
      newUserId: trimmed,
      nativeAction: () => _adapty.identify(trimmed),
      persistAction: () => _userManager.login(trimmed),
    );
  }

  Future<void> logout() async {
    if (!canUseSdk || isPresentingFlow || _modalFlowObserver != null) {
      return;
    }

    await _updateIdentity(newUserId: null, nativeAction: _adapty.logout, persistAction: _userManager.logout);
  }

  Future<void> restorePurchases() async {
    if (!canUseSdk) {
      return;
    }

    final revision = _identityRevision;
    final errorOperation = _claimErrorOperation();
    isRestoringPurchases = true;
    _setErrorIfOwned(errorOperation, null);
    notifyListeners();

    try {
      final restoredProfile = await _adapty.restorePurchases();
      if (_isCurrentRevision(revision)) {
        _applyProfile(restoredProfile, notify: false);
      }
    } catch (error) {
      if (_isCurrentRevision(revision)) {
        _setErrorIfOwned(errorOperation, _messageFor(error));
      }
    } finally {
      if (_isCurrentRevision(revision)) {
        isRestoringPurchases = false;
        notifyListeners();
      }
    }
  }

  Future<void> presentFlowModally() async {
    if (!canUseSdk || isPresentingFlow || _modalFlowObserver != null) {
      return;
    }

    final errorOperation = _claimErrorOperation();
    isPresentingFlow = true;
    _setErrorIfOwned(errorOperation, null);
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
      _setErrorIfOwned(errorOperation, _messageFor(error));
    } finally {
      isPresentingFlow = false;
      notifyListeners();
    }
  }

  void applyProfileFromFlow(AdaptyProfile value) {
    _applyProfile(value);
  }

  void reportError(Object error) {
    final errorOperation = _claimErrorOperation();
    _setErrorIfOwned(errorOperation, _messageFor(error));
    notifyListeners();
  }

  void clearError() {
    final errorOperation = _claimErrorOperation();
    _setErrorIfOwned(errorOperation, null);
    notifyListeners();
  }

  Future<void> _updateIdentity({
    required String? newUserId,
    required Future<void> Function() nativeAction,
    required Future<void> Function() persistAction,
  }) async {
    final errorOperation = _claimErrorOperation();
    isUpdatingIdentity = true;
    _setErrorIfOwned(errorOperation, null);
    notifyListeners();

    try {
      try {
        await nativeAction();
      } catch (error) {
        _setErrorIfOwned(errorOperation, _contextualError('Identity', error));
        return;
      }

      _publishIdentityTransition(newUserId, errorOperation);

      final errors = <String>[];
      try {
        await persistAction();
      } catch (error) {
        errors.add(_contextualError('Local identity', error));
      }

      await _refreshProfileAndFlow(errorOperation: errorOperation, initialErrors: errors);
    } finally {
      isUpdatingIdentity = false;
      notifyListeners();
    }
  }

  void _publishIdentityTransition(String? newUserId, int errorOperation) {
    _identityRevision += 1;
    _profileRequestSequence += 1;
    _flowRequestSequence += 1;
    userId = newUserId;
    profile = null;
    flow = null;
    isReloadingProfile = false;
    isLoadingFlow = false;
    isRestoringPurchases = false;
    _setErrorIfOwned(errorOperation, null);
    notifyListeners();
  }

  Future<void> _refreshProfileAndFlow({required int errorOperation, List<String> initialErrors = const []}) async {
    final revision = _identityRevision;
    final errors = <String>[...initialErrors];
    if (_setErrorIfOwned(errorOperation, _joinedErrors(errors))) {
      notifyListeners();
    }

    final profileResult = await _loadProfile(revision);
    if (!profileResult.isCurrent) {
      return;
    }
    if (profileResult.error != null) {
      errors.add(profileResult.error!);
    }

    final flowResult = await _loadFlow(revision);
    if (!flowResult.isCurrent) {
      return;
    }
    if (flowResult.error != null) {
      errors.add(flowResult.error!);
    }

    if (_setErrorIfOwned(errorOperation, _joinedErrors(errors))) {
      notifyListeners();
    }
  }

  Future<({String? error, bool isCurrent})> _loadProfile(int revision) async {
    if (!_isCurrentRevision(revision)) {
      return (error: null, isCurrent: false);
    }

    final request = ++_profileRequestSequence;
    final profileUpdateAtStart = _profileUpdateSequence;
    bool isCurrentRequest() => _isCurrentRevision(revision) && request == _profileRequestSequence;
    bool canPublishResult() => isCurrentRequest() && profileUpdateAtStart == _profileUpdateSequence;

    isReloadingProfile = true;
    notifyListeners();

    try {
      final loadedProfile = await _adapty.getProfile();
      if (canPublishResult()) {
        _applyProfile(loadedProfile, notify: false);
      }
      return (error: null, isCurrent: isCurrentRequest());
    } catch (error) {
      return (error: canPublishResult() ? _contextualError('Profile', error) : null, isCurrent: isCurrentRequest());
    } finally {
      if (isCurrentRequest()) {
        isReloadingProfile = false;
        notifyListeners();
      }
    }
  }

  Future<({String? error, bool isCurrent})> _loadFlow(int revision) async {
    if (!_isCurrentRevision(revision)) {
      return (error: null, isCurrent: false);
    }

    final request = ++_flowRequestSequence;
    bool isCurrentRequest() => _isCurrentRevision(revision) && request == _flowRequestSequence;

    isLoadingFlow = true;
    notifyListeners();

    try {
      final loadedFlow = await _adapty.getFlow(placementId: AppConstants.placementId);
      if (isCurrentRequest()) {
        flow = loadedFlow;
      }
      return (error: null, isCurrent: isCurrentRequest());
    } catch (error) {
      return (error: isCurrentRequest() ? _contextualError('Flow', error) : null, isCurrent: isCurrentRequest());
    } finally {
      if (isCurrentRequest()) {
        isLoadingFlow = false;
        notifyListeners();
      }
    }
  }

  bool _applyProfile(AdaptyProfile value, {bool notify = true}) {
    if (value.customerUserId != userId) {
      return false;
    }

    _profileUpdateSequence += 1;
    profile = value;
    if (notify) {
      notifyListeners();
    }
    return true;
  }

  bool _isCurrentRevision(int revision) => revision == _identityRevision;

  int _claimErrorOperation() => ++_errorOperationSequence;

  bool _setErrorIfOwned(int operation, String? value) {
    if (operation != _errorOperationSequence) {
      return false;
    }

    errorMessage = value;
    return true;
  }

  String? _joinedErrors(List<String> errors) => errors.isEmpty ? null : errors.join('\n\n');

  String _contextualError(String context, Object error) => '$context: ${_messageFor(error)}';

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
    required AppAdaptyUIService adaptyUI,
    required VoidCallback onDisappear,
    required ValueChanged<AdaptyProfile> onProfile,
    required void Function(Object error) onError,
  }) : _adaptyUI = adaptyUI,
       _onDisappear = onDisappear,
       _onProfile = onProfile,
       _onError = onError;

  final String viewId;
  final AppAdaptyUIService _adaptyUI;
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
