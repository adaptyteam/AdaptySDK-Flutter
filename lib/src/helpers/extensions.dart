extension MapExtension on Map<String, dynamic> {
  DateTime? dateTimeOrNull(String key) {
    return containsKey(key) ? DateTime.tryParse(this[key]) : null;
  }
}
