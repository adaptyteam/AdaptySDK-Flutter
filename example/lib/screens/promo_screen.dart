import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/Helpers/value_to_string.dart';
import 'package:adapty_flutter_example/screens/paywalls_screen.dart';
import 'package:adapty_flutter_example/widgets/details_container.dart';
import 'package:flutter/material.dart';

class PromoScreen extends StatelessWidget {
  final AdaptyPromo? promo;

  const PromoScreen(this.promo);

  @override
  Widget build(BuildContext context) {
    final details = {
      'promoType': valueToString(promo?.promoType),
      'variationId': valueToString(promo?.variationId),
      'expiresAt': valueToString(promo?.expiresAt),
    };
    final detailPages = {
      'Paywall': () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) {
                final paywall = promo?.paywall;
                return PaywallsScreen(paywall != null ? [paywall] : null);
              },
            ),
          )
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Promo')),
      body: promo != null
          ? ListView(children: [
              DetailsContainer(
                details: details,
                detailPages: detailPages,
              ),
            ])
          : const Center(child: Text('Promo was not received.')),
    );
  }
}
