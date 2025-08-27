import 'adapty_profile.dart';
import 'private/json_builder.dart';
part 'private/adapty_purchase_result_json_builder.dart';

sealed class AdaptyPurchaseResult {}

class AdaptyPurchaseResultPending extends AdaptyPurchaseResult {}

class AdaptyPurchaseResultUserCancelled extends AdaptyPurchaseResult {}

class AdaptyPurchaseResultSuccess extends AdaptyPurchaseResult {
  final AdaptyProfile profile;
  final String? jwsTransaction;

  AdaptyPurchaseResultSuccess._(this.profile, this.jwsTransaction);
}
