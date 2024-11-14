part of 'adapty.dart';

typedef AdaptyUIProductsTitlesResolver = String? Function(String productId);

class AdaptyUI {
  static final AdaptyUI _instance = AdaptyUI._internal();

  factory AdaptyUI() => _instance;

  AdaptyUI._internal();

  bool _activated = false;
  AdaptyUIObserver? _observer;

  /// Activates the [AdaptyUI] module.
  ///
  /// **Parameters**
  /// - [configuration]: an [AdaptyUIConfiguration] object, describing the desired configuration.
  /// - [observer]: an [AdaptyUIObserver] object, which will receive the events.
  Future<void> activate({
    AdaptyUIConfiguration configuration = AdaptyUIConfiguration.defaultValue,
    required AdaptyUIObserver observer,
  }) async {
    _observer = observer;

    if (_activated) return;

    await Adapty()._invokeMethod<void>(
      Method.activateUI,
      (data) => null,
      {
        Argument.configuration: json.encode(configuration.jsonValue),
      },
    );

    _activated = true;
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
    Duration? loadTimeout,
    bool preloadProducts = false,
    Map<String, String>? customTags,
    Map<String, DateTime>? customTimers,
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
        Argument.preloadProducts: preloadProducts,
        if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
        if (customTags != null) Argument.customTags: json.encode(customTags),
        if (customTimers != null) Argument.customTimers: json.encode(customTimers),
        if (androidPersonalizedOffers != null) Argument.personalizedOffers: json.encode(androidPersonalizedOffers),
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
