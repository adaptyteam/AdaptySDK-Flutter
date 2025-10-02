import 'adapty_profile.dart';
import 'private/json_builder.dart';
part 'private/adapty_purchase_result_json_builder.dart';

sealed class AdaptyPurchaseResult {}

class AdaptyPurchaseResultPending extends AdaptyPurchaseResult {}

class AdaptyPurchaseResultUserCancelled extends AdaptyPurchaseResult {}

class AdaptyPurchaseResultSuccess extends AdaptyPurchaseResult {
  final AdaptyProfile profile;

  final String? appleJwsTransaction;
  final String? googlePurchaseToken;

  @Deprecated('Use appleJwsTransaction instead')
  String? get jwsTransaction => appleJwsTransaction;

  AdaptyPurchaseResultSuccess._(
    this.profile,
    this.appleJwsTransaction,
    this.googlePurchaseToken,
  );
}
