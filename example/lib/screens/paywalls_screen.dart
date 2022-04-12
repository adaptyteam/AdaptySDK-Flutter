import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/Helpers/value_to_string.dart';
import 'package:adapty_flutter_example/screens/products_screen.dart';
import 'package:adapty_flutter_example/widgets/details_container.dart';
import 'package:flutter/material.dart';

class PaywallsScreen extends StatefulWidget {
  final List<AdaptyPaywall>? paywalls;
  const PaywallsScreen(this.paywalls);
  @override
  _PaywallsScreenState createState() => _PaywallsScreenState();
}

class _PaywallsScreenState extends State<PaywallsScreen> {
  @override
  Widget build(BuildContext context) {
    final paywalls = widget.paywalls;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paywalls'),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_outlined,
            size: 24,
          ),
          onPressed: Navigator.of(context).pop,
        ),
      ),
      body: (paywalls != null && paywalls.isNotEmpty)
          ? ListView.separated(
              itemBuilder: (ctx, index) {
                final paywall = paywalls[index];
                final details = {
                  'Developer Id': valueToString(paywall.developerId),
                  'Variation Id': valueToString(paywall.variationId),
                  'Revision': valueToString(paywall.revision),
                  'Is Promo': valueToString(paywall.isPromo),
                  'A/B Test Name': valueToString(paywall.abTestName),
                  'Name': valueToString(paywall.name),
                };
                final detailPages = {
                  'Products': () async {
                    try {
                      await Adapty.instance.logShowPaywall(paywall: paywall);
                    } catch (e) {
                      print(e.toString());
                    }
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (ctx) => ProductsScreen(paywall.products)));
                  },
                };
                return DetailsContainer(
                  details: details,
                  detailPages: detailPages,
                  bottomWidget: paywall.developerId == 'ios_test_visual'
                      ? ElevatedButton(
                          onPressed: () async {
                            print('#Paywalls# showVisualPaywall');
                            final result =
                                await Adapty.instance.showVisualPaywall(
                              paywall: paywall,
                              onPurchaseSuccess: (result) {
                                print(
                                  '#Paywalls# onPurchaseSuccess ${result.product?.vendorProductId}',
                                );
                              },
                              onCancel: () async {
                                print('#Paywalls# closeVisualPaywall');
                                final closeResult =
                                    await Adapty.instance.closeVisualPaywall();
                                print(
                                  '#Paywalls# closeVisualPaywall result = $closeResult',
                                );
                              },
                            );
                            print(
                              '#Paywalls# showVisualPaywall result = $result',
                            );
                          },
                          child: const Text('Show Visual Paywall'),
                        )
                      : null,
                );
              },
              separatorBuilder: (ctx, idx) => const Divider(height: 1),
              itemCount: paywalls.length,
            )
          : const Center(
              child: Text('Paywalls were not received.'),
            ),
    );
  }
}
