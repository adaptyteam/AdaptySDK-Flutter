import 'package:meta/meta.dart' show immutable;

@immutable
class AdaptyGetSDKVersionRequest {
  final String name = 'get_sdk_version';

  @override
  String toString() => '(name: $name)';
}

extension AdaptyGetSDKVersionRequestJSONBuilder on AdaptyGetSDKVersionRequest {
  Map<String, dynamic> toJson() => {
        'name': name,
      };
}

@immutable
class AdaptyGetSDKVersionResponse {
  final String success;

  const AdaptyGetSDKVersionResponse._({
    required this.success,
  });
}

extension AdaptyGetSDKVersionResponseJSONBuilder on AdaptyGetSDKVersionResponse {
  static AdaptyGetSDKVersionResponse fromJson(Map<String, dynamic> json) {
    return AdaptyGetSDKVersionResponse._(
      success: json['success'],
    );
  }
}
