//
//  adapty_error_code.dart
//  Adapty
//
//  Created by Aleksei Valiano on 25.11.2022.
//

class AdaptyErrorCode {
  //////////////////////////////
  /// System StoreKit codes. ///
  //////////////////////////////

  /// Error code indicating that an unknown or unexpected error occurred.
  static final int unknown = 0;

  /// Error code indicating that the client is not allowed to perform the attempted action.
  static final int clientInvalid = 1;

  /// Error code indicating that the user canceled a payment request.
  static final int paymentCancelled = 2; 

  /// Error code indicating that one of the payment parameters was not recognized by the App Store.
  static final int paymentInvalid = 3; 

  /// Error code indicating that the user is not allowed to authorize payments.
  static final int paymentNotAllowed = 4; 

  /// Error code indicating that the requested product is not available in the store.
  static final int storeProductNotAvailable = 5; 

  /// Error code indicating that the user has not allowed access to Cloud service information.
  static final int cloudServicePermissionDenied = 6; 

  /// Error code indicating that the device could not connect to the network.
  static final int cloudServiceNetworkConnectionFailed = 7; 

  /// Error code indicating that the user has revoked permission to use this cloud service.
  static final int cloudServiceRevoked = 8; 

  /// Error code indicating that the user has not yet acknowledged Apple’s privacy policy.
  static final int privacyAcknowledgementRequired = 9; 

  /// Error code indicating that the app is attempting to use a property for which it does not have the required entitlement.
  static final int unauthorizedRequestData = 10;

  /// Error code indicating that the offer identifier is invalid.
  static final int invalidOfferIdentifier = 11; 

  /// Error code indicating that the signature in a payment discount is not valid.
  static final int invalidSignature = 12; 

  /// Error code indicating that parameters are missing in a payment discount.
  static final int missingOfferParams = 13; 

  /// Error code indicating that the price you specified in App Store Connect is no longer valid.
  static final int invalidOfferPrice = 14;

  /////////////////////////////
  /// Custom Android codes. ///
  /////////////////////////////

  static final int adaptyNotInitialized = 20;
  static final int productNotFound = 22;
  static final int invalidJson = 23;
  static final int currentSubscriptionToUpdateNotFoundInHistory = 24;
  static final int pendingPurchase = 25;
  static final int billingServiceTimeout = 97;
  static final int featureNotSupported = 98;
  static final int billingServiceDisconnected = 99;
  static final int billingServiceUnavailable = 102;
  static final int billingUnavailable = 103;
  static final int developerError = 105;
  static final int billingError = 106;
  static final int itemAlreadyOwned = 107;
  static final int itemNotOwned = 108;

  //////////////////////////////
  /// Custom StoreKit codes. ///
  //////////////////////////////

  /// No In-App Purchase product identifiers were found.
  static final int noProductIDsFound = 1000;

  /// Unable to fetch available In-App Purchase products at the moment.
  static final int productRequestFailed = 1002;

  /// In-App Purchases are not allowed on this device.
  static final int cantMakePayments = 1003;

  /// No purchases to restore.
  static final int noPurchasesToRestore = 1004;

  /// Can't find a valid receipt.
  static final int cantReadReceipt = 1005;

  /// Product purchase failed.
  static final int productPurchaseFailed = 1006;

  /// Receipt refresh operation has been failed.
  static final int refreshReceiptFailed = 1010;

  /// Error occured in the process of restoring purchases.
  static final int receiveRestoredTransactionsFailed = 1011;

  /////////////////////////////
  /// Custom network codes. ///
  /////////////////////////////

  /// You need to be authenticated to perform requests.
  static final int notActivated = 2002;

  /// Bad request
  static final int badRequest = 2003;

  /// Response code is 429 or 500s.
  static final int serverError = 2004;

  /// Network request failed
  static final int networkFailed = 2005;

  /// We could not decode the response.
  static final int decodingFailed = 2006;

  /// Parameters encoding failed.
  static final int encodingFailed = 2009;
  static final int analyticsDisabled = 3000;

  /// Wrong parameter was passed.
  static final int wrongParam = 3001;

  /// It is not possible to call `.activate` method more than once.
  static final int activateOnceError = 3005;

  /// The user profile was changed during the operation.
  static final int profileWasChanged = 3006;

  /// It was error while saving data.
  static final int persistingDataError = 3100;

  /// This operation was interrupted by the system.
  static final int operationInterrupted = 9000;
}
