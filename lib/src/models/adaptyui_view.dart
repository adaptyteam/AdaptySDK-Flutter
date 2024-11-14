import 'package:adapty_flutter/src/models/private/json_builder.dart';
import 'package:meta/meta.dart' show immutable;

import '../adapty.dart';
import 'adaptyui_dialog.dart';

part 'private/adaptyui_view_json_builder.dart';

@immutable
class AdaptyUIView {
  /// The unique identifier of the view.
  final String id;

  /// The identifier of paywall.
  final String placementId;

  /// The identifier of paywall variation.
  final String paywallVariationId;

  const AdaptyUIView._(
    this.id,
    this.placementId,
    this.paywallVariationId,
  );

  @override
  String toString() => '(id: $id, '
      'id: $id, '
      'placementId: $placementId, '
      'paywallVariationId: $paywallVariationId';

  /// Call this function if you wish to present the view.
  Future<void> present() => AdaptyUI().presentPaywallView(this);

  /// Call this function if you wish to dismiss the view.
  Future<void> dismiss() => AdaptyUI().dismissPaywallView(this);

  /// Call this function if you wish to present the dialog.
  ///
  /// **Parameters**
  /// - [dialog]: an [AdaptyUIDialog] object, description of the desired dialog.
  Future<void> showDialog(AdaptyUIDialog dialog) => AdaptyUI().showDialog(this, dialog);
}
