extension MapExtension on Map<String, dynamic> {
  DateTime dateTimeOrNull(String key) {
    return this.containsKey(key) ? DateTime.tryParse(this[key]) : null;
  }
}
