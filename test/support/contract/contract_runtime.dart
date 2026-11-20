import 'package:adapty_flutter/src/adapty.dart';
import 'package:adapty_flutter/src/runtime/adapty_internal_error_sink.dart';
import 'package:adapty_flutter/src/runtime/adapty_native_transport.dart';
import 'package:adapty_flutter/src/runtime/adapty_platform_info.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_test/flutter_test.dart';

import '../../../tool/contract/src/contract_schema.dart';
import '../../../tool/contract/src/corpus.dart';
import '../../../tool/contract/src/request_check.dart';
import '../capturing_log_sink.dart';
import '../collecting_error_sink.dart';
import '../test_platform_info.dart';
import 'contract_native.dart';

/// A runtime of the SDK over the real adapty method channel with the contract native of one platform
/// on the other side.
final class ContractRuntime {
  ContractRuntime._(this.runtime, this.native, this.errors, this.log);

  final AdaptyRuntime runtime;
  final ContractNative native;

  /// The errors the SDK swallowed; any left at the end of the test fails it.
  final CollectingErrorSink errors;

  /// The log of the SDK.
  final CapturingLogSink log;

  /// Hands over the records of the errors the SDK swallowed so far and forgets them.
  List<AdaptyInternalErrorRecord> takeErrorRecords() {
    final taken = [...errors.records];
    errors.records.clear();
    return taken;
  }

  /// Fails the test with every error the SDK swallowed so far.
  void verify() {
    if (errors.records.isEmpty) return;
    fail(
      'The SDK swallowed ${errors.records.length} error(s) on ${native.platform.name}:\n'
      '${errors.records.map((r) => '${r.kind.name} in ${r.context}: ${r.error}').join('\n')}',
    );
  }
}

const _platforms = {
  ContractPlatform.ios: TestPlatformInfo(
    isIOS: true,
    isAndroid: false,
    viewKind: AdaptyPlatformViewKind.uiKit,
    logTag: 'i',
  ),
  ContractPlatform.android: TestPlatformInfo(
    isIOS: false,
    isAndroid: true,
    viewKind: AdaptyPlatformViewKind.android,
    logTag: 'a',
  ),
};

/// Puts a runtime over the real adapty method channel in place of the current one for the rest of the
/// test, with the contract native of [platform] answering the channel, and returns both. The SDK
/// handles the events of the native side on it, as after a hot restart.
///
/// The runtime reports [platform] as its platform. The errors the SDK swallows go to
/// [ContractRuntime.errors] and fail the test unless taken; the log goes to [ContractRuntime.log]. App
/// message ids are `00000000-0000-4000-8000-000000000001`, `…0002` and so on, the same in every run.
/// At the end of the test the runtime is disposed, the previous one comes back and the channel has no
/// native answering it.
///
/// The schema, the corpus and the baseline are those of this repository unless given. The clean-up is
/// registered with [registerTearDown], which only the self-test of the contract native replaces.
///
/// Only in `test/contract/` and in the self-test of this file, where every test file runs in an
/// isolate of its own: disposing this runtime takes the incoming handler off the shared channel, which
/// the production runtime of the isolate would otherwise rely on.
ContractRuntime installContractRuntime({
  required ContractPlatform platform,
  ContractSchema? schema,
  Corpus? corpus,
  List<BaselineEntry>? baseline,
  @visibleForTesting void Function(dynamic Function()) registerTearDown = addTearDown,
}) {
  final native = ContractNative.install(
    platform: platform,
    schema: schema,
    corpus: corpus,
    baseline: baseline,
    registerTearDown: registerTearDown,
  );
  final errors = CollectingErrorSink();
  final log = CapturingLogSink();
  var messages = 0;
  final runtime = AdaptyRuntime(
    transport: const MethodChannelTransport(),
    platform: _platforms[platform],
    errorSink: errors,
    logSink: log,
    newMessageId: () => contractMessageId(++messages),
  );
  final contract = ContractRuntime._(runtime, native, errors, log);
  final previous = AdaptyRuntime.debugInstall(runtime);
  registerTearDown(() async {
    await runtime.debugDispose();
    AdaptyRuntime.debugInstall(previous);
    contract.verify();
  });
  Adapty().setupAfterHotRestart();
  return contract;
}
