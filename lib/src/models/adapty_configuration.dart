import 'package:meta/meta.dart' show immutable;

enum AdaptyServerCluster {
  eu,
  us,
}

@immutable
class AdaptyConfiguration {
  final String apiKey;
  final AdaptyServerCluster serverCluster;

  const AdaptyConfiguration({
    required this.apiKey,
    required this.serverCluster,
  });
}

extension AdaptyConfigurationJSONBuilder on AdaptyConfiguration {
  Map<String, dynamic> toJson() => {
        'api_key': apiKey,
        'server_cluster': serverCluster.name,
      };
}
