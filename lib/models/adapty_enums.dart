enum AdaptyLogLevel { none, errors, verbose }

enum AdaptyDataState { cached, synced }

enum AdaptyPeriodUnit { day, week, month, year, unknown }

enum AdaptyPaymentMode { payAsYouGo, payUpFront, freeTrial, unknown }

enum AdaptyGender { female, male, other }

enum AdaptyAttributionNetwork { adjust, appsflyer, branch, appleSearchAds, custom }

AdaptyPeriodUnit periodUnitFromInt(int? value) {
  switch (value) {
    case 0:
      return AdaptyPeriodUnit.day;
    case 1:
      return AdaptyPeriodUnit.week;
    case 2:
      return AdaptyPeriodUnit.month;
    case 3:
      return AdaptyPeriodUnit.year;
    default:
      return AdaptyPeriodUnit.unknown;
  }
}

AdaptyPaymentMode paymentModeFromInt(int? value) {
  switch (value) {
    case 0:
      return AdaptyPaymentMode.payAsYouGo;
    case 1:
      return AdaptyPaymentMode.payUpFront;
    case 2:
      return AdaptyPaymentMode.freeTrial;
    default:
      return AdaptyPaymentMode.unknown;
  }
}

extension AdaptyAttributionNetworkExtension on AdaptyAttributionNetwork {
  static AdaptyAttributionNetwork? fromStringValue(String? value) {
    switch (value) {
      case 'adjust':
        return AdaptyAttributionNetwork.adjust;
      case 'appsflyer':
        return AdaptyAttributionNetwork.appsflyer;
      case 'branch':
        return AdaptyAttributionNetwork.branch;
      case 'appleSearchAds':
        return AdaptyAttributionNetwork.appleSearchAds;
      case 'custom':
        return AdaptyAttributionNetwork.custom;
      default:
        return null;
    }
  }

  String? stringValue() {
    switch (this) {
      case AdaptyAttributionNetwork.adjust:
        return 'adjust';
      case AdaptyAttributionNetwork.appsflyer:
        return 'appsflyer';
      case AdaptyAttributionNetwork.branch:
        return 'branch';
      case AdaptyAttributionNetwork.appleSearchAds:
        return 'appleSearchAds';
      case AdaptyAttributionNetwork.custom:
        return 'custom';
      default:
        return null;
    }
  }
}
