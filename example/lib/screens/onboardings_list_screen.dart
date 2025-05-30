import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/cupertino.dart';

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

  Future<void> _showOnboardingPlatformView(AdaptyOnboarding onboarding) async {
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
        onTap: () => _showOnboardingPlatformView(onboarding),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: (_onboardingsIds ?? []).map((onboardingId) {
          final item = _onboardingsItems[onboardingId];

          return ListSection(
            headerText: 'Onboarding $onboardingId',
            children: item?.onboarding == null ? _buildErrorStatusItems() : _buildOnboardingItems(item!.onboarding!),
          );
        }).toList(),
      ),
    );
  }
}
