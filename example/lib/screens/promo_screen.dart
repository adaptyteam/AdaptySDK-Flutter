import 'package:adapty_flutter/models/adapty_promo.dart';
import 'package:adapty_flutter_example/Helpers/value_to_string.dart';
import 'package:adapty_flutter_example/screens/paywalls_screen.dart';
import 'package:adapty_flutter_example/widgets/details_container.dart';
import 'package:flutter/material.dart';

class PromoScreen extends StatelessWidget {
  final AdaptyPromo promo;

  PromoScreen(this.promo);

  @override
  Widget build(BuildContext context) {
    final details = {
      'promoType': valueToString(promo?.promoType),
      'variationId': valueToString(promo?.variationId),
      'expiresAt': valueToString(promo?.expiresAt),
    };
    final detailPages = {
      'Paywall': () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => PaywallsScreen([promo?.paywall])))
    };
    return Scaffold(
      appBar: AppBar(title: Text('Promo')),
      body: promo != null
          ? ListView(children: [
              DetailsContainer(
                details: details,
                detailPages: detailPages,
              ),
            ])
          : Center(child: Text('Promo was not received.')),
    );
  }
}
