import 'dart:io';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../widgets/list_components.dart';
import 'paywalls_view.dart';
import '../Helpers/custom_asset_base64_image.dart' show base64ImageData;

typedef OnAdaptyErrorCallback = void Function(AdaptyError error);
typedef OnCustomErrorCallback = void Function(Object error);

class PaywallsList extends StatefulWidget {
  const PaywallsList({
    super.key,
    required this.adaptyErrorCallback,
    required this.customErrorCallback,
  });

  final OnAdaptyErrorCallback adaptyErrorCallback;
  final OnCustomErrorCallback customErrorCallback;

  @override
  State<PaywallsList> createState() => _PaywallsListState();
}

class PaywallsListItem {
  String id;
  AdaptyPaywall? paywall;
  AdaptyError? error;

  PaywallsListItem({
    required this.id,
    this.paywall,
    this.error,
  });
}

class _PaywallsListState extends State<PaywallsList> {
  List<String>? _paywallsIds;

  final Map<String, PaywallsListItem> _paywallsItems = {};

  @override
  void initState() {
    PaywallsViewSharedState().onNeedsUpdateState = (ids) {
      setState(() {
        _paywallsIds = ids;
        _loadPaywalls();
      });
    };
    _loadPaywalls();

    super.initState();
  }

  Future<void> _loadPaywallData(String id) async {
    try {
      _paywallsItems[id] = PaywallsListItem(
        id: id,
        paywall: await Adapty().getPaywall(placementId: id),
      );

      setState(() {});
    } on AdaptyError catch (e) {
      _paywallsItems[id] = PaywallsListItem(id: id, error: e);

      widget.adaptyErrorCallback(e);
    } catch (e) {
      widget.customErrorCallback(e);
    }
  }

  void _loadPaywalls() {
    for (var id in _paywallsIds ?? []) {
      _paywallsItems[id] = PaywallsListItem(id: id);
      setState(() {});
      _loadPaywallData(id);
    }
  }

  bool _loadingPaywall = false;
  bool _loadingPaywallWithProducts = false;

  final Map<String, String>? _customTags = {
    'CUSTOM_TAG_NAME': 'Walter White',
    'CUSTOM_TAG_PHONE': '+1 234 567890',
    'CUSTOM_TAG_CITY': 'Albuquerque',
    'CUSTOM_TAG_EMAIL': 'walter@white.com',
  };

  final Map<String, DateTime>? _customTimers = {
    'CUSTOM_TIMER_24H': DateTime.now().add(const Duration(seconds: 86400)),
    'CUSTOM_TIMER_10H': DateTime.now().add(const Duration(seconds: 36000)),
    'CUSTOM_TIMER_1H': DateTime.now().add(const Duration(seconds: 3600)),
    'CUSTOM_TIMER_10M': DateTime.now().add(const Duration(seconds: 600)),
    'CUSTOM_TIMER_1M': DateTime.now().add(const Duration(seconds: 60)),
    'CUSTOM_TIMER_10S': DateTime.now().add(const Duration(seconds: 10)),
    'CUSTOM_TIMER_5S': DateTime.now().add(const Duration(seconds: 5)),
  };

  final Map<String, AdaptyCustomAsset>? _customAssets = {
    'custom_image_walter_white': AdaptyCustomAsset.localImageAsset(
      assetId: 'assets/images/Walter_White.png',
    ),
    'hero_image': AdaptyCustomAsset.localImageAsset(
      assetId: 'assets/images/landscape.png',
    ),
    'apple_icon_image': AdaptyCustomAsset.localImageData(
      data: base64ImageData,
    ),
    'custom_video_mp4': AdaptyCustomAsset.localVideoAsset(
      assetId: 'assets/videos/demo_video.mp4',
    ),
    'custom_image_landscape': AdaptyCustomAsset.localImageAsset(
      assetId: 'assets/images/landscape.png',
    ),
    'custom_color_orange': AdaptyCustomAsset.color(color: Colors.orange),
    'custom_bright_gradient': AdaptyCustomAsset.linearGradient(
      gradient: LinearGradient(
        colors: [Colors.white.withAlpha(0), Colors.green.withAlpha(128), Colors.yellow],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    ),
  };

  Future<void> _createAndPresentPaywallView(
    AdaptyPaywall paywall,
    bool loadProducts,
    AdaptyUIIOSPresentationStyle iosPresentationStyle,
  ) async {
    setState(() {
      _loadingPaywall = !loadProducts;
      _loadingPaywallWithProducts = loadProducts;
    });

    try {
      final view = await AdaptyUI().createPaywallView(
        paywall: paywall,
        customTags: _customTags,
        customTimers: _customTimers,
        customAssets: _customAssets,
        preloadProducts: loadProducts,
        productPurchaseParams: Map.fromEntries(
          paywall.productIdentifiers.map(
            (e) {
              final parameters = AdaptyPurchaseParametersBuilder();
              // ..setObfuscatedAccountId('123e4567-e89b-12d3-a456-426614174000')
              // ..setObfuscatedProfileId('123e4567-e89b-12d3-a456-426614174000');

              return MapEntry(e, parameters.build());
            },
          ),
        ),
      );

      await view.present(iosPresentationStyle: iosPresentationStyle);
    } on AdaptyError catch (e) {
      widget.adaptyErrorCallback(e);
    } catch (e) {
      widget.customErrorCallback(e);
    } finally {
      setState(() {
        _loadingPaywall = false;
        _loadingPaywallWithProducts = false;
      });
    }
  }

  void _showToast(String title, String description) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: ToastificationStyle.minimal,
      title: Text(title),
      description: Text(description),
      autoCloseDuration: const Duration(seconds: 3),
    );
  }

  Future<void> _showPaywallPlatformView(AdaptyPaywall paywall, bool showToastEvents) async {
    try {
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (BuildContext context) => CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text('Paywall ${paywall.placement.id}'),
            ),
            child: SafeArea(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: CupertinoColors.systemBackground,
                child: AdaptyUIPaywallPlatformView(
                  paywall: paywall,
                  customTags: _customTags,
                  customTimers: _customTimers,
                  customAssets: _customAssets,
                  productPurchaseParams: Map.fromEntries(
                    paywall.productIdentifiers.map(
                      (e) => MapEntry(e, AdaptyPurchaseParametersBuilder().build()),
                    ),
                  ),
                  onDidAppear: (view) {
                    print('#Example# Platform View onDidAppear');
                    if (showToastEvents) {
                      _showToast('Action: onDidAppear', 'View: $view');
                    }
                  },
                  onDidDisappear: (view) {
                    print('#Example# Platform View onDidDisappear');
                    if (showToastEvents) {
                      _showToast('Action: onDidDisappear', 'View: $view');
                    }
                  },
                  onDidPerformAction: (view, action) {
                    print('#Example# Platform View onDidPerformAction: $action');
                    if (showToastEvents) {
                      _showToast('Action: onDidPerformAction', 'Action: $action');
                    }

                    switch (action) {
                      case const CloseAction():
                        Navigator.of(context).pop();
                        break;
                      default:
                        break;
                    }
                  },
                  onDidSelectProduct: (view, productId) {
                    print('#Example# Platform View onDidSelectProduct: $productId');
                    if (showToastEvents) {
                      _showToast('Action: onDidSelectProduct', 'ProductId: $productId');
                    }
                  },
                  onDidStartPurchase: (view, product) {
                    print('#Example# Platform View onDidStartPurchase: $product');
                    if (showToastEvents) {
                      _showToast('Action: onDidStartPurchase', 'Product: $product');
                    }
                  },
                  onDidFinishPurchase: (view, product, result) {
                    print('#Example# Platform View onDidFinishPurchase: $product, $result');
                    if (showToastEvents) {
                      _showToast('Action: onDidFinishPurchase', 'Product: $product, Result: $result');
                    }
                  },
                  onDidFailPurchase: (view, product, error) {
                    print('#Example# Platform View onDidFailPurchase: $product, $error');
                    if (showToastEvents) {
                      _showToast('Action: onDidFailPurchase', 'Product: $product, Error: $error');
                    }
                  },
                  onDidStartRestore: (view) {
                    print('#Example# Platform View onDidStartRestore');
                    if (showToastEvents) {
                      _showToast('Action: onDidStartRestore', 'View: $view');
                    }
                  },
                  onDidFinishRestore: (view, profile) {
                    print('#Example# Platform View onDidFinishRestore: $profile');
                    if (showToastEvents) {
                      _showToast('Action: onDidFinishRestore', 'Profile: $profile');
                    }
                  },
                  onDidFailRestore: (view, error) {
                    print('#Example# Platform View onDidFailRestore: $error');
                    if (showToastEvents) {
                      _showToast('Action: onDidFailRestore', 'Error: $error');
                    }
                  },
                  onDidFailRendering: (view, error) {
                    print('#Example# Platform View onDidFailRendering: $error');
                    if (showToastEvents) {
                      _showToast('Action: onDidFailRendering', 'Error: $error');
                    }
                  },
                  onDidFailLoadingProducts: (view, error) {
                    print('#Example# Platform View onDidFailLoadingProducts: $error');
                    if (showToastEvents) {
                      _showToast('Action: onDidFailLoadingProducts', 'Error: $error');
                    }
                  },
                  onDidFinishWebPaymentNavigation: (view, product, error) {
                    print('#Example# Platform View onDidFinishWebPaymentNavigation: $product, $error');
                    if (showToastEvents) {
                      _showToast('Action: onDidFinishWebPaymentNavigation', 'Product: $product, Error: $error');
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      );
    } on AdaptyError catch (e) {
      widget.adaptyErrorCallback(e);
    } catch (e) {
      widget.customErrorCallback(e);
    } finally {
      setState(() {
        _loadingPaywall = false;
        _loadingPaywallWithProducts = false;
      });
    }
  }

  List<Widget> _buildErrorStatusItems() {
    return const [
      ListTextTile(
        title: 'Status',
        subtitle: 'Error',
        subtitleColor: CupertinoColors.systemRed,
      ),
    ];
  }

  List<Widget> _buildPaywallItems(AdaptyPaywall paywall) {
    return [
      const ListTextTile(
        title: 'Status',
        subtitle: 'OK',
        subtitleColor: CupertinoColors.systemGreen,
      ),
      ListTextTile(
        title: 'Variation Id',
        subtitle: paywall.variationId,
      ),
      ListTextTile(
        title: 'Has View',
        subtitle: paywall.hasViewConfiguration ? 'true' : 'false',
        subtitleColor: paywall.hasViewConfiguration ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
      ),
      if (paywall.hasViewConfiguration) ...[
        if (Platform.isIOS) ...[
          ListActionTile(
            title: 'Present Page Sheet',
            showProgress: _loadingPaywall,
            onTap: () => _createAndPresentPaywallView(paywall, false, AdaptyUIIOSPresentationStyle.pageSheet),
          ),
        ],
        ListActionTile(
          title: 'Present Full Screen',
          showProgress: _loadingPaywall,
          onTap: () => _createAndPresentPaywallView(paywall, false, AdaptyUIIOSPresentationStyle.fullScreen),
        ),
        ListActionTile(
          title: 'Present Platform View',
          showProgress: _loadingPaywall,
          onTap: () => _showPaywallPlatformView(paywall, true),
        ),
        ListActionTile(
          title: 'Load Products and Present',
          showProgress: _loadingPaywallWithProducts,
          onTap: () => _createAndPresentPaywallView(paywall, true, AdaptyUIIOSPresentationStyle.fullScreen),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: (_paywallsIds ?? []).map((paywallId) {
          final item = _paywallsItems[paywallId];

          return ListSection(
            headerText: 'Paywall $paywallId',
            children: item?.paywall == null ? _buildErrorStatusItems() : _buildPaywallItems(item!.paywall!),
          );
        }).toList(),
      ),
    );
  }
}
