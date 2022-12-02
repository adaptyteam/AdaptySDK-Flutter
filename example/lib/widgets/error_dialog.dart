import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/cupertino.dart';

class AdaptyErrorDialog extends StatelessWidget {
  final AdaptyError error;
  AdaptyErrorDialog(this.error);

  static showAdaptyErrorDialog(BuildContext context, AdaptyError error) {
    showCupertinoDialog(context: context, builder: (ctx) => AdaptyErrorDialog(error));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text('Adapty Error ${error.code}'),
      content: Text(error.message),
      actions: <Widget>[
        CupertinoButton(
          child: Text('OK'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
