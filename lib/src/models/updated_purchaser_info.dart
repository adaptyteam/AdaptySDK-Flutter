class UpdatedPurchaserInfo {
  final List<String> nonSubscriptionsProductIds;
  final List<String> activePaidAccessLevels;
  final List<String> activeSubscriptionsIds;

  UpdatedPurchaserInfo(this.nonSubscriptionsProductIds,
      this.activePaidAccessLevels, this.activeSubscriptionsIds);

  UpdatedPurchaserInfo.fromJson(Map<String, dynamic> json)
      : nonSubscriptionsProductIds = List<String>.from(
            json[_GetActivePurchasesResultKeys._nonSubscriptionsProductIds]),
        activePaidAccessLevels = List<String>.from(
            json[_GetActivePurchasesResultKeys._activePaidAccessLevels]),
        activeSubscriptionsIds = List<String>.from(
            json[_GetActivePurchasesResultKeys._activeSubscriptionsIds]);

  @override
  String toString() =>
      '${_GetActivePurchasesResultKeys._nonSubscriptionsProductIds}: ${nonSubscriptionsProductIds.join(', ')}, '
      '${_GetActivePurchasesResultKeys._activePaidAccessLevels}: ${activePaidAccessLevels.join(', ')}, '
      '${_GetActivePurchasesResultKeys._activeSubscriptionsIds}: ${activeSubscriptionsIds.join(', ')}';
}

class _GetActivePurchasesResultKeys {
  static const _nonSubscriptionsProductIds = "nonSubscriptionsProductIds";
  static const _activePaidAccessLevels = "activePaidAccessLevels";
  static const _activeSubscriptionsIds = "activeSubscriptionsIds";
}
