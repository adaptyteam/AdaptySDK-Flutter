import 'adapty_android_subscription_update_parameters.dart';
import 'adapty_error.dart';
import 'adapty_error_code.dart';

part 'private/adapty_purchase_parameters_json_builder.dart';

sealed class AdaptyAppAccountToken {}

class AdaptyAppAccountTokenNone extends AdaptyAppAccountToken {}

class AdaptyAppAccountTokenCustomerUserId extends AdaptyAppAccountToken {}

class AdaptyAppAccountTokenCustom extends AdaptyAppAccountToken {
  final String uuid;

  AdaptyAppAccountTokenCustom({
    required this.uuid,
  }) {
    if (!_isValidUuid(uuid)) {
      throw AdaptyError(
        'Invalid UUID format: $uuid',
        AdaptyErrorCode.wrongParam,
        'UUID must be in RFC 4122 format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
      );
    }
  }

  /// Validates if the provided string is a valid UUID format
  static bool _isValidUuid(String uuid) {
    // UUID regex pattern matching RFC 4122 format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidPattern.hasMatch(uuid);
  }
}

class AdaptyPurchaseParameters {
  /// The app account token (use for Android).
  AdaptyAppAccountToken? appAccountToken;

  /// Used to upgrade or downgrade a subscription (use for Android).
  AdaptyAndroidSubscriptionUpdateParameters? subscriptionUpdateParams;

  /// Specifies whether the offer is personalized to the buyer (use for Android).
  bool? isOfferPersonalized;

  /// The obfuscated account identifier (use for Android), [read more](https://developer.android.com/google/play/billing/developer-payload#attribute).
  String? obfuscatedAccountId;

  /// The obfuscated profile identifier (use for Android), [read more](https://developer.android.com/google/play/billing/developer-payload#attribute).
  String? obfuscatedProfileId;

  AdaptyPurchaseParameters({
    this.appAccountToken = null,
    this.subscriptionUpdateParams = null,
    this.isOfferPersonalized = null,
    this.obfuscatedAccountId = null,
    this.obfuscatedProfileId = null,
  });
}

class AdaptyPurchaseParametersBuilder {
  var _parameters = AdaptyPurchaseParameters();

  void setAppAccountToken(AdaptyAppAccountToken? value) => _parameters.appAccountToken = value;

  void setSubscriptionUpdateParams(AdaptyAndroidSubscriptionUpdateParameters? value) => _parameters.subscriptionUpdateParams = value;

  void setIsOfferPersonalized(bool? value) => _parameters.isOfferPersonalized = value;

  void setObfuscatedAccountId(String? value) => _parameters.obfuscatedAccountId = value;

  void setObfuscatedProfileId(String? value) => _parameters.obfuscatedProfileId = value;

  AdaptyPurchaseParameters build() => _parameters;
}
