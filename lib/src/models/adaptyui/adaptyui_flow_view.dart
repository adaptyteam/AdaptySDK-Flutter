import 'package:meta/meta.dart' show immutable;

import '../../adapty.dart';
import 'adaptyui_dialog.dart';
import 'adaptyui_ios_presentation_style.dart';
import '../private/json_builder.dart';

part '../private/adaptyui_flow_view_json_builder.dart';

@immutable
class AdaptyUIFlowView {
  /// The unique identifier of the view.
  final String id;

  /// The identifier of placement.
  final String placementId;

  /// The identifier of flow variation.
  final String variationId;

  /// The localization the view was actually built with.
  ///
  /// It is the locale passed to [AdaptyUI.createFlowView] when the flow has that
  /// localization, `en` when no locale was passed and the flow has `en`, and the
  /// flow's default localization in every other case. On iOS it is `null` in the view passed to
  /// the [AdaptyUISystemRequestsHandler] and [AdaptyUIObserverModeResolver] methods for a flow
  /// shown by [AdaptyUIFlowPlatformView], and in the view passed with the error of a flow that
  /// widget never showed.
  final String? locale;

  const AdaptyUIFlowView._(
    this.id,
    this.placementId,
    this.variationId,
    this.locale,
  );

  @override
  String toString() => '(id: $id, '
      'placementId: $placementId, '
      'variationId: $variationId, '
      'locale: $locale)';

  /// Presents this view. On iOS, [iosPresentationStyle] picks full screen, the default, or a page
  /// sheet the user can swipe down; Android ignores it.
  ///
  /// Works only with a view created by [AdaptyUI.createFlowView]. Fails with
  /// [AdaptyErrorCode.wrongParam] for a view shown by [AdaptyUIFlowPlatformView], once this view is
  /// released, or while a flow view is already presented. On iOS, it doesn't fail while the
  /// presented flow has the in-app browser, an alert or another screen over it: this flow is shown
  /// on top.
  Future<void> present({
    AdaptyUIIOSPresentationStyle iosPresentationStyle = AdaptyUIIOSPresentationStyle.fullScreen,
  }) =>
      AdaptyUI().presentFlowView(this, iosPresentationStyle: iosPresentationStyle);

  /// Dismisses this view. Works only with a view created by [AdaptyUI.createFlowView]: for a view
  /// shown by [AdaptyUIFlowPlatformView], or once this view is released, it fails with
  /// [AdaptyErrorCode.wrongParam].
  ///
  /// **Parameters**
  /// - [destroy]: with `true`, the default, the view is released: create a new one to show the
  /// flow again. With `false` it stays alive, and [present] resumes it where the user left it,
  /// until you release it with [destroy] or dismiss it with `destroy: true`. On Android, what its
  /// script sends while it is dismissed, such as a custom action, reaches your app only once it is
  /// presented again.
  Future<void> dismiss({bool destroy = true}) => AdaptyUI().dismissFlowView(this, destroy: destroy);

  /// Releases this view when you won't present it again: if it was never presented, if [dismiss]
  /// kept it alive with `destroy: false`, or, on iOS, if the user swiped it down as a page sheet,
  /// which leaves it alive until released. After [dismiss] with `destroy: true` it is already
  /// released. A presented view is closed, on iOS without the animation, and the call doesn't
  /// wait for it: to close it, use [dismiss] instead. Don't release it on
  /// [AdaptyUIFlowsEventsObserver.flowViewDidDisappear] alone: on iOS, that method is also
  /// invoked when the in-app browser opens over the flow.
  ///
  /// Works only with a view created by [AdaptyUI.createFlowView]: for a view shown by
  /// [AdaptyUIFlowPlatformView], or once this view is released, it fails with
  /// [AdaptyErrorCode.wrongParam].
  Future<void> destroy() => AdaptyUI().destroyFlowView(this);

  /// Sends [payload] to the script of this flow as the `applicationMsg` SDK event.
  ///
  /// Completes once the message is passed to the flow, not once the script has handled it. Await
  /// each call when the order matters. Fails with [AdaptyErrorCode.wrongParam] if `json.encode`
  /// can't encode [payload], or once [dismiss] or [destroy] has released this view. If it comes
  /// from [AdaptyUI.createFlowView], send once [AdaptyUIFlowsEventsObserver.flowViewDidAppear] is
  /// called: on Android it silently drops a message sent before its script starts, even right after
  /// [present] returns. On iOS, what its script sends back before its first [present] is lost.
  Future<void> sendAppMessage(Map<String, dynamic> payload) => AdaptyUI().sendAppMessage(this, payload);

  /// Call this function if you wish to present the dialog.
  ///
  /// **Parameters**
  /// - [title]: The title of the dialog.
  /// - [content]: Descriptive text that provides additional details about the reason for the dialog.
  /// - [primaryActionTitle]: The action title to display as part of the dialog. If you provide two actions, be sure the `defaultAction` cancels the operation and leaves things unchanged.
  /// - [secondaryActionTitle]: The secondary action title to display as part of the dialog.
  Future<AdaptyUIDialogActionType> showDialog({
    required String title,
    required String content,
    required String primaryActionTitle,
    String? secondaryActionTitle,
  }) =>
      AdaptyUI().showDialog(
        id,
        title: title,
        content: content,
        primaryActionTitle: primaryActionTitle,
        secondaryActionTitle: secondaryActionTitle,
      );
}
