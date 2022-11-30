import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter_example/Helpers/value_to_string.dart';
import 'package:adapty_flutter_example/widgets/details_container.dart';
import 'package:flutter/material.dart';

class AccessLevelsScreen extends StatelessWidget {
  final Map<String, AdaptyAccessLevel> accessLevels;
  AccessLevelsScreen(this.accessLevels);

  static showAccessLevelsPage(BuildContext context, Map<String, AdaptyAccessLevel> accessLevels) {
    showModalBottomSheet(
      context: context,
      builder: (context) => AccessLevelsScreen(accessLevels),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessLevelKeys = accessLevels.keys.toList();

    return Scaffold(
      appBar: AppBar(title: Text('Access Levels')),
      body: ListView.builder(
        itemBuilder: (ctx, index) {
          final accessLevelInfo = accessLevels[accessLevelKeys[index]]!;
          final details = {
            'Id': valueToString(accessLevelInfo.id),
            'Is Active': valueToString(accessLevelInfo.isActive),
            'Vendor Product Id': valueToString(accessLevelInfo.vendorProductId),
            'Store': valueToString(accessLevelInfo.store),
            'Activated At': valueToString(accessLevelInfo.activatedAt),
            'Renewed At': valueToString(accessLevelInfo.renewedAt),
            'Expires At': valueToString(accessLevelInfo.expiresAt),
            'Is Lifetime': valueToString(accessLevelInfo.isLifetime),
            'Active Introductory Offer Type': valueToString(accessLevelInfo.activeIntroductoryOfferType),
            'Active Promotional Offer Type': valueToString(accessLevelInfo.activePromotionalOfferType),
            'Active Promotional Offer Id': valueToString(accessLevelInfo.activePromotionalOfferId),
            'Will Renew': valueToString(accessLevelInfo.willRenew),
            'Is In Grace Period': valueToString(accessLevelInfo.isInGracePeriod),
            'Unsubscribed At': valueToString(accessLevelInfo.unsubscribedAt),
            'Billing Issue Detected At': valueToString(accessLevelInfo.billingIssueDetectedAt),
            'Starts At': valueToString(accessLevelInfo.startsAt),
            'Cancellation Reason': valueToString(accessLevelInfo.cancellationReason),
            'Is Refund': valueToString(accessLevelInfo.isRefund),
          };
          return DetailsContainer(details: details);
        },
        itemCount: accessLevels.length,
      ),
    );
  }
}
