part of 'adapty.dart';

typedef AdaptyUIProductsTitlesResolver = String? Function(String productId);

class AdaptyUI {
  static final AdaptyUI _instance = AdaptyUI._internal();

  factory AdaptyUI() => _instance;

  AdaptyUI._internal();

  AdaptyUIObserver? _observer;

  /// Use this method to set the AdaptyUI events observer.
  void setObserver(AdaptyUIObserver observer) {
    AdaptyLogger.write(AdaptyLogLevel.verbose, 'AdaptyUI.setObserver()');
    _observer = observer;
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
        Argument.paywall: paywall.jsonValue,
        Argument.preloadProducts: preloadProducts,
        if (loadTimeout != null) Argument.loadTimeout: loadTimeout.inMilliseconds.toDouble() / 1000.0,
        if (customTags != null) Argument.customTags: customTags,
        if (customTimers != null)
          Argument.customTimers: customTimers.map((key, value) => MapEntry(
                key,
                value.toAdaptyValidString(),
              )),
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
  Future<void> dismissPaywallView(AdaptyUIView view) async {
    return Adapty()._invokeMethod<void>(
      Method.dismissView,
      (data) => null,
      {
        Argument.id: view.id,
        Argument.destroy: false,
      },
    );
  }

  /// Call this function if you wish to present the dialog.
  ///
  /// **Parameters**
  /// - [title]: The title of the dialog.
  /// - [content]: Descriptive text that provides additional details about the reason for the dialog.
  /// - [primaryActionTitle]: The action title to display as part of the dialog. If you provide two actions, be sure the `defaultAction` cancels the operation and leaves things unchanged.
  /// - [secondaryActionTitle]: The secondary action title to display as part of the dialog.
  Future<AdaptyUIDialogActionType> showDialog(
    AdaptyUIView view, {
    required String title,
    required String content,
    required String primaryActionTitle,
    String? secondaryActionTitle,
  }) async {
    final dialog = AdaptyUIDialog(
      title: title,
      content: content,
      primaryActionTitle: primaryActionTitle,
      secondaryActionTitle: secondaryActionTitle,
    );

    return await Adapty()._invokeMethod<AdaptyUIDialogActionType>(
      Method.showDialog,
      (data) => AdaptyUIDialogActionTypeJSONBuilder.fromJsonValue(data as String),
      {
        Argument.id: view.id,
        Argument.configuration: dialog.jsonValue,
      },
    );
  }
}
