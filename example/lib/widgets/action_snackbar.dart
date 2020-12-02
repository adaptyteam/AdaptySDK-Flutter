import 'package:adapty_flutter/models/adapty_promo.dart';
import 'package:adapty_flutter/models/adapty_purchaser_info.dart';
import 'package:adapty_flutter_example/screens/promo_screen.dart';
import 'package:adapty_flutter_example/screens/purchaser_info_screen.dart';
import 'package:flutter/material.dart';

SnackBar buildActionSnackbar({String title, String actionTitle, Function onPressed}) {
  return SnackBar(
    duration: Duration(seconds: 3),
    content: Text(
      title ?? '',
      // style: TextStyle(fontSize: 17),
    ),
    padding: EdgeInsets.symmetric(horizontal: 12),
    action: (onPressed != null && actionTitle != null)
        ? SnackBarAction(
            onPressed: onPressed,
            label: actionTitle,
          )
        : null,
  );
}

SnackBar buildPurchaserInfoSnackbar(BuildContext context, AdaptyPurchaserInfo purchaserInfo) {
  return buildActionSnackbar(
    title: 'Purchaser Info updated.',
    actionTitle: 'Open Purchaser Info',
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => PurchaserInfoScreen(purchaserInfo)),
    ),
  );
}

SnackBar buildPromoSnackbar(BuildContext context, AdaptyPromo promo) {
  return buildActionSnackbar(
    title: 'Promo updated.',
    actionTitle: 'Open Promo',
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => PromoScreen(promo)),
    ),
  );
}
