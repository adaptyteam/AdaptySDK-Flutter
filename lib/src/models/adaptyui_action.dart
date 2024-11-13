import 'package:adapty_flutter/src/models/private/json_builder.dart';
import 'package:meta/meta.dart' show immutable;

part 'private/adaptyui_action_json_builder.dart';

enum AdaptyUIActionType {
  /// Close Button was pressed by user
  close,

  /// Some button which contains url (e.g. Terms or Privacy & Policy) was pressed by user
  openUrl,

  /// Some button with custom action (e.g. Login) was pressed by user
  custom,

  /// Android Back Button was pressed by user
  androidSystemBack,
}

@immutable
class AdaptyUIAction {
  /// The type of action.
  final AdaptyUIActionType type;

  /// Additional value of action. Look here in case of `openUrl` or `custom` types.
  final String? value;

  const AdaptyUIAction(this.type, this.value);
}
