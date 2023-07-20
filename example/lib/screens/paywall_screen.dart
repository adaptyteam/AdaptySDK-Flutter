import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/cupertino.dart';

import '../Helpers/value_to_string.dart';
import '../purchase_observer.dart';

extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

extension PaywallScreenRemoteConfig on AdaptyPaywall {
  String? remoteTitleText() {
    return this.remoteConfig?['title'];
  }

  String? remoteSubtitleText() {
    return this.remoteConfig?['subtitle'];
  }

  Color? remoteBackgroundColor() {
    final hexColor = this.remoteConfig?['background_color'];
    if (hexColor == null) return null;
    return HexColor.fromHex(hexColor);
  }

  Color? remoteAccentColor() {
    final hexColor = this.remoteConfig?['accent_color'];
    if (hexColor == null) return null;
    return HexColor.fromHex(hexColor);
  }

  bool isHorizontal() {
    return this.remoteConfig?['is_horisontal'] ?? false;
  }
}

class PaywallScreen extends StatefulWidget {
  final AdaptyPaywall paywall;
  const PaywallScreen({Key? key, required this.paywall}) : super(key: key);

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  List<AdaptyPaywallProduct>? products;
  Map<String, AdaptyEligibility>? productsEligibilities;

  void _dismiss() {
    Navigator.of(context).pop();
  }

  Future<void> _fetchProducts() async {
    final products = await PurchasesObserver().callGetPaywallProducts(
      widget.paywall,
    );

    setState(() {
      this.products = products;
    });

    if (products == null) return;

    final productsEligibilities = await PurchasesObserver().callGetProductsIntroductoryOfferEligibility(products);

    setState(() {
      this.productsEligibilities = productsEligibilities;
    });
  }

  Future<void> _purchaseProduct(AdaptyPaywallProduct product) async {
    final profile = await PurchasesObserver().callMakePurchase(product);

    if (profile?.accessLevels['premium']?.isActive ?? false) {
      _dismiss();
    }
  }

  Future<void> _restorePurchases() async {
    final profile = await PurchasesObserver().callRestorePurchases();

    if (profile?.accessLevels['premium']?.isActive ?? false) {
      _dismiss();
    }
  }

  Widget _introEligibilityText(AdaptyEligibility? eligibility) {
    if (eligibility == null) return Text('unknown');

    switch (eligibility) {
      case AdaptyEligibility.eligible:
        return Text('eligible');
      case AdaptyEligibility.ineligible:
        return Text('ineligible');
      case AdaptyEligibility.notApplicable:
        return Text('notApplicable');
      default:
        return Text('unknown');
    }
  }

  Widget _verticalPurchaseButton(AdaptyPaywallProduct product) {
    final discount = product.introductoryDiscount; //.discounts.length > 0 ? product.discounts.first : null;

    return CupertinoButton(
      padding: const EdgeInsets.all(4.0),
      color: widget.paywall.remoteAccentColor(),
      child: Column(
        children: [
          Text(
            '${product.vendorProductId}',
            style: TextStyle(fontSize: 14),
          ),
          Text(
            '${product.localizedPrice}',
            style: TextStyle(fontSize: 14),
          ),
          if (discount != null)
            Text(
              '${discount.paymentMode.toReadableString()}  ${discount.localizedPrice}',
              style: TextStyle(fontSize: 14),
            ),
          if (discount == null) Text('Discount Not Found', style: TextStyle(fontSize: 14)),
          _introEligibilityText(productsEligibilities?[product.vendorProductId])
        ],
      ),
      onPressed: () => _purchaseProduct(product),
    );
  }

  Widget _horizontalPurchaseButton(AdaptyPaywallProduct product) {
    final discount = product.introductoryDiscount;

    return CupertinoButton.filled(
      child: Column(
        children: [
          Text(
            '${product.vendorProductId} for ${product.localizedPrice}',
            style: TextStyle(fontSize: 14),
          ),
          if (discount != null)
            Text(
              '${discount.paymentMode.toReadableString()} ${discount.localizedPrice}',
              style: TextStyle(fontSize: 14),
            ),
          if (discount == null) Text('Discount Not Found', style: TextStyle(fontSize: 14)),
        ],
      ),
      onPressed: () => _purchaseProduct(product),
    );
  }

  Widget _purchaseButtonsBlock(AdaptyPaywall paywall, List<AdaptyPaywallProduct> products) {
    if (paywall.isHorizontal()) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: products
            .map((e) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _horizontalPurchaseButton(e),
                ))
            .toList(),
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: products.map((e) => _verticalPurchaseButton(e)).toList(),
      );
    }
  }

  Widget _restoreButton() {
    return CupertinoButton(child: Text('Restore Purchases'), onPressed: _restorePurchases);
  }

  @override
  void initState() {
    _fetchProducts();
    _sendPaywallShown();
    super.initState();
  }

  void _sendPaywallShown() {
    PurchasesObserver().callLogShowPaywall(widget.paywall);
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.paywall.remoteBackgroundColor() ?? CupertinoColors.white;
    final accentColor = widget.paywall.remoteAccentColor() ?? CupertinoColors.black;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(widget.paywall.name, style: TextStyle(color: accentColor)),
        backgroundColor: backgroundColor,
      ),
      child: Container(
        decoration: BoxDecoration(color: backgroundColor),
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                'Welcome to Adapty',
                style: TextStyle(fontSize: 36, color: accentColor),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                widget.paywall.remoteTitleText() ?? 'null',
                style: TextStyle(fontSize: 32),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                widget.paywall.remoteSubtitleText() ?? 'null',
                style: TextStyle(fontSize: 24, color: accentColor),
              ),
            ),
            SizedBox(height: 64),
            if (this.products != null) _purchaseButtonsBlock(widget.paywall, this.products!),
            if (this.products == null) Center(child: Text('Loading Products...')),
            _restoreButton()
          ],
        ),
      ),
    );
  }
}
