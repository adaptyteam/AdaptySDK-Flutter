class AdaptyErrorCode {
  static final int none = -1;

  // system storekit codes
  static final int unknown = 0;
  static final int clientInvalid = 1; // client is not allowed to issue the request, etc.
  static final int paymentCancelled = 2; // user cancelled the request, etc.
  static final int paymentInvalid = 3; // purchase identifier was invalid, etc.
  static final int paymentNotAllowed = 4; // this device is not allowed to make the payment
  static final int storeProductNotAvailable = 5; // Product is not available in the current storefront
  static final int cloudServicePermissionDenied = 6; // user has not allowed access to cloud service information
  static final int cloudServiceNetworkConnectionFailed = 7; // the device could not connect to the nework
  static final int cloudServiceRevoked = 8; // user has revoked permission to use this cloud service
  static final int privacyAcknowledgementRequired = 9; // The user needs to acknowledge Apple's privacy policy
  static final int unauthorizedRequestData = 10; // The app is attempting to use SKPayment's requestData property, but does not have the appropriate entitlement
  static final int invalidOfferIdentifier = 11; // The specified subscription offer identifier is not valid
  static final int invalidSignature = 12; // The cryptographic signature provided is not valid
  static final int missingOfferParams = 13; // One or more parameters from SKPaymentDiscount is missing
  static final int invalidOfferPrice = 14;

  //custom android codes
  static final int adaptyNotInitialized = 20;
  static final int paywallNotFound = 21;
  static final int productNotFound = 22;
  static final int invalidJson = 23;
  static final int currentSubscriptionToUpdateNotFoundInHistory = 24;
  static final int billingServiceTimeout = 97;
  static final int featureNotSupported = 98;
  static final int billingServiceDisconnected = 99;
  static final int billingServiceUnavailable = 102;
  static final int billingUnavailable = 103;
  static final int developerError = 105;
  static final int billingError = 106;
  static final int itemAlreadyOwned = 107;
  static final int itemNotOwned = 108;

  // custom storekit codes
  static final int noProductIDsFound = 1000; // No In-App Purchase product identifiers were found
  static final int noProductsFound = 1001; // No In-App Purchases were found
  static final int productRequestFailed = 1002; // Unable to fetch available In-App Purchase products at the moment
  static final int cantMakePayments = 1003; // In-App Purchases are not allowed on this device
  static final int noPurchasesToRestore = 1004; // No purchases to restore
  static final int cantReadReceipt = 1005; // Can't find a valid receipt
  static final int productPurchaseFailed = 1006; // Product purchase failed
  static final int missingOfferSigningParams = 1007; // Missing offer signing required params
  static final int fallbackPaywallsNotRequired = 1008; // Fallback paywalls are not required

  // custom network codes
  static final int emptyResponse = 2000; //Response is empty
  static final int emptyData = 2001; // Request data is empty
  static final int authenticationError = 2002; // You need to be authenticated first
  static final int badRequest = 2003; // Bad request
  static final int serverError = 2004; // Response code is 429 or 500s
  static final int failed = 2005; // Network request failed
  static final int unableToDecode = 2006; // We could not decode the response
  static final int missingParam = 2007; // Missing some of the required params
  static final int invalidProperty = 2008; // Received invalid property data
  static final int encodingFailed = 2009; // Parameters encoding failed
  static final int missingURL = 2010; // Request url is nil
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
