import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert' show json;

import '../../adapty_flutter.dart';
import '../models/adapty_paywall.dart';

class AdaptyUIPaywallPlatformView extends StatefulWidget {
  final AdaptyPaywall paywall;

  final void Function(AdaptyUIPaywallView)? onDidAppear;
  final void Function(AdaptyUIPaywallView)? onDidDisappear;
  final void Function(AdaptyUIPaywallView, AdaptyUIAction)? onDidPerformAction;
  final void Function(AdaptyUIPaywallView, String)? onDidSelectProduct;
  final void Function(AdaptyUIPaywallView, AdaptyPaywallProduct)? onDidStartPurchase;
  final void Function(AdaptyUIPaywallView, AdaptyPaywallProduct, AdaptyPurchaseResult)? onDidFinishPurchase;
  final void Function(AdaptyUIPaywallView, AdaptyPaywallProduct, AdaptyError)? onDidFailPurchase;
  final void Function(AdaptyUIPaywallView)? onDidStartRestore;
  final void Function(AdaptyUIPaywallView, AdaptyProfile)? onDidFinishRestore;
  final void Function(AdaptyUIPaywallView, AdaptyError)? onDidFailRestore;
  final void Function(AdaptyUIPaywallView, AdaptyError)? onDidFailRendering;
  final void Function(AdaptyUIPaywallView, AdaptyError)? onDidFailLoadingProducts;
  final void Function(AdaptyUIPaywallView, AdaptyPaywallProduct?, AdaptyError?)? onDidFinishWebPaymentNavigation;

  const AdaptyUIPaywallPlatformView({
    super.key,
    required this.paywall,
    this.onDidAppear,
    this.onDidDisappear,
    this.onDidPerformAction,
    this.onDidSelectProduct,
    this.onDidStartPurchase,
    this.onDidFinishPurchase,
    this.onDidFailPurchase,
    this.onDidStartRestore,
    this.onDidFinishRestore,
    this.onDidFailRestore,
    this.onDidFailRendering,
    this.onDidFailLoadingProducts,
    this.onDidFinishWebPaymentNavigation,
  });

  @override
  State<AdaptyUIPaywallPlatformView> createState() => _AdaptyUIPaywallPlatformViewState();
}

class _AdaptyUIPaywallPlatformViewState extends State<AdaptyUIPaywallPlatformView> implements AdaptyUIPaywallsEventsObserver {
  @override
  void dispose() {
    AdaptyUI().unregisterPaywallEventsListener(widget.paywall.instanceIdentity);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'adaptyui_paywall_platform_view',
        onPlatformViewCreated: (id) {
          AdaptyUI().registerPaywallEventsListener(this, 'flutter_native_${id}');
        },
        creationParams: json.encode(widget.paywall.jsonValue),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'adaptyui_paywall_platform_view',
        onPlatformViewCreated: (id) {
          AdaptyUI().registerPaywallEventsListener(this, 'flutter_native_${id}');
        },
        creationParams: json.encode(widget.paywall.jsonValue),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  void paywallViewDidAppear(AdaptyUIPaywallView view) => widget.onDidAppear?.call(view);

  @override
  void paywallViewDidDisappear(AdaptyUIPaywallView view) => widget.onDidDisappear?.call(view);

  @override
  void paywallViewDidPerformAction(AdaptyUIPaywallView view, AdaptyUIAction action) => widget.onDidPerformAction?.call(view, action);

  @override
  void paywallViewDidSelectProduct(AdaptyUIPaywallView view, String productId) => widget.onDidSelectProduct?.call(view, productId);

  @override
  void paywallViewDidStartPurchase(AdaptyUIPaywallView view, AdaptyPaywallProduct product) => widget.onDidStartPurchase?.call(view, product);

  @override
  void paywallViewDidFinishPurchase(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct product,
    AdaptyPurchaseResult purchaseResult,
  ) =>
      widget.onDidFinishPurchase?.call(view, product, purchaseResult);

  @override
  void paywallViewDidFailPurchase(AdaptyUIPaywallView view, AdaptyPaywallProduct product, AdaptyError error) => widget.onDidFailPurchase?.call(view, product, error);

  @override
  void paywallViewDidStartRestore(AdaptyUIPaywallView view) => widget.onDidStartRestore?.call(view);

  @override
  void paywallViewDidFinishRestore(AdaptyUIPaywallView view, AdaptyProfile profile) => widget.onDidFinishRestore?.call(view, profile);

  @override
  void paywallViewDidFailRestore(AdaptyUIPaywallView view, AdaptyError error) => widget.onDidFailRestore?.call(view, error);

  @override
  void paywallViewDidFailRendering(AdaptyUIPaywallView view, AdaptyError error) => widget.onDidFailRendering?.call(view, error);

  @override
  void paywallViewDidFailLoadingProducts(AdaptyUIPaywallView view, AdaptyError error) => widget.onDidFailLoadingProducts?.call(view, error);

  @override
  void paywallViewDidFinishWebPaymentNavigation(
    AdaptyUIPaywallView view,
    AdaptyPaywallProduct? product,
    AdaptyError? error,
  ) =>
      widget.onDidFinishWebPaymentNavigation?.call(view, product, error);
}
