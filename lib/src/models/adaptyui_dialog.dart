import 'package:meta/meta.dart' show immutable;

part 'private/adaptyui_dialog_json_builder.dart';

@immutable
class AdaptyUIDialogAction {
  /// The text to use for the button title.
  final String title;

  /// This callback will be invoked if user will press the button.
  final void Function() onPressed;

  const AdaptyUIDialogAction({
    required this.title,
    required this.onPressed,
  });
}

@immutable
class AdaptyUIDialog {
  /// The title of the dialog.
  final String? title;

  /// Descriptive text that provides additional details about the reason for the dialog.
  final String? content;

  /// The action object to display as part of the dialog.
  /// If you provide two actions, be sure the `defaultAction` cancels the operation and leaves things unchanged.
  final AdaptyUIDialogAction defaultAction;

  /// The action object to display as part of the dialog.
  final AdaptyUIDialogAction? secondaryAction;

  const AdaptyUIDialog({
    this.title,
    this.content,
    required this.defaultAction,
    this.secondaryAction,
  });
}
