import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/material.dart';

class AdaptyErrorDialog extends StatelessWidget {
  final AdaptyError error;

  const AdaptyErrorDialog(this.error);

  static showAdaptyErrorDialog(BuildContext context, AdaptyError error) {
    showDialog(context: context, builder: (ctx) => AdaptyErrorDialog(error));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adapty Error ${error.adaptyCode}'),
      content: Text(error.message),
      actions: <Widget>[
        TextButton(
          child: const Text('OK'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
