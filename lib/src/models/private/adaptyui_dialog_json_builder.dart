part of '../adaptyui_dialog.dart';

extension AdaptyUIDialogActionJSONBuilder on AdaptyUIDialogAction {
  dynamic get jsonValue => {
        _ActionKeys.title: title,
      };
}

extension AdaptyUIDialogJSONBuilder on AdaptyUIDialog {
  dynamic get jsonValue => {
        if (title != null) _DialogKeys.title: title,
        if (content != null) _DialogKeys.content: content,
        _DialogKeys.defaultAction: defaultAction.jsonValue,
        if (secondaryAction != null) _DialogKeys.secondaryAction: secondaryAction!.jsonValue,
      };
}

class _ActionKeys {
  static const title = 'title';
}

class _DialogKeys {
  static const title = 'title';
  static const content = 'content';
  static const defaultAction = 'default_action';
  static const secondaryAction = 'secondary_action';
}
