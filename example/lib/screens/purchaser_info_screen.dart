import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/Helpers/value_to_string.dart';
import 'package:adapty_flutter_example/screens/access_levels_screen.dart';
import 'package:adapty_flutter_example/screens/non_subscriptions_screen.dart';
import 'package:adapty_flutter_example/screens/subscriptions_screen.dart';
import 'package:adapty_flutter_example/widgets/details_container.dart';
import 'package:flutter/material.dart';

class PurchaserInfoScreen extends StatefulWidget {
  final AdaptyProfile purchaserInfo;
  PurchaserInfoScreen(this.purchaserInfo);
  @override
  _PurchaserInfoScreenState createState() => _PurchaserInfoScreenState();
}

class _PurchaserInfoScreenState extends State<PurchaserInfoScreen> {
  @override
  Widget build(BuildContext context) {
    final details = {
      'Profile Id': valueToString(widget.purchaserInfo.profileId),
      'Customer User Id': valueToString(widget.purchaserInfo.customerUserId),
    };

    final detailPages = {
      'Access Levels': () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => AccessLevelsScreen(widget.purchaserInfo.accessLevels))),
      'Subscriptions': () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => SubscriptionsScreen(widget.purchaserInfo.subscriptions))),
      'Non Subscriptions': () => Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => NonSubscriptionsScreen(widget.purchaserInfo.nonSubscriptions))),
    };

    return Scaffold(
        appBar: AppBar(
          title: const Text('Purchaser Info'),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_outlined,
              size: 24,
            ),
            onPressed: Navigator.of(context).pop,
          ),
        ),
        body: ListView(
          children: [
            DetailsContainer(
              details: details,
              detailPages: detailPages,
            ),
          ],
        ));
  }
}
