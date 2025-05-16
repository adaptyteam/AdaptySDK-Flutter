import 'package:meta/meta.dart' show immutable;

import '../adapty.dart';
import 'adaptyui_dialog.dart';
import 'private/json_builder.dart';

part 'private/adaptyui_onboarding_view_json_builder.dart';

@immutable
class AdaptyUIOnboardingView {
  /// The unique identifier of the view.
  final String id;

  /// The identifier of paywall.
  final String placementId;

  /// The identifier of paywall variation.
  final String variationId;

  const AdaptyUIOnboardingView._(
    this.id,
    this.placementId,
    this.variationId,
  );

  @override
  String toString() => '(id: $id, '
      'placementId: $placementId, '
      'variationId: $variationId)';

  /// Call this function if you wish to present the view.
  Future<void> present() => AdaptyUI().presentOnboardingView(this);

  /// Call this function if you wish to dismiss the view.
  Future<void> dismiss() => AdaptyUI().dismissOnboardingView(this);

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
