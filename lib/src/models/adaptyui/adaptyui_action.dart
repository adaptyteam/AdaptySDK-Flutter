import '../private/json_builder.dart';
import 'package:meta/meta.dart' show immutable;

import '../adapty_web_presentation.dart';

part '../private/adaptyui_action_json_builder.dart';

@immutable
sealed class AdaptyUIAction {
  const AdaptyUIAction();
}

// Close Button was pressed by user
final class CloseAction extends AdaptyUIAction {
  const CloseAction();
}

/// Some button which contains url (e.g. Terms or Privacy & Policy) was pressed by user
final class OpenUrlAction extends AdaptyUIAction {
  final String url;

  /// Where the URL should be opened — in an external browser or in an in-app browser.
  final AdaptyWebPresentation openIn;

  const OpenUrlAction(this.url, this.openIn);
}

/// Some button with custom action (e.g. Login) was pressed by user
final class CustomAction extends AdaptyUIAction {
  /// The ID of the custom action, as set in the Adapty Flow Builder.
  final String action;

  /// The arguments the flow passed with this action, or `null` if it passed none.
  ///
  /// Values are JSON values: `String`, `bool`, `num`, `null` inside lists,
  /// `List<dynamic>` and `Map<String, dynamic>`. Read numbers as `num`: a whole
  /// number can arrive as an `int` or a `double`. A key whose value is `null` may
  /// be missing from the map, so treat a missing key and a `null` value alike.
  final Map<String, dynamic>? arguments;

  const CustomAction(this.action, {this.arguments});
}

/// Android Back Button was pressed by user
final class AndroidSystemBackAction extends AdaptyUIAction {
  const AndroidSystemBackAction();
}
