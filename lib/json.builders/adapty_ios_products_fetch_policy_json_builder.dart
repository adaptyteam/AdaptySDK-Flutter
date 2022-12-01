//
//  adapty_ios_products_fetch_policy_json_builder.dart
//  Adapty
//
//  Created by Aleksei Goncharov on 1.12.2022.
//

part of '../models/adapty_ios_products_fetch_policy.dart';

extension AdaptyIOSProductsFetchPolicyJSONBuilder on AdaptyIOSProductsFetchPolicy {
  dynamic get jsonValue {
    switch (this) {
      case AdaptyIOSProductsFetchPolicy.defaultPolicy:
        return _Keys.defaultPolicy;
      case AdaptyIOSProductsFetchPolicy.waitForReceiptValidation:
        return _Keys.waitForReceiptValidation;
    }
  }
}

class _Keys {
  static const defaultPolicy = 'default';
  static const waitForReceiptValidation = 'wait_for_receipt_validation';
}
