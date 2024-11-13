part of '../adaptyui_action.dart';

extension AdaptyUIActionJSONBuilder on AdaptyUIAction {
  // dynamic get jsonValue => {
  //       _Keys.id: id,
  //       _Keys.templateId: templateId,
  //       _Keys.paywallId: paywallId,
  //       _Keys.paywallVariationId: paywallVariationId,
  //     };

  static AdaptyUIAction fromJsonValue(Map<String, dynamic> json) {
    final typeString = json.string(_Keys.type);
    final value = json.stringIfPresent(_Keys.value);
    final AdaptyUIActionType type;

    switch (typeString) {
      case 'close':
        type = AdaptyUIActionType.close;
        break;
      case 'open_url':
        type = AdaptyUIActionType.openUrl;
        break;
      case 'custom':
        type = AdaptyUIActionType.custom;
        break;
      default:
        type = AdaptyUIActionType.custom;
        break;
    }

    return AdaptyUIAction(type, value);
  }
}

class _Keys {
  static const type = 'type';
  static const value = 'value';
}
