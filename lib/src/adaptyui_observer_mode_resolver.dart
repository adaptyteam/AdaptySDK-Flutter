import 'models/adaptyui/adaptyui_flow_view.dart';
import 'models/adapty_paywall_product.dart';

/// Makes purchases and restores for flows in Observer mode; set it with `AdaptyUI().setObserverModeResolver()`.
///
/// The flow waits until you call `onFinishPurchase` or `onFinishRestore`. If a method throws before that, or the SDK
/// can't read the request, the flow's purchase or restore never finishes.
abstract class AdaptyUIObserverModeResolver {
  void observerModeDidInitiatePurchase(AdaptyUIFlowView view, AdaptyPaywallProduct product,
      void Function() onStartPurchase, void Function() onFinishPurchase);

  void observerModeDidInitiateRestore(AdaptyUIFlowView view,
      void Function() onStartRestore, void Function() onFinishRestore);
}
