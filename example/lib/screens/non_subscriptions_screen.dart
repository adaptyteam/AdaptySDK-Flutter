import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/material.dart';

import '../helpers/value_to_string.dart';
import '../widgets/details_container.dart';

class NonSubscriptionsScreen extends StatelessWidget {
  final Map<String, List<AdaptyNonSubscriptionInfo>> nonSubscriptions;
  const NonSubscriptionsScreen(this.nonSubscriptions);

  static showNonSubscriptionsPage(BuildContext context,
      Map<String, List<AdaptyNonSubscriptionInfo>> nonSubscriptions) {
    showModalBottomSheet(
      context: context,
      builder: (context) => NonSubscriptionsScreen(nonSubscriptions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nonSubscriptionsKeys = nonSubscriptions.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Non Subscriptions')),
      body: CustomScrollView(
        slivers: nonSubscriptionsKeys.map((key) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, index) {
                final nonSubscriptionInfoList = nonSubscriptions[key]!;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        key,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    ...nonSubscriptionInfoList.map((nonSubscriptionInfo) {
                      final details = {
                        'PurchaseId':
                            valueToString(nonSubscriptionInfo.purchaseId),
                        'Vendor Product Id':
                            valueToString(nonSubscriptionInfo.vendorProductId),
                        'Store': valueToString(nonSubscriptionInfo.store),
                        'Purchased At':
                            valueToString(nonSubscriptionInfo.purchasedAt),
                        'Is One Time':
                            valueToString(nonSubscriptionInfo.isOneTime),
                        'Is Sandbox':
                            valueToString(nonSubscriptionInfo.isSandbox),
                        'Vendor Transaction Id': valueToString(
                            nonSubscriptionInfo.vendorTransactionId),
                        'Vendor Original Transaction Id': valueToString(
                            nonSubscriptionInfo.vendorOriginalTransactionId),
                        'Is Refund':
                            valueToString(nonSubscriptionInfo.isRefund),
                      };
                      return DetailsContainer(details: details);
                    }).toList(),
                    const Divider(height: 1)
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
