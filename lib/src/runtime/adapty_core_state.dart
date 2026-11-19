import 'dart:async';

import '../models/adapty_error.dart';
import '../models/adapty_installation_details.dart';
import '../models/adapty_profile.dart';
import '../models/adapty_promoted_product.dart';

/// The streams `Adapty()` hands to the app. They are broadcast: an event nobody listens to is dropped.
final class AdaptyCoreState {
  final StreamController<AdaptyProfile> profileUpdates = StreamController.broadcast();
  final StreamController<AdaptyPromotedProduct> promotedPurchases = StreamController.broadcast();
  final StreamController<AdaptyInstallationDetails> installationDetailsSuccess = StreamController.broadcast();
  final StreamController<AdaptyError> installationDetailsFail = StreamController.broadcast();

  /// Closes the streams; their listeners receive done.
  Future<void> dispose() => Future.wait([
    profileUpdates.close(),
    promotedPurchases.close(),
    installationDetailsSuccess.close(),
    installationDetailsFail.close(),
  ]);
}
