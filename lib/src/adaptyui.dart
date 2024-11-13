part of 'adapty.dart';

typedef AdaptyUIProductsTitlesResolver = String? Function(String productId);

class AdaptyUI {
  static final AdaptyUI _instance = AdaptyUI._internal();

  factory AdaptyUI() => _instance;

  AdaptyUI._internal();

  bool _activated = false;
  AdaptyUIObserver? _observer;

  void activate({
    AdaptyUIConfiguration configuration = AdaptyUIConfiguration.defaultValue,
  }) {
    if (_activated) return;

    // _channel.setMethodCallHandler(_handleIncomingMethodCall);
    _activated = true;
  }

  /// Registers the given object as an [AdaptyUI] events observer.
  void addObserver(AdaptyUIObserver observer) => _observer = observer;

  /// Unregisters the given observer.
  void removeObserver(AdaptyUIObserver observer) {
    if (_observer == observer) {
      _observer = null;
    }
  }

  /// Right after receiving ``AdaptyPaywall``, you can create the corresponding ``AdaptyUIView`` to present it afterwards.
  ///
  /// **Parameters**
  /// - [paywall]: an [AdaptyPaywall] object, for which you are trying to get a controller.
  /// - [preloadProducts]: If you pass `true`, `AdaptyUI` will automatically prefetch the required products at the moment of view assembly.
  /// - [androidPersonalizedOffers]: A map that determines whether the price for a given product is personalized.
  /// Key is a string containing `basePlanId` and `vendorProductId` separated by `:`. If `basePlanId` is `null` or empty, only `vendorProductId` is used.
  /// Example: `basePlanId:vendorProductId` or `vendorProductId`.
  /// [Read more](https://developer.android.com/google/play/billing/integrate#personalized-price)
  ///
  /// **Returns**
  /// - an [AdaptyUIView] object, representing the requested paywall screen.
  Future<AdaptyUIView> createPaywallView({
    required AdaptyPaywall paywall,
    required String locale,
    bool preloadProducts = false,
    Map<String, String>? customTags,
    Map<String, bool>? androidPersonalizedOffers,
  }) async {
    return Adapty()._invokeMethod<AdaptyUIView>(
      Method.createView,
      (data) {
        final viewMap = data as Map<String, dynamic>;
        return AdaptyUIViewJSONBuilder.fromJsonValue(viewMap);
      },
      {
        Argument.paywall: json.encode(paywall.jsonValue),
        Argument.locale: locale,
        Argument.preloadProducts: preloadProducts,
        if (customTags != null) Argument.customTags: customTags,
        if (androidPersonalizedOffers != null) Argument.personalizedOffers: androidPersonalizedOffers,
      },
    );
  }

  /// Call this function if you wish to present the view.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] object, for which is representing the view.
  Future<void> presentPaywallView(AdaptyUIView view) async {
    return Adapty()._invokeMethod<void>(
      Method.presentView,
      (data) => null,
      {
        Argument.id: view.id,
      },
    );
  }

  /// Call this function if you wish to dismiss the view.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] object, for which is representing the view.
  Future<void> dismissPaywallView(
    AdaptyUIView view, {
    bool destroy = false,
  }) async {
    return Adapty()._invokeMethod<void>(
      Method.dismissView,
      (data) => null,
      {
        Argument.id: view.id,
        if (destroy) Argument.destroy: destroy,
      },
    );
  }

  /// Call this function if you wish to present the dialog.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] object, for which is representing the view.
  /// - [dialog]: an [AdaptyUIDialog] object, description of the desired dialog.
  Future<void> showDialog(AdaptyUIView view, AdaptyUIDialog dialog) async {
    final dismissActionIndex = await Adapty()._invokeMethod<int?>(
      Method.showDialog,
      (data) => null,
      {
        Argument.id: view.id,
        Argument.configuration: json.encode(dialog.jsonValue),
      },
    );

    switch (dismissActionIndex) {
      case 0:
        dialog.defaultAction.onPressed.call();
        break;
      case 1:
        dialog.secondaryAction?.onPressed.call();
        break;
      default:
        break;
    }
  }
}
