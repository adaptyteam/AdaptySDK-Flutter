import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/widgets/error_dialog.dart';
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

  Future<void> _initialize() async {
    try {
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
    Adapty.deferredPurchasesStream.listen((event) {
      Logger.logExampleMessage('deferredPurchasesStream:\n $event');
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
                _callIdentifyUser(_enteredCustomerUserId!);
              }
            });
          },
        ),
        ListActionTile(
          title: 'Identify',
          isActive: _enteredCustomerUserId?.isNotEmpty ?? false,
          onTap: () {
            if (_enteredCustomerUserId != null && _enteredCustomerUserId!.isNotEmpty) {
              _callIdentifyUser(_enteredCustomerUserId!);
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

  List<Widget> _paywallContents(AdaptyPaywall paywall, List<AdaptyPaywallProduct>? products, void Function(AdaptyPaywallProduct) onProductTap) {
    return [
      ListTextTile(title: 'Variation', subtitle: paywall.variationId),
      ListTextTile(title: 'Revision', subtitle: '${paywall.revision}'),
      if (products == null) ...paywall.vendorProductIds.map((e) => ListTextTile(title: e)),
      if (products != null)
        ...products.map((p) => ListActionTile(
              title: p.vendorProductId,
              subtitle: p.localizedPrice,
              onTap: () => onProductTap(p),
            ))
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
          ..._paywallContents(paywall, examplePaywallProducts, (p) => _purchaseProduct(p)),
          ListActionTile(
            title: 'Refresh',
            onTap: () => _loadExamplePaywall(),
          ),
          ListActionTile(
            title: 'Present Paywall',
            onTap: () {},
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
          ..._paywallContents(_customPaywall!, _customPaywallProducts, (p) => _purchaseProduct(p)),
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

            final profile = await _callRestorePurchases();
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
          onTap: () {},
        ),
        ListActionTile(
          title: 'Send Onboarding Order 1',
          onTap: () {},
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
          onTap: () {},
        ),
      ],
    );
  }

  // Example Data Loading

  Future<void> _callFunctionShowingProgress(Future f) async {
    setState(() {
      loading = true;
    });

    await f;

    setState(() {
      loading = false;
    });
  }

  Future<void> _loadExamplePaywall() async {
    setState(() {
      this.examplePaywall = null;
      this.examplePaywallProducts = null;
    });

    final paywall = await _callGetPaywall(examplePaywallId);

    setState(() {
      this.examplePaywall = paywall;
    });

    if (paywall == null) return;

    final products = await _callGetPaywallProducts(paywall);

    setState(() {
      this.examplePaywallProducts = products;
    });
  }

  Future<void> _reloadProfile() async {
    setState(() {
      this.loading = true;
    });

    final profile = await _callGetProfile();

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

    final paywall = await _callGetPaywall(_customPaywallId!);
    if (paywall == null) return;
    final products = await _callGetPaywallProducts(paywall);
    if (products == null) return;

    setState(() {
      this._customPaywall = paywall;
      this._customPaywallProducts = products;
    });
  }

  Future<void> _purchaseProduct(AdaptyPaywallProduct product) async {
    _setIsLoading(true);

    final profile = await _callMakePurchase(product);

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

    final profile = await _callUpdateProfile(builder.build());

    if (profile != null) {
      setState(() {
        adaptyProfile = profile;
      });
    }

    _setIsLoading(false);
  }

  // Methods Calling

  Future<AdaptyProfile?> _callGetProfile() async {
    Logger.logExampleMessage('Calling Adapty.getProfile()');

    try {
      return await Adapty.getProfile();
    } on AdaptyError catch (adaptyError) {
      AdaptyErrorDialog.showAdaptyErrorDialog(context, adaptyError);
      Logger.logExampleMessage('Adapty.getProfile()  Adapty Error: $adaptyError');
    } catch (e) {
      Logger.logExampleMessage('Adapty.getProfile() Error: $e');
    }

    return null;
  }

  Future<void> _callIdentifyUser(String customerUserId) async {
    Logger.logExampleMessage('Calling Adapty.identify()');

    try {
      await Adapty.identify(customerUserId);
    } on AdaptyError catch (adaptyError) {
      AdaptyErrorDialog.showAdaptyErrorDialog(context, adaptyError);
      Logger.logExampleMessage('Adapty.identify()  Adapty Error: $adaptyError');
    } catch (e) {
      Logger.logExampleMessage('Adapty.identify() Error: $e');
    }
  }

  Future<AdaptyProfile?> _callUpdateProfile(AdaptyProfileParameters params) async {
    Logger.logExampleMessage('Calling Adapty.updateProfile()');

    try {
      return await Adapty.updateProfile(params);
    } on AdaptyError catch (adaptyError) {
      AdaptyErrorDialog.showAdaptyErrorDialog(context, adaptyError);
      Logger.logExampleMessage('Adapty.updateProfile()  Adapty Error: $adaptyError');
    } catch (e) {
      Logger.logExampleMessage('Adapty.updateProfile() Error: $e');
    }
    return null;
  }

  Future<AdaptyPaywall?> _callGetPaywall(String paywallId) async {
    Logger.logExampleMessage('Calling Adapty.getPaywall()');

    try {
      return await Adapty.getPaywall(id: paywallId);
    } on AdaptyError catch (adaptyError) {
      AdaptyErrorDialog.showAdaptyErrorDialog(context, adaptyError);
      Logger.logExampleMessage('Adapty.getPaywall()  Adapty Error: $adaptyError');
    } catch (e) {
      Logger.logExampleMessage('Adapty.getPaywall() Error: $e');
    }

    return null;
  }

  Future<List<AdaptyPaywallProduct>?> _callGetPaywallProducts(AdaptyPaywall paywall) async {
    Logger.logExampleMessage('Calling Adapty.getPaywallProducts()');

    try {
      return await Adapty.getPaywallProducts(paywall: paywall);
    } on AdaptyError catch (adaptyError) {
      AdaptyErrorDialog.showAdaptyErrorDialog(context, adaptyError);
      Logger.logExampleMessage('Adapty.getPaywallProducts()  Adapty Error: $adaptyError');
    } catch (e) {
      Logger.logExampleMessage('Adapty.getPaywallProducts() Error: $e');
    }

    return null;
  }

  Future<AdaptyProfile?> _callMakePurchase(AdaptyPaywallProduct product) async {
    Logger.logExampleMessage('Calling Adapty.makePurchase()');

    try {
      return await Adapty.makePurchase(product: product);
    } on AdaptyError catch (adaptyError) {
      AdaptyErrorDialog.showAdaptyErrorDialog(context, adaptyError);
      Logger.logExampleMessage('Adapty.makePurchase()  Adapty Error: $adaptyError');
    } catch (e) {
      Logger.logExampleMessage('Adapty.makePurchase() Error: $e');
    }

    return null;
  }

  Future<AdaptyProfile?> _callRestorePurchases() async {
    Logger.logExampleMessage('Calling Adapty.restorePurchases()');

    try {
      return await Adapty.restorePurchases();
    } on AdaptyError catch (adaptyError) {
      AdaptyErrorDialog.showAdaptyErrorDialog(context, adaptyError);
      Logger.logExampleMessage('Adapty.restorePurchases()  Adapty Error: $adaptyError');
    } catch (e) {
      Logger.logExampleMessage('Adapty.restorePurchases() Error: $e');
    }

    return null;
  }

  // Helpers

  static final _dateFormatter = DateFormat('MMM dd, yyyy HH:mm:ss');

  String _dateTimeFormattedString(DateTime dt) {
    return _dateFormatter.format(dt.toLocal());
  }
}
