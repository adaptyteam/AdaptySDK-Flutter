import 'package:adapty_flutter/models/adapty_non_subscription_info.dart';
import 'package:adapty_flutter_example/Helpers/value_to_string.dart';
import 'package:adapty_flutter_example/widgets/details_container.dart';
import 'package:flutter/material.dart';

class NonSubscriptionsScreen extends StatelessWidget {
  final Map<String, List<AdaptyNonSubscriptionInfo>> nonSubscriptions;
  NonSubscriptionsScreen(this.nonSubscriptions);

  static showNonSubscriptionsPage(BuildContext context, Map<String, List<AdaptyNonSubscriptionInfo>> nonSubscriptions) {
    showModalBottomSheet(
      context: context,
      builder: (context) => NonSubscriptionsScreen(nonSubscriptions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nonSubscriptionsKeys = nonSubscriptions.keys.toList();

    return Scaffold(
      appBar: AppBar(title: Text('Non Subscriptions')),
      body: CustomScrollView(
        slivers: nonSubscriptionsKeys.map((key) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, index) {
                final nonSubscriptionInfoList = nonSubscriptions[key];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        key,
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                    ...nonSubscriptionInfoList.map((nonSubscriptionInfo) {
                      final details = {
                        'PurchaseId': valueToString(nonSubscriptionInfo.purchaseId),
                        'Vendor Product Id': valueToString(nonSubscriptionInfo.vendorProductId),
                        'Store': valueToString(nonSubscriptionInfo.store),
                        'Purchased At': valueToString(nonSubscriptionInfo.purchasedAt),
                        'Is One Time': valueToString(nonSubscriptionInfo.isOneTime),
                        'Is Sandbox': valueToString(nonSubscriptionInfo.isSandbox),
                        'Vendor Transaction Id': valueToString(nonSubscriptionInfo.vendorTransactionId),
                        'Vendor Original Transaction Id': valueToString(nonSubscriptionInfo.vendorOriginalTransactionId),
                        'Is Refund': valueToString(nonSubscriptionInfo.isRefund),
                      };
                      return DetailsContainer(details: details);
                    }).toList(),
                    Divider(height: 1)
                  ],
                );
              },
              childCount: 1,
            ),
          );
        }).toList(),
      ),
    );
  }
}
