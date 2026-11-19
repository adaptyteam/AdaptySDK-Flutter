import 'package:meta/meta.dart' show immutable;

part 'private/adapty_customer_identity_json_builder.dart';

@immutable
class AdaptyCustomerIdentity {
  /// The UUID that you generate to associate a customer’s In-App Purchase with its resulting App Store transaction. (use for iOS), [read more](https://developer.apple.com/documentation/appstoreserverapi/appaccounttoken)
  ///
  /// On iOS, a value that is not a UUID makes the whole call that sends it fail with `AdaptyErrorCode.decodingFailed`.
  final String? appAccountToken;

  /// The obfuscated account identifier (use for Android), [read more](https://developer.android.com/google/play/billing/developer-payload#attribute).
  final String? obfuscatedAccountId;

  AdaptyCustomerIdentity(
    this.appAccountToken,
    this.obfuscatedAccountId,
  );

  bool get isEmpty => appAccountToken == null && obfuscatedAccountId == null;
}
