import 'package:adapty_flutter/src/models/adapty_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert' show json;

import '../../adapty_flutter.dart';

class AdaptyUIOnboardingPlatformView extends StatefulWidget {
  final AdaptyOnboarding onboarding;

  final void Function()? onCloseAction;

  const AdaptyUIOnboardingPlatformView({
    super.key,
    required this.onboarding,
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
      // if (event.viewId == widget.view.id) {
      //   widget.onCloseAction?.call();
      // }
    });
  }

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'adaptyui_onboarding_platform_view',
      onPlatformViewCreated: (id) {
        print('onPlatformViewCreated: $id');
      },
      layoutDirection: TextDirection.ltr,
      creationParams: json.encode(widget.onboarding.jsonValue),
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
