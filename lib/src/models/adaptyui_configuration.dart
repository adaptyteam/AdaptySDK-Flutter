import 'package:meta/meta.dart' show immutable;

part 'private/adaptyui_configuration_json_builder.dart';

@immutable
class AdaptyUIMediaCacheConfiguration {
  final int memoryStorageTotalCostLimit;
  final int memoryStorageCountLimit;
  final int diskStorageSizeLimit;

  const AdaptyUIMediaCacheConfiguration({
    required this.memoryStorageTotalCostLimit,
    required this.memoryStorageCountLimit,
    required this.diskStorageSizeLimit,
  });

  static const defaultValue = AdaptyUIMediaCacheConfiguration(
    memoryStorageTotalCostLimit: 100 * 1024 * 1024, // 100MB
    memoryStorageCountLimit: 2147483647, // 2^31 - 1, max int value in Dart
    diskStorageSizeLimit: 100 * 1024 * 1024, // 100MB
  );
}

@immutable
class AdaptyUIConfiguration {
  final AdaptyUIMediaCacheConfiguration? mediaCache;

  const AdaptyUIConfiguration({
    this.mediaCache,
  });

  static const AdaptyUIConfiguration defaultValue = AdaptyUIConfiguration();
}
