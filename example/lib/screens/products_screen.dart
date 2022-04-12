import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/Helpers/value_to_string.dart';
import 'package:adapty_flutter_example/screens/discounts_screen.dart';
import 'package:adapty_flutter_example/widgets/details_container.dart';
import 'package:adapty_flutter_example/widgets/error_dialog.dart';
import 'package:flutter/material.dart';

class ProductsScreen extends StatefulWidget {
  final List<AdaptyProduct>? products;
  const ProductsScreen(this.products);

  static showProductsPage(BuildContext context, List<AdaptyProduct> products) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ProductsScreen(products),
    );
  }

  @override
  _ProductsScreenState createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool loading = false;
  @override
  Widget build(BuildContext context) {
    final products = widget.products;
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (products != null && products.isNotEmpty)
              ? ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (ctx, index) {
                    final product = products[index];
                    final details = {
                      'Vendor Product Id':
                          valueToString(product.vendorProductId),
                      'Introductory Offer Eligibility':
                          valueToString(product.introductoryOfferEligibility),
                      'Promotional Offer Eligibility':
                          valueToString(product.promotionalOfferEligibility),
                      'Promotional Offer Id':
                          valueToString(product.promotionalOfferId),
                      'Variation Id': valueToString(product.variationId),
                      'Localized Description':
                          valueToString(product.localizedDescription),
                      'Localized Title': valueToString(product.localizedTitle),
                      'Price': valueToString(product.price),
                      'Currency Code': valueToString(product.currencyCode),
                      'Currency Symbol': valueToString(product.currencySymbol),
                      'Region Code': valueToString(product.regionCode),
                      'Subscription Period':
                          adaptyPeriodToString(product.subscriptionPeriod),
                      'Free Trial Period':
                          adaptyPeriodToString(product.freeTrialPeriod),
                      'Subscription Group Identifier':
                          valueToString(product.subscriptionGroupIdentifier),
                      'Is Family Shareable':
                          valueToString(product.isFamilyShareable),
                      'Localized Price': valueToString(product.localizedPrice),
                      'Localized Subscription Period':
                          valueToString(product.localizedSubscriptionPeriod),
                      'Paywall A/B Test Name':
                          valueToString(product.paywallABTestName),
                      'Paywall Name': valueToString(product.paywallName),
                    };
                    final detailPages = {
                      if (product.introductoryDiscount != null)
                        'Introductory Discount': () =>
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => DiscountsScreen(
                                    [product.introductoryDiscount!]),
                              ),
                            ),
                      'Discounts': () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => DiscountsScreen(
                                product.discounts ??
                                    List<AdaptyProductDiscount>.empty(),
                              ),
                            ),
                          ),
                    };
                    final purchaseButton = ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          loading = true;
                        });
                        try {
                          await Adapty.instance.makePurchase(product);
                          // res.
                        } on AdaptyError catch (adaptyError) {
                          if (adaptyError.adaptyCode !=
                              AdaptyErrorCode.paymentCancelled) {
                            AdaptyErrorDialog.showAdaptyErrorDialog(
                                context, adaptyError);
                          }
                        } catch (e) {
                          print('#MakePurchase# ${e.toString()}');
                        }
                        setState(() {
                          loading = false;
                        });
                      },
                      child: const Text('Make Purchase'),
                    );
                    return DetailsContainer(
                      details: details,
                      bottomWidget: purchaseButton,
                      detailPages: detailPages,
                    );
                  },
                )
              : const Center(
                  child: Text('Products were not received.'),
                ),
    );
  }
}
