import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/models/adapty_paywall.dart';
import 'package:adapty_flutter_example/Helpers/value_to_string.dart';
import 'package:adapty_flutter_example/screens/products_screen.dart';
import 'package:adapty_flutter_example/widgets/details_container.dart';
import 'package:flutter/material.dart';

class PaywallsScreen extends StatefulWidget {
  final List<AdaptyPaywall> paywalls;
  PaywallsScreen(this.paywalls);
  @override
  _PaywallsScreenState createState() => _PaywallsScreenState();
}

class _PaywallsScreenState extends State<PaywallsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paywalls'),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_outlined,
            size: 24,
          ),
          onPressed: Navigator.of(context).pop,
        ),
      ),
      body: (widget.paywalls != null || widget.paywalls.length > 0)
          ? ListView.separated(
              itemBuilder: (ctx, index) {
                final paywall = widget.paywalls[index];
                final details = {
                  'Developer Id': valueToString(paywall.developerId),
                  'Variation Id': valueToString(paywall.variationId),
                  'Revision': valueToString(paywall.revision),
                  'Is Promo': valueToString(paywall.isPromo),
                  'Visual Paywall': valueToString(paywall.visualPaywall),
                };
                final detailPages = {
                  'Products': () {
                    Adapty.logShowPaywall(paywall: paywall);
                    Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ProductsScreen(paywall.products)));
                  },
                };
                return DetailsContainer(
                  details: details,
                  detailPages: detailPages,
                );
              },
              separatorBuilder: (ctx, idx) => Divider(height: 1),
              itemCount: widget.paywalls.length,
            )
          : Center(
              child: Text('Paywalls were not received.'),
            ),
    );
  }
}
