extension MapExtension on Map<String, dynamic> {
  DateTime dateTimeOrNull(String key) {
    return this.containsKey(key) ? DateTime.fromMillisecondsSinceEpoch(this[key]) : null;
  }
}
