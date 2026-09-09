import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_constants.dart';
import '../app/app_controller.dart';
import 'adaptive.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isInitializing) {
          return Center(child: adaptiveActivityIndicator());
        }

        final profile = controller.profile;
        final accessLevel = profile?.accessLevels[AppConstants.accessLevelId];
        final profileId = profile?.profileId;
        final hasProfileId = profileId?.isNotEmpty == true;

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (controller.errorMessage != null)
              AppErrorBanner(
                message: controller.errorMessage!,
                onDismiss: controller.clearError,
              ),
            const SectionHeader('Customer User Id'),
            GroupedSection(
              children: [
                if (controller.userId == null)
                  InfoRow(
                    title: 'Log In',
                    trailing: controller.canUseSdk ? _chevron(context) : null,
                    onTap: controller.canUseSdk
                        ? () => _showLoginDialog(context)
                        : null,
                  )
                else ...[
                  InfoRow(title: 'User Id', subtitle: controller.userId),
                  InfoRow(
                    title: 'Logout',
                    onTap: controller.canUseSdk ? controller.logout : null,
                    trailing: Icon(
                      usesCupertino
                          ? CupertinoIcons.square_arrow_right
                          : Icons.logout,
                      color: usesCupertino
                          ? CupertinoColors.systemRed.resolveFrom(context)
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            const SectionHeader('Adapty Profile Id'),
            GroupedSection(
              children: [
                InfoRow(
                  title: 'Profile Id',
                  subtitle: hasProfileId ? profileId : 'Not Set',
                  trailing: hasProfileId ? _copyIcon(context) : null,
                  onTap: hasProfileId
                      ? () => Clipboard.setData(ClipboardData(text: profileId!))
                      : null,
                ),
              ],
            ),
            const SectionHeader('Profile'),
            GroupedSection(
              children: [
                _PremiumStatusRow(controller: controller),
                if (profile != null && accessLevel == null)
                  InfoRow(
                    title: 'Access Levels',
                    subtitle: '${profile.accessLevels.length}',
                  )
                else
                  ..._accessLevelRows(accessLevel),
                if (profile != null) ...[
                  InfoRow(
                    title: 'Subscriptions',
                    subtitle: '${profile.subscriptions.length}',
                  ),
                  InfoRow(
                    title: 'NonSubscriptions',
                    subtitle: '${profile.nonSubscriptions.length}',
                  ),
                ],
                InfoRow(
                  title: controller.isReloadingProfile
                      ? 'Updating...'
                      : 'Update',
                  onTap: controller.canUseSdk && !controller.isReloadingProfile
                      ? controller.reloadProfile
                      : null,
                  trailing: controller.isReloadingProfile
                      ? adaptiveActivityIndicator()
                      : _chevron(context),
                ),
                InfoRow(
                  title: controller.isRestoringPurchases
                      ? 'Restoring...'
                      : 'Restore Purchases',
                  onTap:
                      controller.canUseSdk && !controller.isRestoringPurchases
                      ? controller.restorePurchases
                      : null,
                  trailing: controller.isRestoringPurchases
                      ? adaptiveActivityIndicator()
                      : _chevron(context),
                ),
              ],
            ),
            const SectionHeader('Attribution'),
            GroupedSection(
              children: [
                InfoRow(
                  title: 'Applied Providers',
                  subtitle: profile == null
                      ? 'Not Set'
                      : profile.appliedExternalAttributionProviders.isEmpty
                      ? 'None'
                      : profile.appliedExternalAttributionProviders
                            .map((provider) => provider.rawValue)
                            .join(', '),
                ),
                InfoRow(
                  title: controller.isSendingAttribution
                      ? 'Sending...'
                      : 'Send External Attribution',
                  onTap:
                      controller.canUseSdk && !controller.isSendingAttribution
                      ? controller.sendExternalAttribution
                      : null,
                  trailing: controller.isSendingAttribution
                      ? adaptiveActivityIndicator()
                      : _chevron(context),
                ),
              ],
            ),
            const SectionHeader('Flow'),
            GroupedSection(
              children: [
                InfoRow(
                  title: 'Requested Locale',
                  subtitle: controller.requestedFlowLocale ?? 'Default (en)',
                  trailing: _chevron(context),
                  onTap: () => _showFlowLocaleDialog(context),
                ),
                InfoRow(
                  title: 'View Locale',
                  subtitle: controller.flowViewLocale ?? 'Not built yet',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  List<Widget> _accessLevelRows(AdaptyAccessLevel? level) {
    if (level == null) {
      return const [];
    }

    return [
      InfoRow(title: 'Is Lifetime', subtitle: '${level.isLifetime}'),
      InfoRow(
        title: 'Activated At',
        subtitle: _dateTimeFormattedString(level.activatedAt),
      ),
      if (level.renewedAt != null)
        InfoRow(
          title: 'Renewed At',
          subtitle: _dateTimeFormattedString(level.renewedAt!),
        ),
      if (level.expiresAt != null)
        InfoRow(
          title: 'Expires At',
          subtitle: _dateTimeFormattedString(level.expiresAt!),
        ),
      InfoRow(title: 'Will Renew', subtitle: '${level.willRenew}'),
      if (level.unsubscribedAt != null)
        InfoRow(
          title: 'Unsubscribed At',
          subtitle: _dateTimeFormattedString(level.unsubscribedAt!),
        ),
      if (level.billingIssueDetectedAt != null)
        InfoRow(
          title: 'Billing Issue At',
          subtitle: _dateTimeFormattedString(level.billingIssueDetectedAt!),
        ),
      if (level.cancellationReason != null)
        InfoRow(
          title: 'Cancellation Reason',
          subtitle: level.cancellationReason,
        ),
    ];
  }

  String _dateTimeFormattedString(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showFlowLocaleDialog(BuildContext context) async {
    final value = await showAdaptiveTextDialog(
      context,
      title: 'Flow Locale',
      placeholder: 'Locale (e.g. en, es, fr) or blank',
      initialValue: controller.requestedFlowLocale,
    );
    if (value == null) {
      return;
    }

    controller.setRequestedFlowLocale(value);
  }

  Future<void> _showLoginDialog(BuildContext context) async {
    final value = await showAdaptiveLoginDialog(context);
    if (value == null || value.trim().isEmpty) {
      return;
    }

    await controller.login(value);
  }

  Widget _chevron(BuildContext context) {
    if (usesCupertino) {
      return Icon(
        CupertinoIcons.chevron_forward,
        size: 18,
        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
      );
    }

    return Icon(
      Icons.chevron_right,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }

  Widget _copyIcon(BuildContext context) {
    if (usesCupertino) {
      return Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Icon(
          CupertinoIcons.doc_on_doc,
          size: 18,
          color: CupertinoColors.tertiaryLabel.resolveFrom(context),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(
        Icons.copy,
        size: 18,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PremiumStatusRow extends StatelessWidget {
  const _PremiumStatusRow({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final hasProfile = controller.profile != null;
    final isLoading =
        controller.isReloadingProfile ||
        (!hasProfile &&
            (controller.isUpdatingIdentity ||
                controller.isRestoringPurchases));
    final stateColor = controller.isPremiumUser
        ? (usesCupertino
              ? CupertinoColors.systemGreen.resolveFrom(context)
              : Colors.green)
        : (usesCupertino
              ? CupertinoColors.systemRed.resolveFrom(context)
              : Theme.of(context).colorScheme.error);

    return InfoRow(
      title: 'Premium',
      subtitle: isLoading
          ? 'Loading'
          : (hasProfile
                ? (controller.isPremiumUser ? 'Active' : 'Inactive')
                : 'Unavailable'),
      trailing: !hasProfile && !isLoading
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 8),
              child: isLoading
                  ? adaptiveActivityIndicator()
                  : Icon(
                      controller.isPremiumUser
                          ? (usesCupertino
                                ? CupertinoIcons.check_mark_circled_solid
                                : Icons.check_circle)
                          : (usesCupertino
                                ? CupertinoIcons.xmark_circle_fill
                                : Icons.cancel),
                      color: stateColor,
                      size: 20,
                    ),
            ),
    );
  }
}

Future<String?> showAdaptiveLoginDialog(BuildContext context) {
  return showAdaptiveTextDialog(
    context,
    title: 'Log In',
    placeholder: 'Enter user id',
  );
}

/// Shows a platform-styled dialog with a single text field and returns the
/// entered text, or `null` when cancelled.
Future<String?> showAdaptiveTextDialog(
  BuildContext context, {
  required String title,
  required String placeholder,
  String? initialValue,
}) {
  if (usesCupertino) {
    return showCupertinoDialog<String>(
      context: context,
      builder: (context) => _CupertinoTextDialog(
        title: title,
        placeholder: placeholder,
        initialValue: initialValue,
      ),
    );
  }

  return showDialog<String>(
    context: context,
    builder: (context) => _MaterialTextDialog(
      title: title,
      placeholder: placeholder,
      initialValue: initialValue,
    ),
  );
}

class _CupertinoTextDialog extends StatefulWidget {
  const _CupertinoTextDialog({
    required this.title,
    required this.placeholder,
    this.initialValue,
  });

  final String title;
  final String placeholder;
  final String? initialValue;

  @override
  State<_CupertinoTextDialog> createState() => _CupertinoTextDialogState();
}

class _CupertinoTextDialogState extends State<_CupertinoTextDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: _controller,
          placeholder: widget.placeholder,
          autofocus: true,
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _MaterialTextDialog extends StatefulWidget {
  const _MaterialTextDialog({
    required this.title,
    required this.placeholder,
    this.initialValue,
  });

  final String title;
  final String placeholder;
  final String? initialValue;

  @override
  State<_MaterialTextDialog> createState() => _MaterialTextDialogState();
}

class _MaterialTextDialogState extends State<_MaterialTextDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        decoration: InputDecoration(labelText: widget.placeholder),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
