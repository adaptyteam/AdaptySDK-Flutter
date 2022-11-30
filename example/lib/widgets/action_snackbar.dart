import 'package:adapty_flutter/adapty_flutter.dart';
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

SnackBar buildPurchaserInfoSnackbar(BuildContext context, AdaptyProfile? profile) {
  return buildActionSnackbar(
    title: 'Purchaser Info updated.',
    actionTitle: profile != null ? 'Open Purchaser Info' : 'Purchaser Info is null',
    onPressed: profile != null
        ? () => Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => PurchaserInfoScreen(profile)),
            )
        : null,
  );
}
