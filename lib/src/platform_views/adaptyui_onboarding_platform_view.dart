import 'dart:io';

import 'package:adapty_flutter/src/models/adapty_onboarding.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert' show json;

import '../../adapty_flutter.dart';

class AdaptyUIOnboardingPlatformView extends StatefulWidget {
  final AdaptyOnboarding onboarding;

  final void Function(AdaptyUIOnboardingMeta)? onDidFinishLoading;
  final void Function(AdaptyError)? onDidFailWithError;
  final void Function(AdaptyUIOnboardingMeta, String)? onCloseAction; // meta, actionId
  final void Function(AdaptyUIOnboardingMeta, String)? onPaywallAction; // meta, actionId
  final void Function(AdaptyUIOnboardingMeta, String)? onCustomAction; // meta, actionId
  final void Function(AdaptyUIOnboardingMeta, String, AdaptyOnboardingsStateUpdatedParams)? onStateUpdatedAction; // meta, elementId, params
  final void Function(AdaptyUIOnboardingMeta, AdaptyOnboardingsAnalyticsEvent)? onAnalyticsEvent; // meta, event

  const AdaptyUIOnboardingPlatformView({
    super.key,
    required this.onboarding,
    this.onDidFinishLoading,
    this.onDidFailWithError,
    this.onCloseAction,
    this.onPaywallAction,
    this.onCustomAction,
    this.onStateUpdatedAction,
    this.onAnalyticsEvent,
  });

  @override
  State<AdaptyUIOnboardingPlatformView> createState() => _AdaptyUIOnboardingPlatformViewState();
}

class _AdaptyUIOnboardingPlatformViewState extends State<AdaptyUIOnboardingPlatformView> implements AdaptyUIOnboardingsEventsObserver {
  @override
  void dispose() {
    AdaptyUI().unregisterOnboardingEventsListener(widget.onboarding.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'adaptyui_onboarding_platform_view',
        onPlatformViewCreated: (id) {
          AdaptyUI().registerOnboardingEventsListener(this, 'flutter_native_${id}');
        },
        creationParams: json.encode(widget.onboarding.jsonValue),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'adaptyui_onboarding_platform_view',
        onPlatformViewCreated: (id) {
          AdaptyUI().registerOnboardingEventsListener(this, 'flutter_native_${id}');
        },
        creationParams: json.encode(widget.onboarding.jsonValue),
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  @override
  void onboardingViewDidFailWithError(
    AdaptyUIOnboardingView view,
    AdaptyError error,
  ) {
    widget.onDidFailWithError?.call(error);
  }

  @override
  void onboardingViewDidFinishLoading(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
  ) {
    widget.onDidFinishLoading?.call(meta);
  }

  @override
  void onboardingViewOnAnalyticsEvent(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    AdaptyOnboardingsAnalyticsEvent event,
  ) {
    widget.onAnalyticsEvent?.call(meta, event);
  }

  @override
  void onboardingViewOnCloseAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    widget.onCloseAction?.call(meta, actionId);
  }

  @override
  void onboardingViewOnCustomAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    widget.onCustomAction?.call(meta, actionId);
  }

  @override
  void onboardingViewOnPaywallAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String actionId,
  ) {
    widget.onPaywallAction?.call(meta, actionId);
  }

  @override
  void onboardingViewOnStateUpdatedAction(
    AdaptyUIOnboardingView view,
    AdaptyUIOnboardingMeta meta,
    String elementId,
    AdaptyOnboardingsStateUpdatedParams params,
  ) {
    widget.onStateUpdatedAction?.call(meta, elementId, params);
  }
}
