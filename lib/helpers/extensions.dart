import 'package:intl/intl.dart';

extension MapExtension on Map<String, dynamic> {
  static final formatter = DateFormat("yyyy-MM-dd'T'HH:mm:ssZ");

  DateTime dateTimeOrNull(String key) {
    return this.containsKey(key) ? formatter.parse(this[key]) : null;
  }
}
