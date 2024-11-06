import 'package:meta/meta.dart' show immutable;
import 'package:adapty_flutter/src/models/adapty_log_level.dart';
import 'adapty_request.dart';

@immutable
class AdaptySetLogLevelRequest implements AdaptyRequest<AdaptySetLogLevelResponse> {
  @override
  final String name = 'set_log_level';
  final AdaptyLogLevel value;

  const AdaptySetLogLevelRequest({
    required this.value,
  });

  @override
  Map<String, dynamic> toJson() => {
        'value': value.jsonValue,
      };

  @override
  AdaptySetLogLevelResponse Function(Map<String, dynamic>) get parseResponse => AdaptySetLogLevelResponseJSONBuilder.fromJson;
}

@immutable
class AdaptySetLogLevelResponse {
  final bool success;

  const AdaptySetLogLevelResponse._({
    required this.success,
  });
}

extension AdaptySetLogLevelResponseJSONBuilder on AdaptySetLogLevelResponse {
  static AdaptySetLogLevelResponse fromJson(Map<String, dynamic> json) {
    return AdaptySetLogLevelResponse._(
      success: json['success'] as bool,
    );
  }
}
