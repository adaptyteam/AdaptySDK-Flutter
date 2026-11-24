import '../adapty_logger.dart';
import 'adapty_log_level.dart';
import 'adapty_profile.dart';
import 'private/json_builder.dart';
part 'private/adapty_purchase_result_json_builder.dart';

sealed class AdaptyPurchaseResult {}

/// The purchase is waiting for the store, for example for a parent's approval or a deferred payment, and is not
/// complete yet.
///
/// A purchase result type that this SDK version doesn't know, which a newer native SDK can send, also reads as
/// pending, and the SDK logs a warning that names the type.
class AdaptyPurchaseResultPending extends AdaptyPurchaseResult {}

class AdaptyPurchaseResultUserCancelled extends AdaptyPurchaseResult {}

class AdaptyPurchaseResultSuccess extends AdaptyPurchaseResult {
  final AdaptyProfile profile;

  final String? appleJwsTransaction;
  final String? googlePurchaseToken;

  AdaptyPurchaseResultSuccess._(
    this.profile,
    this.appleJwsTransaction,
    this.googlePurchaseToken,
  );
}
