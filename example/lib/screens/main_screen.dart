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

  @override
  void initState() {
    _initialize();
    super.initState();
  }

  Future<void> _initialize() async {
    final key = 'public_live_zc1n0OPr.jvaDUN8FXq1oUYA5fRQM';
    final installId = await Service.getOrCreateInstallId();

    try {
      await Service.initializePushes();
      await Adapty.activate(key, customerUserId: installId);
      await Adapty.setLogLevel(AdaptyLogLevel.verbose);
      _subscribeForStreams(context);
    } catch (e) {
      print('#Example# activate error $e');
    }
  }

  void _subscribeForStreams(BuildContext context) {
    final scaffoldState = scaffoldKey.currentState as ScaffoldState;
    Adapty.purchaserInfoUpdateStream.listen((purchaserInfo) {
      scaffoldState?.showSnackBar(buildPurchaserInfoSnackbar(context, purchaserInfo));
      print('#Example# purchaserInfoUpdateStream:\n $purchaserInfo');
    });
    Adapty.promosReceiveStream.listen((promo) {
      scaffoldState?.showSnackBar(buildPromoSnackbar(context, promo));
      print('#Example# promosReceiveStream:\n $promo');
    });
    Adapty.deferredPurchasesStream.listen((event) {
      scaffoldState?.showSnackBar(buildSimpleSnackbar(event));
      print('#Example# deferredPurchasesStream:\n $event');
    });
    Adapty.getPaywallsResultStream.listen((event) {
      scaffoldState?.showSnackBar(buildSimpleSnackbar('Paywalls Updated!'));
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
            final scaffoldState = scaffoldKey.currentState as ScaffoldState;
            final installId = await Service.getOrCreateInstallId();
            bool res = false;
            res = await Adapty.identify(installId);
            scaffoldState.showSnackBar(buildSimpleSnackbar(res ? 'You identify with $installId.' : 'You were not identified.'));
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
          if (res != null) {
            final state = scaffoldKey.currentState as ScaffoldState;
            state.showSnackBar(buildPurchaserInfoSnackbar(context, res.purchaserInfo));
          }
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
          final testAttributionMap = {
            'af_message': 'organic install',
            'af_status': 'Organic',
            'is_first_launch': false,
          };

          await Adapty.updateAttribution(testAttributionMap, source: AdaptyAttributionNetwork.appsflyer);
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
        'Logout',
        () => callAdaptyMethod(() async {
          await Adapty.logout();
          print('#Example# logout done!');
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
      subtitle: FutureBuilder(
        future: Service.getOrCreateInstallId(),
        builder: (ctx, snapshot) {
          return Text(snapshot.hasData ? snapshot.data : '');
        },
      ),
    );
  }

  Widget _buildLogLevelTile() {
    return ListTile(
      title: Text('Log Level'),
      subtitle: FutureBuilder(
        future: Adapty.getLogLevel(),
        builder: (ctx, snapshot) {
          if (snapshot.hasError && snapshot.error is AdaptyError) {
            AdaptyErrorDialog.showAdaptyErrorDialog(context, snapshot.error);
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
}
