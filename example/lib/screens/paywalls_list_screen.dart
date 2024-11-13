import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/cupertino.dart';

import '../widgets/list_components.dart';

typedef OnAdaptyErrorCallback = void Function(AdaptyError error);
typedef OnCustomErrorCallback = void Function(Object error);

class PaywallsList extends StatefulWidget {
  const PaywallsList({super.key, required this.adaptyErrorCallback, required this.customErrorCallback});

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
  final List<String> _paywallsIds = ['example_ab_test', 'london'];
  final Map<String, PaywallsListItem> _paywallsItems = {};

  @override
  void initState() {
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
    for (var id in _paywallsIds) {
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
      final view = await AdaptyUI().createPaywallView(
        paywall: paywall,
        loadTimeout: const Duration(seconds: 3),
        preloadProducts: loadProducts,
        customTags: {'USERNAME': 'John'},
        customTimers: {'TIMER_FLUTTER_60S': DateTime.now().add(const Duration(seconds: 60))},
        androidPersonalizedOffers: {'testPlan:testProduct': true},
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
        children: _paywallsIds.map((paywallId) {
          final item = _paywallsItems[paywallId];

          return ListSection(headerText: 'Paywall $paywallId', children: item?.paywall == null ? _buildErrorStatusItems() : _buildPaywallItems(item!.paywall!));
        }).toList(),
      ),
    );
  }
}
