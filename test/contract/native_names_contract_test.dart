/// The names the SDK uses on the channel and the names the contract has, compared both ways: a
/// method the SDK calls that the contract lacks, or a request or an event of the contract the SDK
/// does not know, shows up here.
import 'package:adapty_flutter/src/constants/method.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/contract/src/contract_schema.dart';

/// Requests of the contract the SDK does not send, with the reason.
const _requestsTheSdkDoesNotSend = {
  'get_log_level': 'the SDK keeps the log level it sets and never reads it back from the native side',
  'get_sdk_version': 'the SDK version is a Dart constant',
};

final ContractSchema schema = ContractSchema.load('.');

void main() {
  test('every method and event answer the SDK sends is a request of the contract, and the other way round', () {
    final sent = {
      for (final m in NativeMethod.values) m.wireName,
      for (final r in NativeEventResponse.values) r.wireName,
    };
    final contract = schema.requestMethods.toSet();
    expect(sent.difference(contract), isEmpty, reason: 'sent by the SDK, missing in the contract');
    expect(
      contract.difference(sent),
      unorderedEquals(_requestsTheSdkDoesNotSend.keys),
      reason: 'requests of the contract the SDK does not send must be listed with a reason',
    );
  });

  test('every event the SDK handles is an event of the contract, and the other way round', () {
    final handled = {for (final e in NativeEvent.values) e.wireName};
    final contract = schema.eventIds.toSet();
    expect(handled.difference(contract), isEmpty, reason: 'handled by the SDK, missing in the contract');
    expect(contract.difference(handled), isEmpty, reason: 'sent by the natives, unknown to the SDK');
  });
}
