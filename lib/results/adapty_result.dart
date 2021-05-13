class AdaptyResult {
  final String? errorCode;
  final String? errorMessage;

  AdaptyResult({this.errorCode, this.errorMessage});

  bool success() => errorCode == null && errorMessage == null;
}
