import 'models/adaptyui/adaptyui_flow_view.dart';
import 'models/adaptyui/adaptyui_permission.dart';
import 'models/adaptyui/adaptyui_permission_result.dart';

abstract class AdaptyUISystemRequestsHandler {
  /// Called when a flow asks for [permission]. Request the permission from the OS (declare it in your app first) and
  /// return its result. If this method throws, the flow receives `denied`.
  Future<AdaptyUIPermissionResult> handlePermission(
      AdaptyUIFlowView view, AdaptyUIPermission permission, Map<String, String>? customArgs);

  Future<void> handleAppReviewRequest(AdaptyUIFlowView view) async {}
}
