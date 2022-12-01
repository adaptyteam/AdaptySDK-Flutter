import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/widgets/action_snackbar.dart';
import 'package:adapty_flutter_example/widgets/error_dialog.dart';
import 'package:adapty_flutter_example/widgets/simple_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/list_components.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<State<Scaffold>> scaffoldKey = GlobalKey();
  bool loading = false;
  bool externalAnalyticsEnabled = false;

  final String examplePaywallId = 'example_ab_test';
  AdaptyProfile? adaptyProfile;
  AdaptyPaywall? examplePaywall;
  List<AdaptyPaywallProduct>? examplePaywallProducts;

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, () {
      this._initialize();
    });
  }

  Future<void> _initialize() async {
    // final installId = await Service.getOrCreateInstallId();

    try {
      Adapty.setLogLevel(AdaptyLogLevel.verbose);
      Adapty.activate();
      // await Adapty.identify(installId);
      // await Adapty.setLogLevel(AdaptyLogLevel.verbose);
      _subscribeForStreams(context);
      _loadExamplePaywall();
    } catch (e) {
      print('#Example# activate error $e');
    }
  }

  void _subscribeForStreams(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    Adapty.didUpdateProfileStream.listen((profile) {
      setState(() {
        adaptyProfile = profile;
      });
      scaffoldMessenger.showSnackBar(buildPurchaserInfoSnackbar(context, profile));
      print('#Example# didUpdateProfileStream:\n $profile');
    });
    Adapty.deferredPurchasesStream.listen((event) {
      scaffoldMessenger.showSnackBar(buildSimpleSnackbar(event));
      print('#Example# deferredPurchasesStream:\n $event');
    });
  }

  Future<void> _loadExamplePaywall() async {
    setState(() {
      this.examplePaywall = null;
    });
    final paywall = await Adapty.getPaywall(id: examplePaywallId);
    final products = await Adapty.getPaywallProducts(paywall: paywall);

    setState(() {
      this.examplePaywall = paywall;
      this.examplePaywallProducts = products;
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
      _buildProfileIdSection(),
      _buildProfileInfoSection(),
      _buildExampleABTestSection(),
      // _buildInstallIdTile(),
      // _buildMethodTile(
      //   'Identify',
      //   () async {
      //     callAdaptyMethod(() async {
      //       final scaffoldMessenger = ScaffoldMessenger.of(context);
      //       final installId = await Service.getOrCreateInstallId();
      //       bool res = false;
      //       res = await Adapty.identify(installId);
      //       scaffoldMessenger.showSnackBar(buildSimpleSnackbar(res ? 'You identify with $installId.' : 'You were not identified.'));
      //     });
      //   },
      //   openNewScreen: false,
      // ),
      // _buildMethodTile(
      //   'Get Paywalls',
      //   () {
      //     callAdaptyMethod(() async {
      //       final paywallResult = await Adapty.getPaywalls();
      //       Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => PaywallsScreen(paywallResult.paywalls)));
      //     });
      //   },
      // ),
      // _buildMethodTile(
      //   'Get Products',
      //   () {
      //     callAdaptyMethod(() async {
      //       final paywalls = await Adapty.getPaywalls(forceUpdate: false);
      //       final products = paywalls.products;
      //       Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => ProductsScreen(products)));
      //     });
      //   },
      // ),
      // _buildMethodTile('Get Profile', () {
      //   callAdaptyMethod(() async {
      //     final profile = await Adapty.getProfile();
      //     setState(() {
      //       this.adaptyProfileId = profile.profileId;
      //     });
      //     Navigator.of(context).push(
      //       MaterialPageRoute(builder: (ctx) => PurchaserInfoScreen(profile)),
      //     );
      //   });
      // }),
      // _buildMethodTile(
      //   'Update Profile',
      //   () => Navigator.of(context).push(
      //     MaterialPageRoute(builder: (ctx) => UpdateProfileScreen()),
      //   ),
      // ),
      // _buildMethodTile('Restore Purchases', () {
      //   callAdaptyMethod(() async {
      //     final profile = await Adapty.restorePurchases();
      //     final state = ScaffoldMessenger.of(context);
      //     state.showSnackBar(buildPurchaserInfoSnackbar(context, profile));
      //   });
      // }),
      // _buildMethodTile(
      //   'Update Attribution',
      //   () => callAdaptyMethod(() async {
      //     final attribution = {
      //       "status": "non_organicunknown",
      //       "channel": "Google Ads",
      //       "campaign": "Adapty in-app",
      //       "ad_group": "adapty ad_group",
      //       "ad_set": "adapty ad_set",
      //       "creative": "12312312312312",
      //     };
      //     await Adapty.updateAttribution(attribution, source: AdaptyAttributionNetwork.custom);

      //     print('#Example# updateAttribution done!');
      //   }),
      //   openNewScreen: false,
      // ),
      // _buildMethodTile(
      //   'Set Fallback Paywalls',
      //   () => callAdaptyMethod(() async {
      //     final testPaywalls = '''
      // {
      //   'key1': 1,
      //   'key2': '2'
      // }
      // ''';
      //     await Adapty.setFallbackPaywalls(testPaywalls);
      //     print('#Example# setFallbackPaywalls done!');
      //   }),
      //   openNewScreen: false,
      // ),
      // _buildMethodTile(
      //   'Set Transaction VariationId',
      //   () => callAdaptyMethod(() async {
      //     await Adapty.setTransactionVariationId('variation', 'af3753fe-1dcf-4f80-a2fb-0de5d55bdfde');
      //     print('#Example# setTransactionVariationId done!');
      //   }),
      //   openNewScreen: false,
      // ),
      // _buildSwitchMethodTile(
      //   'External Analytics Enabled',
      //   externalAnalyticsEnabled,
      //   (value) {
      // callAdaptyMethod(() async {
      //   await Adapty.setExternalAnalyticsEnabled(value);
      //   print('#Example# setExternalAnalyticsEnabled $value done!');
      //   setState(() {
      //     externalAnalyticsEnabled = value;
      //   });
      // });
      //   },
      // ),
      // if (Platform.isIOS)
      //   _buildMethodTile(
      //     'Present Code Redemption Sheet',
      //     () => callAdaptyMethod(() async {
      //       await Adapty.presentCodeRedemptionSheet();
      //     }),
      //   ),
      // _buildMethodTile(
      //   'Logout',
      //   () => callAdaptyMethod(() async {
      //     final result = await Adapty.logout();
      //     if (result) {
      //       print('#Example# logout done!');
      //     } else {
      //       print('#Example# logout is not succes');
      //     }
      //   }),
      // ),
    ];
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text('Welcome to Adapty!'),
      ),
      body: Container(
        color: Color.fromRGBO(240, 240, 240, 1.0),
        child: Center(
          child: loading
              ? CircularProgressIndicator()
              : ListView.builder(
                  itemBuilder: (ctx, idx) => listViewChildren[idx],
                  itemCount: listViewChildren.length,
                ),
        ),
      ),
    );
  }

  Widget _buildProfileIdSection() {
    return ListSection(
      headerText: 'Adapty Profile Id',
      footerText: '👆🏻 Tap to copy',
      children: [
        ListTextTile(
          title: this.adaptyProfile != null ? '${this.adaptyProfile!.profileId}' : 'null',
          onTap: this.adaptyProfile != null
              ? () {
                  Clipboard.setData(ClipboardData(text: this.adaptyProfile!.profileId));
                }
              : null,
        ),
      ],
    );
  }

  String _dateTimeFormattedString(DateTime dt) {
    return dt.toIso8601String();
  }

  Widget _buildProfileInfoSection() {
    final premium = adaptyProfile?.accessLevels['premium'];

    return ListSection(
      headerText: 'Profile',
      children: [
        ListTextTile(
          title: 'Premium',
          subtitle: (premium?.isActive ?? false) ? 'Active' : 'Inactive',
          subtitleColor: (premium?.isActive ?? false) ? Colors.greenAccent : Colors.redAccent,
        ),
        ListTextTile(title: 'Is Lifetime', subtitle: (premium?.isLifetime ?? false) ? 'true' : 'false'),
        if (premium != null) ListTextTile(title: 'Activated At', subtitle: _dateTimeFormattedString(premium.activatedAt)),
        if (premium != null && premium.renewedAt != null) ListTextTile(title: 'Renewed At', subtitle: _dateTimeFormattedString(premium.renewedAt!)),
        if (premium != null && premium.expiresAt != null) ListTextTile(title: 'Expires At', subtitle: _dateTimeFormattedString(premium.expiresAt!)),
        ListTextTile(title: 'Will Renew', subtitle: (premium?.willRenew ?? false) ? 'true' : 'false'),
        ListTextTile(title: 'Subscriptions: ${adaptyProfile?.subscriptions.length ?? 0}'),
        ListTextTile(title: 'NonSubscriptions: ${adaptyProfile?.nonSubscriptions.length ?? 0}'),
        ListTextTile(
          title: 'Update',
          titleColor: Colors.blue,
          onTap: () {
            callAdaptyMethod(() async {
              final profile = await Adapty.getProfile();
              setState(() {
                adaptyProfile = profile;
              });
            });
          },
        ),
      ],
    );
  }

  Widget _buildExampleABTestSection() {
    final paywall = this.examplePaywall;

    if (paywall == null) {
      return ListSection(
        headerText: 'Example A/B Test',
        children: [
          ListTextTile(
            title: examplePaywallId,
            subtitle: 'Loading...',
            subtitleColor: Colors.blue,
          ),
        ],
      );
    } else {
      return ListSection(
        headerText: 'Example A/B Test',
        children: [
          ListTextTile(title: examplePaywallId, subtitle: 'OK', subtitleColor: Colors.greenAccent),
          ListTextTile(title: 'Variation', subtitle: paywall.variationId),
          ListTextTile(title: 'Revision', subtitle: '${paywall.revision}'),
          ...paywall.vendorProductIds.map((e) => ListTextTile(title: e)),
          ListTextTile(
            title: 'Refresh',
            titleColor: Colors.blue,
            onTap: () => _loadExamplePaywall(),
          ),
          ListTextTile(
            title: 'Present Paywall',
            titleColor: Colors.blue,
            onTap: () {},
          ),
        ],
      );
    }
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
