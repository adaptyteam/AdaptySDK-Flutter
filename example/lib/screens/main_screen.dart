import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/purchase_observer.dart';
import 'package:adapty_flutter_example/screens/paywall_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../Helpers/logger.dart';
import '../widgets/list_components.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final observer = PurchasesObserver();

  bool loading = false;
  bool externalAnalyticsEnabled = false;

  String? _enteredCustomerUserId;

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

  void _setIsLoading(bool value) {
    setState(() {
      loading = value;
    });
  }

  Future<void> _showErrorDialog(String title, String message) {
    return showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              }),
        ],
      ),
    );
  }

  Future<void> _initialize() async {
    try {
      observer.onAdaptyErrorOccured = (error) {
        _showErrorDialog('Adapty Error ${error.code}', error.message);
      };

      observer.onUnknownErrorOccured = (error) {
        _showErrorDialog('Unknown Error', error.toString());
      };

      Adapty.setLogLevel(AdaptyLogLevel.verbose);
      Adapty.activate();

      _subscribeForStreams(context);
      _reloadProfile();
      _loadExamplePaywall();
    } catch (e) {
      print('#Example# activate error $e');
    }
  }

  void _subscribeForStreams(BuildContext context) {
    Adapty.didUpdateProfileStream.listen((profile) {
      setState(() {
        adaptyProfile = profile;
      });
      Logger.logExampleMessage('didUpdateProfileStream:\n $profile');
    });
  }

  Widget _buildLoadingDimmingWidget() {
    return Container(
      decoration: BoxDecoration(color: CupertinoColors.black.withAlpha(200)),
      child: Center(
        child: CupertinoActivityIndicator(
          color: CupertinoColors.white,
          radius: 20.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Welcome to Adapty Flutter!'),
          ),
          child: SafeArea(
            child: ListView(
              children: [
                _buildProfileIdSection(),
                _buildIdentifySection(),
                _buildProfileInfoSection(),
                _buildExampleABTestSection(),
                _buildCustomPaywallSection(),
                _buildOtherActionsSection(),
                _buildLogoutSection(),
              ],
            ),
          ),
        ),
        if (this.loading) _buildLoadingDimmingWidget(),
      ],
    );
  }

  Widget _buildProfileIdSection() {
    return ListSection(
      headerText: 'Adapty Profile Id',
      footerText: '👆🏻 Tap to copy',
      children: [
        ListActionTile(
          title: this.adaptyProfile != null ? '${this.adaptyProfile!.profileId}' : 'null',
          isActive: this.adaptyProfile != null,
          onTap: () {
            Clipboard.setData(ClipboardData(text: this.adaptyProfile!.profileId));
          },
        ),
      ],
    );
  }

  Widget _buildIdentifySection() {
    return ListSection(
      headerText: 'Customer User Id',
      footerText: null,
      children: [
        if (adaptyProfile?.customerUserId != null) ListTextTile(title: 'Current', subtitle: adaptyProfile!.customerUserId!),
        ListTextFieldTile(
          placeholder: 'Enter Customer User Id',
          onChanged: (txt) => setState(() {
            _enteredCustomerUserId = txt;
          }),
          onSubmitted: (txt) {
            setState(() {
              _enteredCustomerUserId = txt;
              if (_enteredCustomerUserId != null && _enteredCustomerUserId!.isNotEmpty) {
                observer.callIdentifyUser(_enteredCustomerUserId!);
              }
            });
          },
        ),
        ListActionTile(
          title: 'Identify',
          isActive: _enteredCustomerUserId?.isNotEmpty ?? false,
          onTap: () {
            if (_enteredCustomerUserId != null && _enteredCustomerUserId!.isNotEmpty) {
              observer.callIdentifyUser(_enteredCustomerUserId!);
            }
          },
        ),
      ],
    );
  }

  Widget _buildProfileInfoSection() {
    final premium = adaptyProfile?.accessLevels['premium'];

    return ListSection(
      headerText: 'Profile',
      children: [
        ListTextTile(
          title: 'Premium',
          subtitle: (premium?.isActive ?? false) ? 'Active' : 'Inactive',
          subtitleColor: (premium?.isActive ?? false) ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
        ),
        ListTextTile(title: 'Is Lifetime', subtitle: (premium?.isLifetime ?? false) ? 'true' : 'false'),
        if (premium != null) ListTextTile(title: 'Activated At', subtitle: _dateTimeFormattedString(premium.activatedAt)),
        if (premium != null && premium.renewedAt != null) ListTextTile(title: 'Renewed At', subtitle: _dateTimeFormattedString(premium.renewedAt!)),
        if (premium != null && premium.expiresAt != null) ListTextTile(title: 'Expires At', subtitle: _dateTimeFormattedString(premium.expiresAt!)),
        ListTextTile(title: 'Will Renew', subtitle: (premium?.willRenew ?? false) ? 'true' : 'false'),
        ListTextTile(title: 'Subscriptions: ${adaptyProfile?.subscriptions.length ?? 0}'),
        ListTextTile(title: 'NonSubscriptions: ${adaptyProfile?.nonSubscriptions.length ?? 0}'),
        ListActionTile(title: 'Update', onTap: () => _reloadProfile()),
      ],
    );
  }

  List<Widget> _paywallContents(AdaptyPaywall paywall, List<AdaptyPaywallProduct>? products, void Function(AdaptyPaywallProduct) onProductTap, void Function() onLogShowTap) {
    return [
      ListTextTile(title: 'Variation', subtitle: paywall.variationId),
      ListTextTile(title: 'Revision', subtitle: '${paywall.revision}'),
      if (products == null) ...paywall.vendorProductIds.map((e) => ListTextTile(title: e)),
      if (products != null)
        ...products.map((p) => ListActionTile(
              title: p.vendorProductId,
              subtitle: p.localizedPrice,
              onTap: () => onProductTap(p),
            )),
      ListActionTile(
        title: 'Log Show Paywall',
        onTap: () => onLogShowTap(),
      )
    ];
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
            subtitleColor: CupertinoColors.systemBlue,
          ),
        ],
      );
    } else {
      return ListSection(
        headerText: 'Example A/B Test',
        children: [
          ListTextTile(
            title: examplePaywallId,
            subtitle: 'OK',
            subtitleColor: CupertinoColors.systemGreen,
          ),
          ..._paywallContents(
            paywall,
            examplePaywallProducts,
            (p) => _purchaseProduct(p),
            () => observer.callLogShowPaywall(paywall),
          ),
          ListActionTile(
            title: 'Refresh',
            onTap: () => _loadExamplePaywall(),
          ),
          ListActionTile(
            title: 'Present Paywall',
            onTap: () {
              showCupertinoDialog(
                  context: context,
                  builder: (ctx) {
                    return PaywallScreen(paywall: paywall);
                  });
            },
          ),
        ],
      );
    }
  }

  String? _customPaywallId;
  AdaptyPaywall? _customPaywall;
  List<AdaptyPaywallProduct>? _customPaywallProducts;

  Widget _buildCustomPaywallSection() {
    return ListSection(
      headerText: 'Custom Paywall',
      footerText: 'Here you can load any paywall by its id and inspect the contents',
      children: [
        if (_customPaywall == null) ...[
          ListTextTile(title: 'No Paywal Loaded'),
          ListTextFieldTile(
            placeholder: 'Enter Paywall Id',
            onChanged: (id) => setState(() {
              this._customPaywallId = id;
            }),
            onSubmitted: (id) {
              this._customPaywallId = id;
              _loadCustomPaywall();
            },
          ),
          ListActionTile(
            title: 'Load',
            isActive: _customPaywallId?.isNotEmpty ?? false,
            onTap: () => _loadCustomPaywall(),
          ),
        ],
        if (_customPaywall != null) ...[
          ListTextTile(title: 'Paywall Id', subtitle: _customPaywall!.id),
          ..._paywallContents(
            _customPaywall!,
            _customPaywallProducts,
            (p) => _purchaseProduct(p),
            () => observer.callLogShowPaywall(_customPaywall!),
          ),
          ListActionTile(
            title: 'Reset',
            isActive: _customPaywallId?.isNotEmpty ?? false,
            onTap: () {
              setState(() {
                _customPaywall = null;
                _customPaywallProducts = null;
                _customPaywallId = null;
              });
            },
          ),
        ],
      ],
    );
  }

  Widget _buildOtherActionsSection() {
    return ListSection(
      headerText: 'Other Actions',
      footerText: null,
      children: [
        ListActionTile(
          title: 'Restore Purchases',
          onTap: () async {
            _setIsLoading(true);

            final profile = await observer.callRestorePurchases();
            if (profile != null) {
              this.adaptyProfile = profile;
            }

            _setIsLoading(false);
          },
        ),
        ListActionTile(
          title: 'Update Profile',
          onTap: () => _updateProfile(),
        ),
        ListActionTile(
          title: 'Update Attribution',
          onTap: () => _updateAttribution(),
        ),
        ListActionTile(
          title: 'Send Onboarding Order 1',
          onTap: () async {
            _setIsLoading(true);

            await observer.callLogShowOnboarding('test_name', 'test_screen', 3);

            _setIsLoading(false);
          },
        ),
      ],
    );
  }

  Widget _buildLogoutSection() {
    return ListSection(
      headerText: null,
      footerText: null,
      children: [
        ListActionTile(
          title: 'Logout',
          titleColor: CupertinoColors.destructiveRed,
          onTap: () => _logout(),
        ),
      ],
    );
  }

  // Example Data Loading

  Future<void> _loadExamplePaywall() async {
    setState(() {
      this.examplePaywall = null;
      this.examplePaywallProducts = null;
    });

    final paywall = await observer.callGetPaywall(examplePaywallId);

    setState(() {
      this.examplePaywall = paywall;
    });

    if (paywall == null) return;

    final products = await observer.callGetPaywallProducts(paywall, AdaptyIOSProductsFetchPolicy.defaultPolicy);

    setState(() {
      this.examplePaywallProducts = products;
    });
  }

  Future<void> _reloadProfile() async {
    setState(() {
      this.loading = true;
    });

    final profile = await observer.callGetProfile();

    if (profile != null) {
      setState(() {
        this.adaptyProfile = profile;
        this.loading = false;
      });
    } else {
      setState(() {
        this.loading = false;
      });
    }
  }

  Future<void> _loadCustomPaywall() async {
    if (_customPaywallId?.isEmpty ?? true) return;

    setState(() {
      this._customPaywall = null;
      this._customPaywallProducts = null;
    });

    final paywall = await observer.callGetPaywall(_customPaywallId!);
    if (paywall == null) return;
    final products = await observer.callGetPaywallProducts(paywall, AdaptyIOSProductsFetchPolicy.defaultPolicy);
    if (products == null) return;

    setState(() {
      this._customPaywall = paywall;
      this._customPaywallProducts = products;
    });
  }

  Future<void> _purchaseProduct(AdaptyPaywallProduct product) async {
    _setIsLoading(true);

    final profile = await observer.callMakePurchase(product);

    if (profile != null) {
      setState(() {
        this.adaptyProfile = profile;
      });
    }

    _setIsLoading(false);
  }

  Future<void> _updateProfile() async {
    _setIsLoading(true);

    final builder = AdaptyProfileParametersBuilder()
      ..setFirstName('John')
      ..setLastName('Appleseed')
      ..setBirthday(DateTime(1990, 5, 14))
      ..setGender(AdaptyProfileGender.female)
      ..setEmail('example@adapty.io');

    await observer.callUpdateProfile(builder.build());

    _setIsLoading(false);
  }

  Future<void> _updateAttribution() async {
    _setIsLoading(true);

    await observer.callUpdateAttribution({'key1': 'value1', 'key2': 'value2'}, AdaptyAttributionSource.custom, '123456');

    _setIsLoading(false);
  }

  Future<void> _logout() async {
    _setIsLoading(true);

    await observer.callLogout();

    setState(() {
      this.adaptyProfile = null;
      this.examplePaywall = null;
      this.examplePaywallProducts = null;
    });

    _reloadProfile();
    _loadExamplePaywall();
  }

  // Helpers

  static final _dateFormatter = DateFormat('MMM dd, yyyy HH:mm:ss');

  String _dateTimeFormattedString(DateTime dt) {
    return _dateFormatter.format(dt.toLocal());
  }
}
