extension MapExtension on Map<String, dynamic> {
  DateTime dateTimeOrNull(String key) {
    return this.containsKey(key) ? DateTime.parse(this[key]) : null;
  }
}
