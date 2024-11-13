part of '../adaptyui_configuration.dart';

extension AdaptyUIMediaCacheConfigurationJSONBuilder on AdaptyUIMediaCacheConfiguration {
  dynamic get jsonValue => {
        _Keys.memoryStorageTotalCostLimit: memoryStorageTotalCostLimit,
        _Keys.memoryStorageCountLimit: memoryStorageCountLimit,
        _Keys.diskStorageSizeLimit: diskStorageSizeLimit,
      };
}

extension AdaptyUIConfigurationJSONBuilder on AdaptyUIConfiguration {
  dynamic get jsonValue => {
        if (mediaCache != null) _Keys.mediaCache: mediaCache!.jsonValue,
      };
}

class _Keys {
  static const mediaCache = 'media_cache';

  static const memoryStorageTotalCostLimit = 'memory_storage_total_cost_limit';
  static const memoryStorageCountLimit = 'memory_storage_count_limit';
  static const diskStorageSizeLimit = 'disk_storage_size_limit';
}
