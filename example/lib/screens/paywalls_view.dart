import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'paywalls_list_screen.dart';

class PaywallsViewSharedState {
  static final PaywallsViewSharedState _instance = PaywallsViewSharedState._internal();
  static const String _prefsKey = 'stored_paywall_ids';

  Function(List<String>)? onNeedsUpdateState;

  factory PaywallsViewSharedState() {
    return _instance;
  }

  List<String> paywallsIds = [];

  PaywallsViewSharedState._internal() {
    _restorePaywallIds();
  }

  Future<void> _restorePaywallIds() async {
    final prefs = await SharedPreferences.getInstance();
    paywallsIds = prefs.getStringList(_prefsKey) ?? [];
    if (!paywallsIds.contains('example_ab_test')) {
      paywallsIds.add('example_ab_test');
    }
    onNeedsUpdateState?.call(paywallsIds);
  }

  Future<void> addPaywallId(String id) async {
    if (!paywallsIds.contains(id)) {
      paywallsIds.insert(0, id);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, paywallsIds);

    onNeedsUpdateState?.call(paywallsIds);
  }
}

class PaywallsView extends StatefulWidget {
  final OnAdaptyErrorCallback adaptyErrorCallback;
  final OnCustomErrorCallback customErrorCallback;

  PaywallsView({super.key, required this.adaptyErrorCallback, required this.customErrorCallback});

  @override
  State<PaywallsView> createState() => _PaywallsViewState();
}

class _PaywallsViewState extends State<PaywallsView> {
  final sharedState = PaywallsViewSharedState();

  Future<void> _addButtonPressed(BuildContext context) {
    return showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Add and save Paywall'),
        content: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: CupertinoTextField(
                placeholder: 'Enter Placement Id',
                onChanged: (value) {
                  _currentlyAddedPaywallId = value;
                },
              ),
            ),
          ],
        ),
        actions: [
          CupertinoButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(ctx).pop();

                if (_currentlyAddedPaywallId != null) {
                  setState(() {
                    sharedState.addPaywallId(_currentlyAddedPaywallId!);
                  });
                }
              }),
        ],
      ),
    );
  }

  String? _currentlyAddedPaywallId;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('AdaptyUI'),
        trailing: CupertinoButton(
          onPressed: () => _addButtonPressed(context),
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: PaywallsList(
        adaptyErrorCallback: widget.adaptyErrorCallback,
        customErrorCallback: widget.customErrorCallback,
      ),
    );
  }
}
