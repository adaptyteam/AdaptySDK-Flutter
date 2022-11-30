import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/Helpers/value_to_string.dart';
import 'package:adapty_flutter_example/widgets/details_container.dart';
import 'package:flutter/material.dart';

class DiscountsScreen extends StatelessWidget {
  final List<AdaptyProductDiscount> discounts;
  DiscountsScreen(this.discounts);

  static showDiscountsPage(BuildContext context, List<AdaptyProductDiscount> discounts) {
    showModalBottomSheet(
      context: context,
      builder: (context) => DiscountsScreen(discounts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Discounds')),
      body: ListView.builder(
        itemCount: discounts.length,
        itemBuilder: (ctx, index) {
          final discount = discounts[index];
          final details = {
            'Price': valueToString(discount.price),
            'Identifier': valueToString(discount.identifier),
            'Subscription Period': adaptyPeriodToString(discount.subscriptionPeriod),
            'Number Of Periods': valueToString(discount.numberOfPeriods),
            'Payment Mode': adaptyPaymentModeToString(discount.paymentMode),
            'Localized Price': valueToString(discount.localizedPrice),
            'Localized Subscription Period': valueToString(discount.localizedSubscriptionPeriod),
            'Localized Number Of Periods': valueToString(discount.localizedNumberOfPeriods),
          };

          return DetailsContainer(
            details: details,
          );
        },
      ),
    );
  }
}
