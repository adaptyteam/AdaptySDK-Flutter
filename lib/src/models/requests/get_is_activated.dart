import 'package:meta/meta.dart' show immutable;

@immutable
class AdaptyIsActivatedRequest {
  final String name = 'get_is_activated';
}

@immutable
class AdaptyIsActivatedResponse {
  final bool success;

  const AdaptyIsActivatedResponse._({
    required this.success,
  });
}

extension AdaptyIsActivatedResponseJSONBuilder on AdaptyIsActivatedResponse {
  static AdaptyIsActivatedResponse fromJson(Map<String, dynamic> json) {
    return AdaptyIsActivatedResponse._(
      success: json['success'],
    );
  }
}
