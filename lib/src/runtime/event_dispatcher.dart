import 'dart:convert' show json;

import '../adapty.dart';
import '../adapty_logger.dart';
import '../constants/argument.dart';
import '../constants/method.dart';
import '../models/adapty_error.dart';
import '../models/adapty_installation_details.dart';
import '../models/adapty_log_level.dart';
import '../models/adapty_paywall_product.dart';
import '../models/adapty_profile.dart';
import '../models/adapty_promoted_product.dart';
import '../models/adapty_purchase_result.dart';
import '../models/adaptyui/adaptyui_action.dart';
import '../models/adaptyui/adaptyui_flow_view.dart';
import '../models/adaptyui/adaptyui_onboarding_meta.dart';
import '../models/adaptyui/adaptyui_onboarding_state_updated_params.dart';
import '../models/adaptyui/adaptyui_onboarding_view.dart';
import '../models/adaptyui/adaptyui_onboardings_analytics_event.dart';
import '../models/adaptyui/adaptyui_permission.dart';
import '../models/adaptyui/adaptyui_permission_result.dart';
import 'adapty_internal_error_sink.dart';
import 'adapty_runtime.dart';
import 'bridge.dart';

/// Reads the events of the native side and hands each one to the streams, observers, handler and resolver of the
/// runtime it is given; an answer the event asks for goes back to the native side of that runtime.
///
/// The caller runs [dispatch] bound to that runtime: the log lines, the default handling it falls back to (through the
/// facades) and the default implementations of the observers read the current runtime.
final class AdaptyEventDispatcher {
  const AdaptyEventDispatcher();

  Future<dynamic> dispatch(AdaptyRuntime rt, String eventName, String jsonPayload) {
    final arguments = json.decode(jsonPayload) as Map<String, dynamic>;

    AdaptyLogger.write(AdaptyLogLevel.verbose, 'handleIncomingCall $eventName Args: $arguments');

    AdaptyUIFlowView decodeView() {
      return AdaptyUIFlowViewJSONBuilder.fromJsonValue(arguments[Argument.view]);
    }

    AdaptyUIOnboardingView decodeOnboardingView() {
      return AdaptyUIOnboardingViewJSONBuilder.fromJsonValue(arguments[Argument.view]);
    }

    AdaptyPaywallProduct decodeProduct() {
      return AdaptyPaywallProductJSONBuilder.fromJsonValue(arguments[Argument.product]);
    }

    AdaptyPaywallProduct? decodeProductIfPresent() {
      return arguments[Argument.product] != null
          ? AdaptyPaywallProductJSONBuilder.fromJsonValue(arguments[Argument.product])
          : null;
    }

    AdaptyPromotedProduct decodePromotedProduct() {
      return AdaptyPromotedProductJSONBuilder.fromJsonValue(arguments[Argument.product]);
    }

    AdaptyProfile decodeProfile() {
      return AdaptyProfileJSONBuilder.fromJsonValue(arguments[Argument.profile]);
    }

    AdaptyPurchaseResult decodePurchaseResult() {
      return AdaptyPurchaseResultJSONBuilder.fromJsonValue(arguments[Argument.purchasedResult]);
    }

    AdaptyError decodeError() {
      return AdaptyErrorJSONBuilder.fromJsonValue(arguments[Argument.error]);
    }

    AdaptyError? decodeErrorIfPresent() {
      return arguments[Argument.error] != null ? AdaptyErrorJSONBuilder.fromJsonValue(arguments[Argument.error]) : null;
    }

    AdaptyUIOnboardingMeta decodeOnboardingMeta() {
      return AdaptyUIOnboardingMetaJSONBuilder.fromJsonValue(arguments[Argument.meta]);
    }

    switch (NativeEvent.fromWireName(eventName)) {
      case NativeEvent.didLoadLatestProfile:
        rt.core.profileUpdates.add(decodeProfile());
        return Future.value(null);
      case NativeEvent.didReceivePromotedPurchase:
        _handlePromotedPurchase(rt, decodePromotedProduct());
        return Future.value(null);
      case NativeEvent.onInstallationDetailsSuccess:
        final details = AdaptyInstallationDetailsJSONBuilder.fromJsonValue(arguments[Argument.details]);
        rt.core.installationDetailsSuccess.add(details);
        return Future.value(null);
      case NativeEvent.onInstallationDetailsFail:
        rt.core.installationDetailsFail.add(decodeError());
        return Future.value(null);
      case NativeEvent.flowViewDidAppear:
        rt.ui.eventsProxy.flowViewDidAppear(decodeView());
        return Future.value(null);
      case NativeEvent.flowViewDidDisappear:
        rt.ui.eventsProxy.flowViewDidDisappear(decodeView());
        return Future.value(null);
      case NativeEvent.flowViewDidPerformAction:
        final action = AdaptyUIActionJSONBuilder.fromJsonValue(arguments[Argument.action]);
        rt.ui.eventsProxy.flowViewDidPerformAction(decodeView(), action);
        return Future.value(null);
      case NativeEvent.flowViewDidSelectProduct:
        final productId = arguments[Argument.productId] as String;
        rt.ui.eventsProxy.flowViewDidSelectProduct(decodeView(), productId);
        return Future.value(null);
      case NativeEvent.flowViewDidStartPurchase:
        rt.ui.eventsProxy.flowViewDidStartPurchase(decodeView(), decodeProduct());
        return Future.value(null);
      case NativeEvent.flowViewDidFinishPurchase:
        rt.ui.eventsProxy.flowViewDidFinishPurchase(decodeView(), decodeProduct(), decodePurchaseResult());
        return Future.value(null);
      case NativeEvent.flowViewDidFailPurchase:
        rt.ui.eventsProxy.flowViewDidFailPurchase(decodeView(), decodeProduct(), decodeError());
        return Future.value(null);
      case NativeEvent.flowViewDidFinishRestore:
        rt.ui.eventsProxy.flowViewDidFinishRestore(decodeView(), decodeProfile());
        return Future.value(null);
      case NativeEvent.flowViewDidStartRestore:
        rt.ui.eventsProxy.flowViewDidStartRestore(decodeView());
        return Future.value(null);
      case NativeEvent.flowViewDidFailRestore:
        rt.ui.eventsProxy.flowViewDidFailRestore(decodeView(), decodeError());
        return Future.value(null);
      case NativeEvent.flowViewDidReceiveError:
        rt.ui.eventsProxy.flowViewDidReceiveError(decodeView(), decodeError());
        return Future.value(null);
      case NativeEvent.flowViewDidFailLoadingProducts:
        rt.ui.eventsProxy.flowViewDidFailLoadingProducts(decodeView(), decodeError());
        return Future.value(null);
      case NativeEvent.flowViewDidFinishWebPaymentNavigation:
        rt.ui.eventsProxy.flowViewDidFinishWebPaymentNavigation(
          decodeView(),
          decodeProductIfPresent(),
          decodeErrorIfPresent(),
        );
        return Future.value(null);
      case NativeEvent.flowViewDidAskPermission:
        // The native side waits for exactly one answer per event_id and never cleans the request up itself
        // (iOS flushes only when the plugin registers; Android never). So we always answer: the handler's
        // result, or denied when there is no handler, the handler throws, or the event can't be decoded.
        // Without a readable event_id there is nothing to answer.
        final eventId = arguments[Argument.eventId] as String;
        if (eventId.isEmpty) throw ArgumentError.value(eventId, Argument.eventId, 'must not be empty');
        Future<AdaptyUIPermissionResult> Function()? askHandler;
        try {
          final view = decodeView();
          final permission = AdaptyUIPermission(arguments[Argument.permission] as String);
          final customArgs = (arguments[Argument.customArgs] as Map?)?.map(
            (key, value) => MapEntry(key as String, value as String),
          );
          final handler = rt.ui.systemRequestsHandler;
          if (handler != null) {
            askHandler = () => handler.handlePermission(view, permission, customArgs);
          } else {
            AdaptyLogger.write(
              AdaptyLogLevel.warn,
              "No AdaptyUISystemRequestsHandler set; answering denied for permission '${permission.value}'. "
              'Set one with AdaptyUI().setSystemRequestsHandler().',
            );
          }
        } catch (e, s) {
          rt.diagnostics.errorSink.report(
            AdaptyInternalErrorRecord(
              AdaptyInternalErrorKind.eventDecodeFailed,
              e,
              stack: s,
              context: eventName,
              correlationId: eventId,
            ),
          );
        }
        return Future(() async {
          var result = const AdaptyUIPermissionResult.denied();
          final ask = askHandler;
          if (ask != null) {
            try {
              result = await ask();
            } catch (e, s) {
              rt.diagnostics.errorSink.report(
                AdaptyInternalErrorRecord(
                  AdaptyInternalErrorKind.handlerThrew,
                  e,
                  stack: s,
                  context: eventName,
                  correlationId: eventId,
                ),
              );
            }
          }
          try {
            await adaptyInvoke<void>(rt, NativeEventResponse.flowViewDidAnswerPermission, (_) => null, {
              Argument.eventId: eventId,
              ...result.jsonValue,
            });
          } catch (e, s) {
            rt.diagnostics.errorSink.report(
              AdaptyInternalErrorRecord(
                AdaptyInternalErrorKind.replyFailed,
                e,
                stack: s,
                context: NativeEventResponse.flowViewDidAnswerPermission.wireName,
                correlationId: eventId,
              ),
            );
          }
        });
      case NativeEvent.flowViewDidRequestAppReview:
        final view = decodeView();
        final handler = rt.ui.systemRequestsHandler;
        return Future(() async {
          // No registered handler → trigger the native review prompt by default.
          if (handler != null) {
            try {
              await handler.handleAppReviewRequest(view);
            } catch (e, s) {
              throw IncomingEventFailure(AdaptyInternalErrorKind.handlerThrew, e, s);
            }
          } else {
            try {
              await AdaptyUI().requestAppReview();
            } catch (e, s) {
              throw IncomingEventFailure(
                AdaptyInternalErrorKind.replyFailed,
                e,
                s,
                label: NativeMethod.requestAppReview.wireName,
              );
            }
          }
        });
      case NativeEvent.flowViewDidReceiveAnalyticEvent:
        final name = arguments[Argument.name] as String;
        final params = (arguments[Argument.params] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        rt.ui.eventsProxy.flowViewDidReceiveAnalyticEvent(decodeView(), name, params);
        return Future.value(null);
      case NativeEvent.flowViewObserverDidInitiatePurchase:
        final eventId = arguments[Argument.eventId] as String;
        final AdaptyUIFlowView view;
        final AdaptyPaywallProduct product;
        try {
          view = decodeView();
          product = decodeProduct();
        } catch (e, s) {
          _reportObserverEventDecodeFailed(rt, eventName, eventId, e, s);
          return Future.value(null);
        }
        final resolver = rt.ui.observerModeResolver;
        if (resolver == null) {
          _warnNoObserverModeResolver('purchase');
          return Future.value(null);
        }
        try {
          resolver.observerModeDidInitiatePurchase(
            view,
            product,
            () => _answerObserverMode(rt, NativeEventResponse.observerPurchaseDidStart, eventId),
            () => _answerObserverMode(rt, NativeEventResponse.observerPurchaseDidFinish, eventId),
          );
        } catch (e, s) {
          throw IncomingEventFailure(AdaptyInternalErrorKind.handlerThrew, e, s, correlationId: eventId);
        }
        return Future.value(null);
      case NativeEvent.flowViewObserverDidInitiateRestore:
        final eventId = arguments[Argument.eventId] as String;
        final AdaptyUIFlowView view;
        try {
          view = decodeView();
        } catch (e, s) {
          _reportObserverEventDecodeFailed(rt, eventName, eventId, e, s);
          return Future.value(null);
        }
        final resolver = rt.ui.observerModeResolver;
        if (resolver == null) {
          _warnNoObserverModeResolver('restore');
          return Future.value(null);
        }
        try {
          resolver.observerModeDidInitiateRestore(
            view,
            () => _answerObserverMode(rt, NativeEventResponse.observerRestoreDidStart, eventId),
            () => _answerObserverMode(rt, NativeEventResponse.observerRestoreDidFinish, eventId),
          );
        } catch (e, s) {
          throw IncomingEventFailure(AdaptyInternalErrorKind.handlerThrew, e, s, correlationId: eventId);
        }
        return Future.value(null);
      case NativeEvent.onboardingDidFinishLoading:
        rt.ui.eventsProxy.onboardingViewDidFinishLoading(decodeOnboardingView(), decodeOnboardingMeta());
        return Future.value(null);
      case NativeEvent.onboardingDidFailWithError:
        rt.ui.eventsProxy.onboardingViewDidFailWithError(decodeOnboardingView(), decodeError());
        return Future.value(null);
      case NativeEvent.onboardingOnAnalyticsActionEvent:
        rt.ui.eventsProxy.onboardingViewOnAnalyticsEvent(
          decodeOnboardingView(),
          decodeOnboardingMeta(),
          AdaptyOnboardingsAnalyticsEventJSONBuilder.fromJsonValue(arguments[Argument.event]),
        );
        return Future.value(null);
      case NativeEvent.onboardingOnCloseActionEvent:
        rt.ui.eventsProxy.onboardingViewOnCloseAction(
          decodeOnboardingView(),
          decodeOnboardingMeta(),
          arguments[Argument.actionId] as String,
        );
        return Future.value(null);
      case NativeEvent.onboardingOnCustomActionEvent:
        rt.ui.eventsProxy.onboardingViewOnCustomAction(
          decodeOnboardingView(),
          decodeOnboardingMeta(),
          arguments[Argument.actionId] as String,
        );
        return Future.value(null);
      case NativeEvent.onboardingOnPaywallActionEvent:
        rt.ui.eventsProxy.onboardingViewOnPaywallAction(
          decodeOnboardingView(),
          decodeOnboardingMeta(),
          arguments[Argument.actionId] as String,
        );
        return Future.value(null);
      case NativeEvent.onboardingOnStateUpdatedActionEvent:
        final action = arguments[Argument.action] as Map<String, dynamic>;

        rt.ui.eventsProxy.onboardingViewOnStateUpdatedAction(
          decodeOnboardingView(),
          decodeOnboardingMeta(),
          action[Argument.elementId] as String,
          AdaptyOnboardingsStateUpdatedParamsJSONBuilder.fromJsonValue(action),
        );
        return Future.value(null);
      case null:
        rt.diagnostics.errorSink.report(
          AdaptyInternalErrorRecord(AdaptyInternalErrorKind.unknownEvent, eventName, context: eventName),
        );
        return Future.value(null);
    }
  }

  /// Hands a promoted product to the app, or completes the purchase when nothing is listening.
  ///
  /// An App Store promoted purchase that nobody completes does nothing: the store hands the
  /// product to the app and waits. [Adapty.didReceivePromotedPurchaseStream] is a broadcast
  /// stream, so an event emitted with no subscriber is dropped and the purchase is lost with it.
  ///
  /// A product handed to the stream waits for a subscription to receive it; if the last subscription is cancelled
  /// before any does, the SDK completes the purchase then, in the runtime of the event.
  void _handlePromotedPurchase(AdaptyRuntime rt, AdaptyPromotedProduct product) {
    if (rt.core.promotedPurchases.hasListener) {
      rt.core.undeliveredPromoted[product] = () => rt.runBound(() => _completeByDefault(rt, product));
      rt.core.promotedPurchases.add(product);
      return;
    }

    _completeByDefault(rt, product);
  }

  void _completeByDefault(AdaptyRuntime rt, AdaptyPromotedProduct product) {
    rt.diagnostics.background.track(
      'promoted_purchase.complete',
      _completePromotedPurchase(product),
      onError: AdaptyInternalErrorKind.promotedAutoCompleteFailed,
    );
  }

  Future<void> _completePromotedPurchase(AdaptyPromotedProduct product) async {
    await Adapty().makePromotedPurchase(product: product);
  }

  /// An Observer mode event that can't be read reaches no resolver, so nothing would ever answer it; the record keeps
  /// its `event_id`.
  void _reportObserverEventDecodeFailed(
    AdaptyRuntime rt,
    String eventName,
    String eventId,
    Object error,
    StackTrace stack,
  ) {
    rt.diagnostics.errorSink.report(
      AdaptyInternalErrorRecord(
        AdaptyInternalErrorKind.eventDecodeFailed,
        error,
        stack: stack,
        context: eventName,
        correlationId: eventId,
      ),
    );
  }

  /// Sends [response] for the request [eventId] to the native side of [rt] and returns the call: the callback the
  /// resolver gets is a `void Function()`, but an app that waits for what it returns gets the answer or its error. A
  /// failure is also reported to the error sink of [rt], so it never surfaces as an uncaught error when nobody waits.
  Future<void> _answerObserverMode(AdaptyRuntime rt, NativeEventResponse response, String eventId) {
    final call = adaptyInvoke<void>(rt, response, (_) => null, {Argument.eventId: eventId});
    rt.diagnostics.background.track(
      response.wireName,
      call,
      onError: AdaptyInternalErrorKind.replyFailed,
      correlationId: eventId,
    );
    return call;
  }

  /// Only the resolver can start and finish a purchase or a restore a flow makes in Observer mode. Without one the
  /// flow waits forever, and this warning is the only trace of it; the native side gets nothing, as before.
  void _warnNoObserverModeResolver(String action) {
    AdaptyLogger.write(
      AdaptyLogLevel.warn,
      "Observer mode is on but no AdaptyUIObserverModeResolver is set; the flow's $action will not complete. "
      'Set one with AdaptyUI().setObserverModeResolver().',
    );
  }
}
