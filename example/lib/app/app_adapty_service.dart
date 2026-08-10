import 'package:adapty_flutter/adapty_flutter.dart';

abstract interface class AppAdaptyService {
  Stream<AdaptyProfile> get didUpdateProfileStream;

  Future<bool> isActivated();

  void setupAfterHotRestart();

  Future<void> activate(AdaptyConfiguration configuration);

  Future<AdaptyProfile> getProfile();

  Future<AdaptyFlow> getFlow({required String placementId});

  Future<void> identify(String customerUserId);

  Future<void> logout();

  Future<AdaptyProfile> restorePurchases();
}

final class DefaultAppAdaptyService implements AppAdaptyService {
  DefaultAppAdaptyService() : _adapty = Adapty();

  final Adapty _adapty;

  @override
  Stream<AdaptyProfile> get didUpdateProfileStream => _adapty.didUpdateProfileStream;

  @override
  Future<bool> isActivated() => _adapty.isActivated();

  @override
  void setupAfterHotRestart() => _adapty.setupAfterHotRestart();

  @override
  Future<void> activate(AdaptyConfiguration configuration) => _adapty.activate(configuration: configuration);

  @override
  Future<AdaptyProfile> getProfile() => _adapty.getProfile();

  @override
  Future<AdaptyFlow> getFlow({required String placementId}) => _adapty.getFlow(placementId: placementId);

  @override
  Future<void> identify(String customerUserId) => _adapty.identify(customerUserId);

  @override
  Future<void> logout() => _adapty.logout();

  @override
  Future<AdaptyProfile> restorePurchases() => _adapty.restorePurchases();
}

abstract interface class AppAdaptyUIService {
  Future<AdaptyUIFlowView> createFlowView({required AdaptyFlow flow});

  void setFlowsEventsObserver(AdaptyUIFlowsEventsObserver? observer);

  Future<void> openUrl(String url, {required AdaptyWebPresentation openIn});
}

final class DefaultAppAdaptyUIService implements AppAdaptyUIService {
  DefaultAppAdaptyUIService() : _adaptyUI = AdaptyUI();

  final AdaptyUI _adaptyUI;

  @override
  Future<AdaptyUIFlowView> createFlowView({required AdaptyFlow flow}) => _adaptyUI.createFlowView(flow: flow);

  @override
  void setFlowsEventsObserver(AdaptyUIFlowsEventsObserver? observer) {
    _adaptyUI.setFlowsEventsObserver(observer);
  }

  @override
  Future<void> openUrl(String url, {required AdaptyWebPresentation openIn}) {
    return _adaptyUI.openUrl(url, openIn: openIn);
  }
}
