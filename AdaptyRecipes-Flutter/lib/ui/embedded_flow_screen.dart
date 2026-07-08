import 'dart:async';

import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import 'adaptive.dart';

class EmbeddedFlowScreen extends StatefulWidget {
  const EmbeddedFlowScreen({super.key, required this.title, required this.controller});

  final String title;
  final AppController controller;

  @override
  State<EmbeddedFlowScreen> createState() => _EmbeddedFlowScreenState();
}

class _EmbeddedFlowScreenState extends State<EmbeddedFlowScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.controller.flow == null && !widget.controller.isLoadingFlow) {
      widget.controller.loadFlow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final flow = widget.controller.flow;

        if (widget.controller.errorMessage != null && flow == null) {
          return ListView(
            padding: const EdgeInsets.only(top: 16),
            children: [
              AppErrorBanner(message: widget.controller.errorMessage!, onDismiss: widget.controller.clearError),
              Padding(
                padding: const EdgeInsets.all(16),
                child: AdaptiveActionButton(label: 'Retry', onPressed: widget.controller.loadFlow),
              ),
            ],
          );
        }

        if (flow == null) {
          return Center(child: adaptiveActivityIndicator());
        }

        return AdaptyUIFlowPlatformView(
          flow: flow,
          onDidPerformAction: (view, action) {
            switch (action) {
              case const CloseAction():
              case const AndroidSystemBackAction():
                Navigator.of(context).maybePop();
                break;
              case OpenUrlAction(:final url, :final openIn):
                unawaited(AdaptyUI().openUrl(url, openIn: openIn));
                break;
              default:
                break;
            }
          },
          onDidFinishPurchase: (view, product, result) {
            if (result is AdaptyPurchaseResultSuccess) {
              widget.controller.applyProfileFromFlow(result.profile);
            }
          },
          onDidFailPurchase: (view, product, error) => widget.controller.reportError(error),
          onDidFinishRestore: (view, profile) => widget.controller.applyProfileFromFlow(profile),
          onDidFailRestore: (view, error) => widget.controller.reportError(error),
          onDidReceiveError: (view, error) {
            widget.controller.reportError(error);
            Navigator.of(context).maybePop();
          },
          onDidFailLoadingProducts: (view, error) => widget.controller.reportError(error),
        );
      },
    );

    if (usesCupertino) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Text(widget.title)),
        child: SafeArea(child: content),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(child: content),
    );
  }
}
