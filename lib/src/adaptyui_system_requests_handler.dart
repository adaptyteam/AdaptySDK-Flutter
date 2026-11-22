import 'models/adaptyui/adaptyui_flow_view.dart';
import 'models/adaptyui/adaptyui_permission.dart';
import 'models/adaptyui/adaptyui_permission_result.dart';

abstract class AdaptyUISystemRequestsHandler {
  /// Called when a flow asks for [permission]. Request the permission from the OS (declare it in your app first) and
  /// return its result. If this method throws, the flow receives `denied`.
  Future<AdaptyUIPermissionResult> handlePermission(
      AdaptyUIFlowView view, AdaptyUIPermission permission, Map<String, String>? customArgs);

  /// Called when a flow asks for an App Store / Google Play review. Does nothing by default: to show the native
  /// prompt, override it and call [AdaptyUI.requestAppReview]. Without a handler set, the SDK shows the native
  /// prompt itself.
  Future<void> handleAppReviewRequest(AdaptyUIFlowView view) async {}
}
