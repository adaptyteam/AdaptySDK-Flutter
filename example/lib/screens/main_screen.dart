import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/models/adapty_enums.dart';
import 'package:adapty_flutter/models/adapty_error.dart';
import 'package:adapty_flutter_example/screens/paywalls_screen.dart';
import 'package:adapty_flutter_example/screens/products_screen.dart';
import 'package:adapty_flutter_example/screens/promo_screen.dart';
import 'package:adapty_flutter_example/screens/purchaser_info_screen.dart';
import 'package:adapty_flutter_example/screens/update_profile_screen.dart';
import 'package:adapty_flutter_example/service.dart';
import 'package:adapty_flutter_example/widgets/action_snackbar.dart';
import 'package:adapty_flutter_example/widgets/error_dialog.dart';
import 'package:adapty_flutter_example/widgets/simple_snackbar.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<State<Scaffold>> scaffoldKey = GlobalKey();
  bool loading = false;
  bool externalAnalyticsEnabled = false;

  @override
  void initState() {
    _initialize();
    super.initState();
  }

  Future<void> _initialize() async {
    final installId = await Service.getOrCreateInstallId();

    try {
      Adapty.activate();
      await Adapty.identify(installId);

      await Service.initializePushes();
      await Adapty.setLogLevel(AdaptyLogLevel.verbose);
      _subscribeForStreams(context);
    } catch (e) {
      print('#Example# activate error $e');
    }
  }

  void _subscribeForStreams(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Adapty.purchaserInfoUpdateStream.listen((purchaserInfo) {
      scaffoldMessenger.showSnackBar(buildPurchaserInfoSnackbar(context, purchaserInfo));
      print('#Example# purchaserInfoUpdateStream:\n $purchaserInfo');
    });
    Adapty.promosReceiveStream.listen((promo) {
      scaffoldMessenger.showSnackBar(buildPromoSnackbar(context, promo));
      print('#Example# promosReceiveStream:\n $promo');
    });
    Adapty.deferredPurchasesStream.listen((event) {
      scaffoldMessenger.showSnackBar(buildSimpleSnackbar(event));
      print('#Example# deferredPurchasesStream:\n $event');
    });
    Adapty.getPaywallsResultStream.listen((event) {
      scaffoldMessenger.showSnackBar(buildSimpleSnackbar('Paywalls Updated!'));
      print('#Example# getPaywallsResultStream:\n $event');
    });
  }

  void callAdaptyMethod(Function method) async {
    setState(() {
      loading = true;
    });
    try {
      await method();
    } on AdaptyError catch (adapryError) {
      AdaptyErrorDialog.showAdaptyErrorDialog(context, adapryError);
    } catch (e) {
      print(e.toString());
    }
    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listViewChildren = [
      _buildInstallIdTile(),
      _buildLogLevelTile(),
      _buildMethodTile(
        'Identify',
        () async {
          callAdaptyMethod(() async {
            final scaffoldMessenger = ScaffoldMessenger.of(context);
            final installId = await Service.getOrCreateInstallId();
            bool res = false;
            res = await Adapty.identify(installId);
            scaffoldMessenger.showSnackBar(buildSimpleSnackbar(res ? 'You identify with $installId.' : 'You were not identified.'));
          });
        },
        openNewScreen: false,
      ),
      _buildMethodTile(
        'Get Paywalls',
        () {
          callAdaptyMethod(() async {
            final paywallResult = await Adapty.getPaywalls();
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => PaywallsScreen(paywallResult.paywalls)));
          });
        },
      ),
      _buildMethodTile(
        'Get Products',
        () {
          callAdaptyMethod(() async {
            final paywalls = await Adapty.getPaywalls(forceUpdate: false);
            final products = paywalls.products;
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ProductsScreen(products)));
          });
        },
      ),
      _buildMethodTile('Get Purchaser Info', () {
        callAdaptyMethod(() async {
          final purchaserInfo = await Adapty.getPurchaserInfo(forceUpdate: false);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => PurchaserInfoScreen(purchaserInfo)),
          );
        });
      }),
      _buildMethodTile(
        'Update Profile',
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (ctx) => UpdateProfileScreen()),
        ),
      ),
      _buildMethodTile('Restore Purchases', () {
        callAdaptyMethod(() async {
          final res = await Adapty.restorePurchases();

          final state = ScaffoldMessenger.of(context);
          state.showSnackBar(buildPurchaserInfoSnackbar(context, res.purchaserInfo));
        });
      }),
      _buildMethodTile(
        'Get Promo',
        () {
          callAdaptyMethod(() async {
            final promo = await Adapty.getPromo();
            Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => PromoScreen(promo)));
          });
        },
      ),
      _buildMethodTile(
        'Update Attribution',
        () => callAdaptyMethod(() async {
          final attribution = {
            "status": "non_organicunknown",
            "channel": "Google Ads",
            "campaign": "Adapty in-app",
            "ad_group": "adapty ad_group",
            "ad_set": "adapty ad_set",
            "creative": "12312312312312",
          };
          await Adapty.updateAttribution(attribution, source: AdaptyAttributionNetwork.custom);

          print('#Example# updateAttribution done!');
        }),
        openNewScreen: false,
      ),
      _buildMethodTile(
        'Set Fallback Paywalls',
        () => callAdaptyMethod(() async {
          final testPaywalls = '''
      {
        'key1': 1,
        'key2': '2'
      }
      ''';
          await Adapty.setFallbackPaywalls(testPaywalls);
          print('#Example# setFallbackPaywalls done!');
        }),
        openNewScreen: false,
      ),
      _buildMethodTile(
        'Set Transaction VariationId',
        () => callAdaptyMethod(() async {
          await Adapty.setTransactionVariationId('variation', 'af3753fe-1dcf-4f80-a2fb-0de5d55bdfde');
          print('#Example# setTransactionVariationId done!');
        }),
        openNewScreen: false,
      ),
      _buildSwitchMethodTile(
        'External Analytics Enabled',
        externalAnalyticsEnabled,
        (value) {
          callAdaptyMethod(() async {
            await Adapty.setExternalAnalyticsEnabled(value);
            print('#Example# setExternalAnalyticsEnabled $value done!');
            setState(() {
              externalAnalyticsEnabled = value;
            });
          });
        },
      ),
      if (Platform.isIOS)
        _buildMethodTile(
          'Present Code Redemption Sheet',
          () => callAdaptyMethod(() async {
            await Adapty.presentCodeRedemptionSheet();
          }),
        ),
      _buildMethodTile(
        'Logout',
        () => callAdaptyMethod(() async {
          final result = await Adapty.logout();
          if (result) {
            print('#Example# logout done!');
          } else {
            print('#Example# logout is not succes');
          }
        }),
      ),
    ];
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text('Welcome to Adapty!'),
      ),
      body: Center(
        child: loading
            ? CircularProgressIndicator()
            : ListView.separated(
                itemBuilder: (ctx, idx) => listViewChildren[idx],
                separatorBuilder: (ctx, idx) => Divider(height: 1),
                itemCount: listViewChildren.length,
              ),
      ),
    );
  }

  Widget _buildInstallIdTile() {
    return ListTile(
      title: Text('Your Install Id (generated by app)'),
      subtitle: FutureBuilder<String>(
        future: Service.getOrCreateInstallId(),
        builder: (ctx, snapshot) {
          return Text(snapshot.data ?? '');
        },
      ),
    );
  }

  Widget _buildLogLevelTile() {
    return ListTile(
      title: Text('Log Level'),
      subtitle: FutureBuilder<AdaptyLogLevel>(
        future: Adapty.getLogLevel(),
        builder: (ctx, snapshot) {
          if (snapshot.hasError && snapshot.error is AdaptyError) {
            final adaptyError = snapshot.error as AdaptyError;
            AdaptyErrorDialog.showAdaptyErrorDialog(context, adaptyError);
          }
          return Text(snapshot.hasData ? snapshot.data.toString() : '');
        },
      ),
    );
  }

  Widget _buildMethodTile(String title, void Function() onPressed, {bool openNewScreen = true}) {
    return ListTile(
      title: Text(title),
      trailing: Icon(openNewScreen ? Icons.arrow_forward_ios_outlined : Icons.info_outline_rounded, color: Colors.blueAccent),
      onTap: onPressed,
    );
  }

  Widget _buildSwitchMethodTile(String title, bool value, void Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}
