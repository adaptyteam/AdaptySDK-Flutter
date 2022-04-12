class AdaptyErrorCode {
  static const int none = -1;

  ///////////////////////////
  /// System StoreKit codes

  static const int unknown = 0;

  /// client is not allowed to issue the request, etc.
  static const int clientInvalid = 1;

  /// user cancelled the request, etc.
  static const int paymentCancelled = 2;

  /// purchase identifier was invalid, etc.
  static const int paymentInvalid = 3;

  /// this device is not allowed to make the payment
  static const int paymentNotAllowed = 4;

  /// Product is not available in the current storefront
  static const int storeProductNotAvailable = 5;

  /// user has not allowed access to cloud service information
  static const int cloudServicePermissionDenied = 6;

  /// the device could not connect to the nework
  static const int cloudServiceNetworkConnectionFailed = 7;

  /// user has revoked permission to use this cloud service
  static const int cloudServiceRevoked = 8;

  /// The user needs to acknowledge Apple's privacy policy
  static const int privacyAcknowledgementRequired = 9;

  /// The app is attempting to use SKPayment's requestData property, but does not have the appropriate entitlement
  static const int unauthorizedRequestData = 10;

  /// The specified subscription offer identifier is not valid
  static const int invalidOfferIdentifier = 11;

  /// The cryptographic signature provided is not valid
  static const int invalidSignature = 12;

  /// One or more parameters from SKPaymentDiscount is missing
  static const int missingOfferParams = 13;

  static const int invalidOfferPrice = 14;

  ///////////////////////////
  /// Custom Android codes

  static const int adaptyNotInitialized = 20;
  static const int paywallNotFound = 21;
  static const int productNotFound = 22;
  static const int invalidJson = 23;
  static const int currentSubscriptionToUpdateNotFoundInHistory = 24;
  static const int pendingPurchase = 25;
  static const int billingServiceTimeout = 97;
  static const int featureNotSupported = 98;
  static const int billingServiceDisconnected = 99;
  static const int billingServiceUnavailable = 102;
  static const int billingUnavailable = 103;
  static const int developerError = 105;
  static const int billingError = 106;
  static const int itemAlreadyOwned = 107;
  static const int itemNotOwned = 108;

  ///////////////////////////
  /// Custom StoreKit codes

  /// No In-App Purchase product identifiers were found
  static const int noProductIDsFound = 1000;

  /// No In-App Purchases were found
  static const int noProductsFound = 1001;

  /// Unable to fetch available In-App Purchase products at the moment
  static const int productRequestFailed = 1002;

  /// In-App Purchases are not allowed on this device
  static const int cantMakePayments = 1003;

  /// No purchases to restore
  static const int noPurchasesToRestore = 1004;

  /// Can't find a valid receipt
  static const int cantReadReceipt = 1005;

  /// Product purchase failed
  static const int productPurchaseFailed = 1006;

  /// Missing offer signing required params
  static const int missingOfferSigningParams = 1007;

  /// Fallback paywalls are not required
  static const int fallbackPaywallsNotRequired = 1008;

  ///////////////////////////
  /// Custom network codes

  /// Response is empty
  static const int emptyResponse = 2000;

  /// Request data is empty
  static const int emptyData = 2001;

  /// You need to be authenticated first
  static const int authenticationError = 2002;

  /// Bad request
  static const int badRequest = 2003;

  /// Response code is 429 or 500s
  static const int serverError = 2004;

  /// Network request failed
  static const int failed = 2005;

  /// We could not decode the response
  static const int unableToDecode = 2006;

  /// Missing some of the required params
  static const int missingParam = 2007;

  /// Received invalid property data
  static const int invalidProperty = 2008;

  /// Parameters encoding failed
  static const int encodingFailed = 2009;

  /// Request url is nil
  static const int missingURL = 2010;
}

class AdaptyError implements Exception {
  final int? code;
  final String message;
  final String? domain;
  final int adaptyCode;

  AdaptyError.fromMap(Map<String, dynamic> map)
      : code = map['code'],
        message = map['message'],
        domain = map['domain'],
        adaptyCode = map['adaptyCode'];

  @override
  String toString() => 'AdaptyError (code $code) $message';
}
