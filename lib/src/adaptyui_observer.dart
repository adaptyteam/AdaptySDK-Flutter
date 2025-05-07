import 'models/adapty_paywall_product.dart';
import 'models/adapty_profile.dart';
import 'models/adapty_error.dart';
import 'models/adaptyui_action.dart';
import 'models/adapty_purchase_result.dart';

import 'models/adaptyui_view.dart';

abstract class AdaptyUIObserver {
  /// If the user presses the close button, this method will be invoked.
  ///
  /// The default implementation is simply dismissing the view:
  /// ```
  /// view.dismiss()
  /// ```
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  void paywallViewDidPerformAction(AdaptyUIView view, AdaptyUIAction action) {
    switch (action) {
      case const CloseAction():
      case const AndroidSystemBackAction():
        view.dismiss();
        break;
      default:
        break;
    }
  }

  /// If product was selected for purchase (by user or by system), this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] which was selected.
  void paywallViewDidSelectProduct(AdaptyUIView view, String productId) {}

  /// If user initiates the purchase process, this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] of the purchase.
  void paywallViewDidStartPurchase(AdaptyUIView view, AdaptyPaywallProduct product) {}

  /// This method is invoked when a successful purchase is made.
  ///
  /// The default implementation is simply dismissing the controller:
  /// ```
  /// view.dismiss()
  /// ```
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] of the purchase.
  /// - [purchaseResult]: an [AdaptyPurchaseResult] object containing the information about successful purchase or it cancellation.
  void paywallViewDidFinishPurchase(
    AdaptyUIView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) =>
      view.dismiss();

  /// This method is invoked when the purchase process fails.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] of the purchase.
  /// - [error]: an [AdaptyError] object representing the error.
  void paywallViewDidFailPurchase(AdaptyUIView view, AdaptyPaywallProduct product, AdaptyError error) {}

  /// If user initiates the restore process, this method will be invoked.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  void paywallViewDidStartRestore(AdaptyUIView view) {}

  /// This method is invoked when a successful restore is made.
  ///
  /// Check if the [AdaptyProfile] object contains the desired access level, and if so, the controller can be dismissed.
  /// ```
  /// view.dismiss()
  /// ```
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  /// - [profile]: an [AdaptyProfile] object containing up to date information about the user.
  void paywallViewDidFinishRestore(AdaptyUIView view, AdaptyProfile profile);

  /// This method is invoked when the restore process fails.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void paywallViewDidFailRestore(AdaptyUIView view, AdaptyError error) {}

  /// This method will be invoked in case of errors during the screen rendering process.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void paywallViewDidFailRendering(AdaptyUIView view, AdaptyError error);

  /// This method is invoked in case of errors during the products loading process.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  /// - [error]: an [AdaptyError] object representing the error.
  void paywallViewDidFailLoadingProducts(AdaptyUIView view, AdaptyError error) {}

  /// This method is invoked when the web payment navigation is finished.
  ///
  /// **Parameters**
  /// - [view]: an [AdaptyUIView] within which the event occurred.
  /// - [product]: an [AdaptyPaywallProduct] object containing the information about the product.
  /// - [error]: an [AdaptyError] object representing the error.
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) {}
}
