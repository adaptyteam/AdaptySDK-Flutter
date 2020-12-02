import 'dart:core';

import '../models/adapty_enums.dart';
import '../models/adapty_purchaser_info.dart';

class GetPurchaserInfoResult {
  final AdaptyPurchaserInfo purchaserInfo; // nullable
  final AdaptyDataState dataState;

  GetPurchaserInfoResult.fromJson(Map<String, dynamic> json)
      : purchaserInfo = AdaptyPurchaserInfo.fromJson(json[_Keys.purchaserInfo]),
        dataState = dataStateFromInt(json[_Keys.dataState]);

  @override
  String toString() => '${_Keys.purchaserInfo}: $purchaserInfo, '
      '${_Keys.dataState}: $dataState';
}

class _Keys {
  static const String purchaserInfo = "purchaserInfo";
  static const String dataState = "dataState";
}
