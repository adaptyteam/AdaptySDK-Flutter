import 'package:flutter/foundation.dart' show visibleForTesting;

import 'adapty_logger.dart';
import 'constants/argument.dart';
import 'models/adapty_log_level.dart';
import 'models/adaptyui/adaptyui_localization_strategy.dart';
import 'models/adapty_sdk_native.dart';

/// The custom localization resolvers of the flow views being created, by the id sent to the
/// native side as `custom_id`.
///
/// A resolver is registered right before its view is requested and unregistered as soon as the
/// view is created or fails to, so the registry never outlives the creation. A request for an id
/// that is not registered is answered with `null`, which lets the native fallback resolver choose.
class AdaptyUILocalizationResolvers {
  static final AdaptyUILocalizationResolvers _instance = AdaptyUILocalizationResolvers._();

  factory AdaptyUILocalizationResolvers() => _instance;

  AdaptyUILocalizationResolvers._();

  final _resolvers = <String, AdaptyUICustomLocalizationResolver>{};
  int _nextId = 0;

  /// Registers the custom resolver of [strategy], if any, and returns its id.
  String? register(AdaptyUILocalizationStrategy strategy) {
    final resolver = strategy.customResolver;
    if (resolver == null) return null;
    final id = 'flutter_localization_resolver_${_nextId++}';
    _resolvers[id] = resolver;
    return id;
  }

  void unregister(String? id) {
    if (id != null) _resolvers.remove(id);
  }

  @visibleForTesting
  int get registeredCount => _resolvers.length;

  /// Asks the resolver registered under [id]. `null` for an unknown id, a resolver that throws or
  /// one that returns `null`.
  String? resolve(
    String id,
    List<String> preferredLocales,
    List<String> locales,
    String? defaultLocale,
  ) {
    final resolver = _resolvers[id];
    if (resolver == null) {
      AdaptyLogger.write(AdaptyLogLevel.warn, 'AdaptyUI: no localization resolver with id $id, falling back');
      return null;
    }
    try {
      return resolver(
        List.unmodifiable(preferredLocales),
        List.unmodifiable(locales),
        defaultLocale,
      );
    } catch (error) {
      AdaptyLogger.write(AdaptyLogLevel.error, 'AdaptyUI: the localization resolver threw $error, falling back');
      return null;
    }
  }
}

/// The localization arguments of a flow view request: `adapty_ui_create_flow_view` and the
/// creation params of the embedded flow view.
///
/// Android doesn't take a strategy yet and reads `locale`, matched as is, so it gets the first
/// preferred locale there.
Map<String, dynamic> flowViewLocalizationArguments({
  required List<String> preferredLocales,
  required AdaptyUILocalizationStrategy strategy,
  String? resolverId,
}) {
  return {
    Argument.preferredLocales: preferredLocales,
    Argument.localizationStrategy: strategy.jsonValue(customId: resolverId),
    if (AdaptySDKNative.isAndroid && preferredLocales.isNotEmpty) Argument.locale: preferredLocales.first,
  };
}
