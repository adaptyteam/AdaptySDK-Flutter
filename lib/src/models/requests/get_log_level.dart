import 'package:meta/meta.dart' show immutable;
import 'package:adapty_flutter/src/models/adapty_log_level.dart';

@immutable
class AdaptyGetLogLevelRequest {
  final String name = 'get_log_level';
}

@immutable
class AdaptyGetLogLevelResponse {
  final AdaptyLogLevel success;

  const AdaptyGetLogLevelResponse._({
    required this.success,
  });
}

extension AdaptyGetLogLevelResponseJSONBuilder on AdaptyGetLogLevelResponse {
  static AdaptyGetLogLevelResponse fromJson(Map<String, dynamic> json) {
    return AdaptyGetLogLevelResponse._(
      success: AdaptyLogLevelJSONBuilder.fromJsonValue(json['success']),
    );
  }
}
