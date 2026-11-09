//
//  adapty_price.dart
//  Adapty
//
//  Created by Aleksei Valiano on 20.07.2023.
//

import 'package:meta/meta.dart' show immutable;
import 'private/json_builder.dart';

part 'private/adapty_price_json_builder.dart';

@immutable
class AdaptyPrice {
  /// The price as a number, in the currency of [currencyCode].
  final double amount;

  /// The currency code of the locale used to format the price of the product.
  final String? currencyCode;

  /// The currency symbol of the locale used to format the price of the product.
  final String? currencySymbol;

  /// The price formatted for the user's locale, for example `$9.99`.
  ///
  /// [Nullable]
  final String? localizedString;

  const AdaptyPrice._(
    this.amount,
    this.currencyCode,
    this.currencySymbol,
    this.localizedString,
  );

  @override
  String toString() => '(amount: $amount, '
      'currencyCode: $currencyCode, '
      'currencySymbol: $currencySymbol, '
      'localizedString: $localizedString)';
}
