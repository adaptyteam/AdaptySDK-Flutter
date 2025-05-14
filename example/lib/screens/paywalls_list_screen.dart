import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../widgets/list_components.dart';
import 'paywalls_view.dart';

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

  PaywallsListItem({required this.id, this.paywall, this.error});
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
      _paywallsItems[id] = PaywallsListItem(id: id, paywall: await Adapty().getPaywall(placementId: id));

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

  Future<void> _createAndPresentPaywallView(AdaptyPaywall paywall, bool loadProducts) async {
    setState(() {
      _loadingPaywall = !loadProducts;
      _loadingPaywallWithProducts = loadProducts;
    });

    try {
      final videoUrl = 'https://firebasestorage.googleapis.com/v0/b/character---ai-chat.appspot.com/o/test%2Ffile_example_MP4_640_3MG.mp4?alt=media&token=5abf0c75-3843-4ac1-b82e-6184db692b63';

      final view = await AdaptyUI().createPaywallView(
        paywall: paywall,
        customTags: {
          'CUSTOM_TAG_NAME': 'Walter White',
          'CUSTOM_TAG_PHONE': '+1 234 567890',
          'CUSTOM_TAG_CITY': 'Albuquerque',
          'CUSTOM_TAG_EMAIL': 'walter@white.com',
        },
        customTimers: {
          'CUSTOM_TIMER_24H': DateTime.now().add(const Duration(seconds: 86400)),
          'CUSTOM_TIMER_10H': DateTime.now().add(const Duration(seconds: 36000)),
          'CUSTOM_TIMER_1H': DateTime.now().add(const Duration(seconds: 3600)),
          'CUSTOM_TIMER_10M': DateTime.now().add(const Duration(seconds: 600)),
          'CUSTOM_TIMER_1M': DateTime.now().add(const Duration(seconds: 60)),
          'CUSTOM_TIMER_10S': DateTime.now().add(const Duration(seconds: 10)),
          'CUSTOM_TIMER_5S': DateTime.now().add(const Duration(seconds: 5)),
        },
        customAssets: {
          'custom_image_bullet': AdaptyCustomAsset.localImage(
            asset: AdaptyLocalImageAsset.asset(assetId: 'assets/images/logo.png'),
          ),
          'custom_image_walter_white': AdaptyCustomAsset.localImage(
            asset: AdaptyLocalImageAsset.asset(assetId: 'assets/images/Walter_White.png'),
          ),
          'hero_image': AdaptyCustomAsset.localImage(
            asset: AdaptyLocalImageAsset.asset(assetId: 'assets/images/landscape.png'),
          ),
          'custom_image_landscape': AdaptyCustomAsset.localImage(
            asset: AdaptyLocalImageAsset.asset(assetId: 'assets/images/landscape.png'),
          ),
          'hero_video': AdaptyCustomAsset.remoteVideo(url: videoUrl),
          'custom_video_mp4': AdaptyCustomAsset.remoteVideo(url: videoUrl),
          'custom_color_orange': AdaptyCustomAsset.color(color: Colors.orange),
          'custom_bright_gradient': AdaptyCustomAsset.gradient(
            gradient: AdaptyGradient.linear(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.0), Colors.green.withOpacity(0.5), Colors.yellow],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        },
        preloadProducts: loadProducts,
      );
      await view.present();
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
        ListActionTile(
          title: 'Present',
          showProgress: _loadingPaywall,
          onTap: () => _createAndPresentPaywallView(paywall, false),
        ),
        ListActionTile(
          title: 'Load Products and Present',
          showProgress: _loadingPaywallWithProducts,
          onTap: () => _createAndPresentPaywallView(paywall, true),
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
