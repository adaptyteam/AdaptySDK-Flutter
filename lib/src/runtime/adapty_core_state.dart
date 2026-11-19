import 'dart:async';

import '../models/adapty_error.dart';
import '../models/adapty_installation_details.dart';
import '../models/adapty_profile.dart';
import '../models/adapty_promoted_product.dart';

/// The streams `Adapty()` hands to the app. They are broadcast: an event nobody listens to is dropped; a promoted
/// product no subscription received goes back to the SDK when the last subscription is cancelled.
final class AdaptyCoreState {
  final StreamController<AdaptyProfile> profileUpdates = StreamController.broadcast();
  late final StreamController<AdaptyPromotedProduct> promotedPurchases = StreamController.broadcast(
    onCancel: _completeUndeliveredPromoted,
  );
  final StreamController<AdaptyInstallationDetails> installationDetailsSuccess = StreamController.broadcast();
  final StreamController<AdaptyError> installationDetailsFail = StreamController.broadcast();

  /// Promoted products handed to the stream that no subscription has received yet, each with the SDK default that
  /// completes it. A product leaves on its first delivery; if the last subscription goes away first, the default runs
  /// instead, so the purchase is never lost.
  final Map<AdaptyPromotedProduct, void Function()> undeliveredPromoted = Map.identity();

  /// What the app subscribes to: the events of [promotedPurchases] at the same time, each marked delivered as it
  /// reaches a subscription.
  late final Stream<AdaptyPromotedProduct> promotedPurchasesStream = promotedPurchases.stream.map((product) {
    undeliveredPromoted.remove(product);
    return product;
  });

  void _completeUndeliveredPromoted() {
    if (promotedPurchases.isClosed) return;
    final undelivered = undeliveredPromoted.values.toList();
    undeliveredPromoted.clear();
    for (final complete in undelivered) {
      complete();
    }
  }

  /// Closes the streams; their listeners receive done.
  Future<void> dispose() => Future.wait([
    profileUpdates.close(),
    promotedPurchases.close(),
    installationDetailsSuccess.close(),
    installationDetailsFail.close(),
  ]);
}
