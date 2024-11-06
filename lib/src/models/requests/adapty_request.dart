abstract class AdaptyRequest<Response> {
  String get name;
  Map<String, dynamic> toJson();
  Response Function(Map<String, dynamic>) get parseResponse;
}
