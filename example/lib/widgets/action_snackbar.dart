import 'package:adapty_flutter/models/adapty_purchaser_info.dart';
import 'package:adapty_flutter_example/screens/purchaser_info_screen.dart';
import 'package:flutter/material.dart';

SnackBar buildActionSnackbar({String? title, String? actionTitle, VoidCallback? onPressed}) {
  return SnackBar(
    duration: Duration(seconds: 3),
    content: Text(
      title ?? '',
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

SnackBar buildPurchaserInfoSnackbar(BuildContext context, AdaptyPurchaserInfo? purchaserInfo) {
  return buildActionSnackbar(
    title: 'Purchaser Info updated.',
    actionTitle: purchaserInfo != null ? 'Open Purchaser Info' : 'Purchaser Info is null',
    onPressed: purchaserInfo != null
        ? () => Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => PurchaserInfoScreen(purchaserInfo)),
            )
        : null,
  );
}
