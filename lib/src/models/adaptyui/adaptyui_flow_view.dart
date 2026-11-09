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
  /// shown by [AdaptyUIFlowPlatformView].
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

  /// Call this function if you wish to present the view.
  ///
  /// On iOS, [iosPresentationStyle] picks a full-screen presentation, the default, or a page
  /// sheet the user can swipe down; Android ignores it.
  ///
  /// Works only with a view created by [AdaptyUI.createFlowView], including the instances of
  /// it that your observers and handlers receive. For a view shown by [AdaptyUIFlowPlatformView],
  /// the call fails with an [AdaptyError] with [AdaptyErrorCode.wrongParam].
  ///
  /// The call also fails with [AdaptyErrorCode.wrongParam] when the view is already released or a
  /// flow view is already presented.
  Future<void> present({
    AdaptyUIIOSPresentationStyle iosPresentationStyle = AdaptyUIIOSPresentationStyle.fullScreen,
  }) =>
      AdaptyUI().presentFlowView(this, iosPresentationStyle: iosPresentationStyle);

  /// Call this function if you wish to dismiss the view.
  ///
  /// Works only with a view created by [AdaptyUI.createFlowView], including the instances of
  /// it that your observers and handlers receive. For a view shown by [AdaptyUIFlowPlatformView],
  /// the call fails with an [AdaptyError] with [AdaptyErrorCode.wrongParam].
  ///
  /// The call also fails with [AdaptyErrorCode.wrongParam] when the view is already released, for
  /// example by an earlier [dismiss] that has completed.
  ///
  /// **Parameters**
  /// - [destroy]: whether to release the view along with dismissing it. With `true`, the
  /// default, the view is released and [present] fails afterwards — call
  /// [AdaptyUI.createFlowView] again to show the flow once more. Pass `false` to keep the
  /// view alive, so it can be presented again and resumes where the user left it, with the
  /// screen they were on and the state the flow had built up. A view kept alive this way
  /// is held until it is released with [AdaptyUIFlowView.destroy], or until it is presented
  /// again and dismissed with `destroy: true`.
  Future<void> dismiss({bool destroy = true}) => AdaptyUI().dismissFlowView(this, destroy: destroy);

  /// Call this function if you wish to release the view when you won't present it (again): if
  /// it was never presented, if [dismiss] kept it alive with `destroy: false`, or, on iOS, if the
  /// user swiped it down as a page sheet.
  ///
  /// After [dismiss] with `destroy: true`, the default, the view is already released and
  /// there is no need to call this function. Once the view is released, [present] fails —
  /// call [AdaptyUI.createFlowView] again to show the flow once more. Calling this
  /// function when the view is already released fails with an [AdaptyError] with
  /// [AdaptyErrorCode.wrongParam].
  ///
  /// If the view is still presented, it is closed and released: on iOS without the closing
  /// animation, on Android with it, and the call does not wait for the view to close. To close
  /// a presented view, use [dismiss] with `destroy: true` instead: it animates on both
  /// platforms and completes once the view is closed.
  ///
  /// On iOS, a view presented with [AdaptyUIIOSPresentationStyle.pageSheet] can be swiped down
  /// by the user. It then closes without [dismiss] and stays alive: present it again, or
  /// release it with this function when you won't.
  ///
  /// Works only with a view created by [AdaptyUI.createFlowView], including the instances of
  /// it that your observers and handlers receive. For a view shown by [AdaptyUIFlowPlatformView],
  /// the call fails with an [AdaptyError] with [AdaptyErrorCode.wrongParam].
  Future<void> destroy() => AdaptyUI().destroyFlowView(this);

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
