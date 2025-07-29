import 'package:meta/meta.dart' show immutable;
import 'product_reference.dart';

@immutable
class AdaptyProductIdentifier {
  final String vendorProductId;

  final String? basePlanId;

  final String _adaptyProductId;

  const AdaptyProductIdentifier._(
    this.vendorProductId,
    this.basePlanId,
    this._adaptyProductId,
  );

  const AdaptyProductIdentifier({
    required this.vendorProductId,
    this.basePlanId,
    required String adaptyProductId,
  }) : _adaptyProductId = adaptyProductId;

  factory AdaptyProductIdentifier.fromProductReference(ProductReference productReference) {
    return AdaptyProductIdentifier(
      vendorProductId: productReference.vendorId,
      basePlanId: productReference.basePlanId,
      adaptyProductId: productReference._adaptyProductId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdaptyProductIdentifier &&
          runtimeType == other.runtimeType &&
          vendorProductId == other.vendorProductId &&
          basePlanId == other.basePlanId &&
          _adaptyProductId == other._adaptyProductId;

  @override
  int get hashCode => Object.hash(vendorProductId, basePlanId, _adaptyProductId);

  @override
  String toString() => '(vendorProductId: $vendorProductId, '
      'basePlanId: $basePlanId, '
      '_adaptyProductId: $_adaptyProductId)';
}
