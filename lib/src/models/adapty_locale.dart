import 'package:meta/meta.dart' show immutable;
import 'private/json_builder.dart';

part 'private/adapty_locale_json.dart';

@immutable
class AdaptyLocale {
  final String id;

  const AdaptyLocale._(this.id);
}
