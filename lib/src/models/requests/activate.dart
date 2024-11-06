import 'package:meta/meta.dart' show immutable;
import 'package:adapty_flutter/src/models/adapty_configuration.dart';
import 'package:adapty_flutter/src/models/adapty_error.dart';
import 'adapty_request.dart';

@immutable
class AdaptyActivateRequest implements AdaptyRequest<AdaptyActivateResponse> {
  @override
  final String name = 'activate';

  final AdaptyConfiguration configuration;

  const AdaptyActivateRequest({
    required this.configuration,
  });

  Map<String, dynamic> toJson() => {
        'configuration': configuration.toJson(),
      };

  @override
  AdaptyActivateResponse Function(Map<String, dynamic>) get parseResponse => AdaptyActivateResponseJSONBuilder.fromJson;
}

@immutable
class AdaptyActivateResponse {
  final bool success;
  final AdaptyError? error;

  const AdaptyActivateResponse._({
    required this.success,
    this.error,
  });
}

extension AdaptyActivateResponseJSONBuilder on AdaptyActivateResponse {
  static AdaptyActivateResponse fromJson(Map<String, dynamic> json) {
    return AdaptyActivateResponse._(
      success: json['success'] as bool,
      error: json['error'] != null
          ? AdaptyErrorJSONBuilder.fromJsonValue(
              json['error'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}
