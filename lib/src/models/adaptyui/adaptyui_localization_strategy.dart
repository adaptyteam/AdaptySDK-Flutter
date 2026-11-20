import 'package:meta/meta.dart' show immutable;

part '../private/adaptyui_localization_strategy_json_builder.dart';

/// A built-in way to choose the localization of a flow from the preferred locales.
///
/// iOS only. On Android the flow is rendered in the first preferred locale, as described in
/// [AdaptyUILocalizationStrategy].
enum AdaptyUILocalizationResolver {
  /// [legacy] for a flow built in an older format of the Adapty Flow Builder, [system] for any
  /// other flow.
  auto,

  /// Matches all the preferred locales against the flow's localizations the way the platform
  /// matches an app's localizations, for example `pt-BR` to `pt` and `zh-Hant-TW` to `zh-Hant`.
  /// When none of them matches, the flow's default localization is used.
  system,

  /// Takes only the first preferred locale and drops its last `-` part until it equals one of the
  /// flow's localizations, so `en-GB` falls back to `en`. When nothing matches, the flow's
  /// default localization is used.
  legacy,
}

/// Chooses a localization of a flow from the localizations the flow has.
///
/// Called with the preferred locales passed to [AdaptyUI.createFlowView] or
/// [AdaptyUIFlowPlatformView], in order of preference, the identifiers of the localizations the
/// flow has, and the identifier of the flow's default localization, if any.
///
/// It is called while the flow view is created and must quickly return one of [locales], or
/// `null` to let the fallback resolver of [AdaptyUILocalizationStrategy.custom] choose. A returned
/// identifier the flow doesn't have renders the flow's default localization.
typedef AdaptyUICustomLocalizationResolver = String? Function(
  List<String> preferredLocales,
  List<String> locales,
  String? defaultLocale,
);

/// How a flow view chooses its localization from the preferred locales passed to
/// [AdaptyUI.createFlowView] or [AdaptyUIFlowPlatformView].
///
/// With no preferred locales, every strategy renders the flow's default localization, and a
/// custom resolver is still called. Strings missing from the chosen localization are filled in
/// from the default one.
///
/// iOS only. On Android the strategy is ignored: the flow is rendered in the first preferred
/// locale when the flow has a localization with exactly that identifier, in `en` when no
/// preferred locale is passed and the flow has `en`, and in the flow's default localization in
/// every other case.
@immutable
class AdaptyUILocalizationStrategy {
  /// [AdaptyUILocalizationResolver.auto], the default.
  static const auto = AdaptyUILocalizationStrategy._(AdaptyUILocalizationResolver.auto);

  /// [AdaptyUILocalizationResolver.system].
  static const system = AdaptyUILocalizationStrategy._(AdaptyUILocalizationResolver.system);

  /// [AdaptyUILocalizationResolver.legacy].
  static const legacy = AdaptyUILocalizationStrategy._(AdaptyUILocalizationResolver.legacy);

  /// The built-in resolver: the strategy itself, or the fallback of a custom one.
  final AdaptyUILocalizationResolver resolver;

  /// The resolver of your app, `null` for a built-in strategy.
  final AdaptyUICustomLocalizationResolver? customResolver;

  const AdaptyUILocalizationStrategy._(this.resolver) : customResolver = null;

  /// Asks [resolver] to choose the localization while the view is created.
  ///
  /// The [fallback] resolver chooses instead when [resolver] returns `null` or throws. It is
  /// called at most once for each view, and the view doesn't keep a reference to it once created.
  const AdaptyUILocalizationStrategy.custom(
    AdaptyUICustomLocalizationResolver resolver, {
    AdaptyUILocalizationResolver fallback = AdaptyUILocalizationResolver.auto,
  })  : resolver = fallback,
        customResolver = resolver;

  @override
  String toString() => customResolver == null
      ? 'AdaptyUILocalizationStrategy.${resolver.name}'
      : 'AdaptyUILocalizationStrategy.custom(fallback: ${resolver.name})';
}
