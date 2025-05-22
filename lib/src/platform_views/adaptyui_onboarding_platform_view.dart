import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../adapty_flutter.dart';

class AdaptyUIOnboardingPlatformView extends StatefulWidget {
  final AdaptyUIOnboardingView view;

  final void Function()? onCloseAction;

  const AdaptyUIOnboardingPlatformView({
    super.key,
    required this.view,
    this.onCloseAction,
  });

  @override
  State<AdaptyUIOnboardingPlatformView> createState() => _AdaptyUIOnboardingPlatformViewState();
}

class _AdaptyUIOnboardingPlatformViewState extends State<AdaptyUIOnboardingPlatformView> {
  @override
  void initState() {
    super.initState();

    AdaptyUI().onboardingEventsStream.listen((event) {
      if (event.viewId == widget.view.id) {
        widget.onCloseAction?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const String viewType = 'adaptyui_onboarding_platform_view';

    final Map<String, dynamic> creationParams = <String, dynamic>{
      'id': widget.view.id,
    };

    return UiKitView(
      viewType: viewType,
      onPlatformViewCreated: (id) {
        print('onPlatformViewCreated: $id');
      },
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
