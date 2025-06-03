import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:toastification/toastification.dart' show ToastificationStyle, ToastificationType, toastification;

import '../widgets/list_components.dart';
import 'onboardings_view.dart';

typedef OnAdaptyErrorCallback = void Function(AdaptyError error);
typedef OnCustomErrorCallback = void Function(Object error);

class OnboardingsList extends StatefulWidget {
  const OnboardingsList({
    super.key,
    required this.adaptyErrorCallback,
    required this.customErrorCallback,
  });

  final OnAdaptyErrorCallback adaptyErrorCallback;
  final OnCustomErrorCallback customErrorCallback;

  @override
  State<OnboardingsList> createState() => _OnboardingsListState();
}

class OnboardingsListItem {
  String id;
  AdaptyOnboarding? onboarding;
  AdaptyError? error;

  OnboardingsListItem({
    required this.id,
    this.onboarding,
    this.error,
  });
}

class _OnboardingsListState extends State<OnboardingsList> {
  List<String>? _onboardingsIds;

  final Map<String, OnboardingsListItem> _onboardingsItems = {};

  bool _showToastEvents = true;

  @override
  void initState() {
    OnboardingsViewSharedState().onNeedsUpdateState = (ids) {
      setState(() {
        _onboardingsIds = ids;
        _loadOnboardings();
      });
    };
    _loadOnboardings();

    super.initState();
  }

  Future<void> _loadOnboardingData(String id) async {
    try {
      _onboardingsItems[id] = OnboardingsListItem(
        id: id,
        onboarding: await Adapty().getOnboarding(placementId: id),
      );

      setState(() {});
    } on AdaptyError catch (e) {
      _onboardingsItems[id] = OnboardingsListItem(id: id, error: e);

      widget.adaptyErrorCallback(e);
    } catch (e) {
      widget.customErrorCallback(e);
    }
  }

  void _loadOnboardings() {
    for (var id in _onboardingsIds ?? []) {
      _onboardingsItems[id] = OnboardingsListItem(id: id);
      setState(() {});
      _loadOnboardingData(id);
    }
  }

  bool _loadingOnboarding = false;

  Future<void> _createAndPresentOnboardingView(AdaptyOnboarding onboarding) async {
    setState(() {
      _loadingOnboarding = true;
    });

    try {
      final view = await AdaptyUI().createOnboardingView(
        onboarding: onboarding,
      );
      await view.present();
    } on AdaptyError catch (e) {
      widget.adaptyErrorCallback(e);
    } catch (e) {
      widget.customErrorCallback(e);
    } finally {
      setState(() {
        _loadingOnboarding = false;
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

  Future<void> _showOnboardingPlatformView(AdaptyOnboarding onboarding, bool showToastEvents) async {
    try {
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (BuildContext context) => CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text('Onboarding ${onboarding.placement.id}'),
            ),
            child: SafeArea(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: CupertinoColors.systemBackground,
                child: AdaptyUIOnboardingPlatformView(
                  onboarding: onboarding,
                  onDidFinishLoading: (meta) {
                    print('#Example# Platform View onDidFinishLoading: $meta');
                    if (showToastEvents) {
                      _showToast('Action: onDidFinishLoading', 'Meta: $meta');
                    }
                  },
                  onDidFailWithError: (error) {
                    print('#Example# Platform View onDidFailWithError: $error');
                    if (showToastEvents) {
                      _showToast('Action: onDidFailWithError', 'Error: $error');
                    }
                  },
                  onCloseAction: (meta, actionId) {
                    print('#Example# Platform View onCloseAction: $meta, $actionId');
                    if (showToastEvents) {
                      _showToast('Action: onCloseAction', 'ActionId: $actionId');
                    }
                    Navigator.of(context).pop();
                  },
                  onPaywallAction: (meta, actionId) {
                    print('#Example# Platform View onPaywallAction: $meta, $actionId');
                    if (showToastEvents) {
                      _showToast('Action: onPaywallAction', 'ActionId: $actionId');
                    }
                  },
                  onCustomAction: (meta, actionId) {
                    print('#Example# Platform View onCustomAction: $meta, $actionId');
                    if (showToastEvents) {
                      _showToast('Action: onCustomAction', 'ActionId: $actionId');
                    }
                  },
                  onStateUpdatedAction: (meta, elementId, params) {
                    print('#Example# Platform View onStateUpdatedAction: $meta, $elementId, $params');
                    if (showToastEvents) {
                      _showToast('Action: onStateUpdatedAction', 'ElementId: $elementId, Params: $params');
                    }
                  },
                  onAnalyticsEvent: (meta, event) {
                    print('#Example# Platform View onAnalyticsEvent: $meta, $event');
                    if (showToastEvents) {
                      _showToast('Action: onAnalyticsEvent', 'Event: $event');
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
        _loadingOnboarding = false;
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

  List<Widget> _buildOnboardingItems(AdaptyOnboarding onboarding) {
    return [
      const ListTextTile(
        title: 'Status',
        subtitle: 'OK',
        subtitleColor: CupertinoColors.systemGreen,
      ),
      ListTextTile(
        title: 'Id',
        subtitle: onboarding.id,
      ),
      ListTextTile(
        title: 'Name',
        subtitle: onboarding.name,
      ),
      ListTextTile(
        title: 'Variation Id',
        subtitle: onboarding.variationId,
      ),
      ListActionTile(
        title: 'Present',
        showProgress: _loadingOnboarding,
        onTap: () => _createAndPresentOnboardingView(onboarding),
      ),
      ListActionTile(
        title: 'Present Platform View',
        showProgress: _loadingOnboarding,
        onTap: () => _showOnboardingPlatformView(onboarding, _showToastEvents),
      ),
    ];
  }

  Widget _buildSettingsSection() {
    return ListSection(
      headerText: 'Settings',
      children: [
        ListToggleTile(
          title: 'Show Toast Events',
          value: _showToastEvents,
          onChanged: (value) {
            setState(() {
              _showToastEvents = value;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: [
          _buildSettingsSection(),
          ...(_onboardingsIds ?? []).map((onboardingId) {
            final item = _onboardingsItems[onboardingId];

            return ListSection(
              headerText: 'Onboarding $onboardingId',
              children: item?.onboarding == null ? _buildErrorStatusItems() : _buildOnboardingItems(item!.onboarding!),
            );
          }).toList(),
        ],
      ),
    );
  }
}
