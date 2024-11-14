part of '../adaptyui_view.dart';

extension AdaptyUIViewJSONBuilder on AdaptyUIView {
  dynamic get jsonValue => {
        _Keys.id: id,
        _Keys.placementId: placementId,
        _Keys.paywallVariationId: paywallVariationId,
      };

  static AdaptyUIView fromJsonValue(Map<String, dynamic> json) {
    return AdaptyUIView._(
      json.string(_Keys.id),
      json.string(_Keys.placementId),
      json.string(_Keys.paywallVariationId),
    );
  }
}

class _Keys {
  static const id = 'id';
  static const placementId = 'placement_id';
  static const paywallVariationId = 'paywall_variation_id';
}
