import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'onboardings_list_screen.dart';

class OnboardingsViewSharedState {
  static final OnboardingsViewSharedState _instance = OnboardingsViewSharedState._internal();
  static const String _prefsKey = 'stored_onboarding_ids';

  Function(List<String>)? onNeedsUpdateState;

  factory OnboardingsViewSharedState() {
    return _instance;
  }

  List<String> onboardingsIds = [];

  OnboardingsViewSharedState._internal() {
    _restoreOnboardingIds();
  }

  Future<void> _restoreOnboardingIds() async {
    final prefs = await SharedPreferences.getInstance();
    onboardingsIds = prefs.getStringList(_prefsKey) ?? [];
    if (!onboardingsIds.contains('testing')) {
      onboardingsIds.add('testing');
    }
    onNeedsUpdateState?.call(onboardingsIds);
  }

  Future<void> addOnboardingId(String id) async {
    if (!onboardingsIds.contains(id)) {
      onboardingsIds.insert(0, id);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, onboardingsIds);

    onNeedsUpdateState?.call(onboardingsIds);
  }
}

class OnboardingsView extends StatefulWidget {
  final OnAdaptyErrorCallback adaptyErrorCallback;
  final OnCustomErrorCallback customErrorCallback;

  OnboardingsView({super.key, required this.adaptyErrorCallback, required this.customErrorCallback});

  @override
  State<OnboardingsView> createState() => _OnboardingsViewState();
}

class _OnboardingsViewState extends State<OnboardingsView> {
  final sharedState = OnboardingsViewSharedState();

  Future<void> _addButtonPressed(BuildContext context) {
    return showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Add and save Onboarding'),
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
                    sharedState.addOnboardingId(_currentlyAddedPaywallId!);
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
      child: OnboardingsList(
        adaptyErrorCallback: widget.adaptyErrorCallback,
        customErrorCallback: widget.customErrorCallback,
      ),
    );
  }
}
