//
//  adapty_non_subscription_details.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

import 'package:meta/meta.dart' show immutable;
import 'adapty_price.dart';

part 'private/adapty_non_subscription_details_json_builder.dart';

@immutable
class AdaptyNonSubscriptionDetails {
  final AdaptyPrice price;

  const AdaptyNonSubscriptionDetails._(
    this.price,
  );

  @override
  String toString() => '(price: $price)';
}
