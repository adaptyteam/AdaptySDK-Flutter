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
                  title: controller.profile?.profileId.isNotEmpty == true
                      ? controller.profile!.profileId
                      : 'Not Set',
                  subtitle: controller.profile?.profileId.isNotEmpty == true
                      ? 'Tap to Copy'
                      : null,
                  onTap: controller.profile?.profileId.isNotEmpty == true
                      ? () => Clipboard.setData(
                          ClipboardData(text: controller.profile!.profileId),
                        )
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
                    title: 'Access Levels: ${profile.accessLevels.length}',
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
}

class _PremiumStatusRow extends StatelessWidget {
  const _PremiumStatusRow({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final isLoading =
        controller.profile == null || controller.isReloadingProfile;
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
          : (controller.isPremiumUser ? 'Active' : 'Inactive'),
      trailing: Padding(
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
  if (usesCupertino) {
    return _showCupertinoLoginDialog(context);
  }

  return _showMaterialLoginDialog(context);
}

Future<String?> _showCupertinoLoginDialog(BuildContext context) async {
  return showCupertinoDialog<String>(
    context: context,
    builder: (context) => const _CupertinoLoginDialog(),
  );
}

Future<String?> _showMaterialLoginDialog(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (context) => const _MaterialLoginDialog(),
  );
}

class _CupertinoLoginDialog extends StatefulWidget {
  const _CupertinoLoginDialog();

  @override
  State<_CupertinoLoginDialog> createState() => _CupertinoLoginDialogState();
}

class _CupertinoLoginDialogState extends State<_CupertinoLoginDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoAlertDialog(
      title: const Text('Log In'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: CupertinoTextField(
          controller: _controller,
          placeholder: 'Enter user id',
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

class _MaterialLoginDialog extends StatefulWidget {
  const _MaterialLoginDialog();

  @override
  State<_MaterialLoginDialog> createState() => _MaterialLoginDialogState();
}

class _MaterialLoginDialogState extends State<_MaterialLoginDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Log In'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(labelText: 'Enter user id'),
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
