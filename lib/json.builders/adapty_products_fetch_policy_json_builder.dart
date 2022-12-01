//
//  adapty_products_fetch_policy_json_builder.dart
//  Adapty
//
//  Created by Aleksei Goncharov on 1.12.2022.
//

part of '../models/adapty_products_fetch_policy.dart';

extension AdaptyProductsFetchPolicyJSONBuilder on AdaptyProductsFetchPolicy {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyProductsFetchPolicy.defaultPolicy:
        return _Keys.defaultPolicy;
      case AdaptyProductsFetchPolicy.waitForReceiptValidation:
        return _Keys.waitForReceiptValidation;
    }
  }
}

class _Keys {
  static const defaultPolicy = 'default';
  static const waitForReceiptValidation = 'wait_for_receipt_validation';
}
