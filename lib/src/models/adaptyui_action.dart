import 'package:adapty_flutter/src/models/private/json_builder.dart';
import 'package:meta/meta.dart' show immutable;

part 'private/adaptyui_action_json_builder.dart';

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
  const OpenUrlAction(this.url);
}

/// Some button with custom action (e.g. Login) was pressed by user
final class CustomAction extends AdaptyUIAction {
  final String action;
  const CustomAction(this.action);
}

/// Android Back Button was pressed by user
final class AndroidSystemBackAction extends AdaptyUIAction {
  const AndroidSystemBackAction();
}
