import 'dart:io';

import '../contract/src/contract_schema.dart';
import '../contract/src/contract_source.dart';
import '../contract/src/corpus.dart';
import '../contract/src/source_refs.dart';
import 'src/bundle.dart';

// Usage, from the repository root: dart run tool/l2a/bundle_cases.dart [--discover] [--out <path>]
//
// Writes the cases of the native probe (integration_test_app/integration_test/support/l2a_cases.g.dart
// unless --out names another file): the golden requests of contract/ on each platform and the payloads
// derived from them, with the outcomes of integration_test_app/l2a_expectations.yaml, without the methods
// of integration_test_app/l2a_denylist.yaml, and the creation params of the embedded views under
// contract/pseudo/, and prints the number of cases, of onboarding views, of flow views and of cases expected to be
// refused as bad params of each platform. By default the bundle is strict: a case without an expected outcome stops
// it.
// --discover observes such cases instead, to record what the plugins answer.
//
// Exit codes: 0 — written; 1 — a problem stops the bundle or an input could not be read.
const _expectationsPath = 'integration_test_app/l2a_expectations.yaml';
const _denylistPath = 'integration_test_app/l2a_denylist.yaml';
const _transportPath = 'lib/src/runtime/adapty_native_transport.dart';
const _methodsPath = 'lib/src/constants/method.dart';
const _defaultOut = 'integration_test_app/integration_test/support/l2a_cases.g.dart';
const _usage = 'usage: dart run tool/l2a/bundle_cases.dart [--discover] [--out <path>]';

void main(List<String> args) {
  var discover = false;
  var out = _defaultOut;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--discover':
        discover = true;
      case '--out' when i + 1 < args.length:
        out = args[++i];
      default:
        stderr
          ..writeln('unknown arguments: ${args.skip(i).join(' ')}')
          ..writeln(_usage);
        exit(1);
    }
  }

  try {
    final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    if (version == null) throw const FormatException('pubspec.yaml has no version');
    final corpus = Corpus.load('.');
    if (corpus.problems.isNotEmpty) throw BundleProblems(corpus.problems);
    final views = PlatformViewCases.load('.');
    if (views.problems.isNotEmpty) throw BundleProblems(views.problems);
    final bundle = buildBundle(
      schema: ContractSchema.load('.'),
      corpus: corpus,
      views: views,
      sdkMethods: sdkMethodsFrom(File(_methodsPath).readAsStringSync()),
      sdkVersion: version.group(1)!,
      channelName: channelNameFrom(File(_transportPath).readAsStringSync()),
      denylist: Denylist.parse(File(_denylistPath).readAsStringSync(), path: _denylistPath),
      expectations: Expectations.parse(
        File(_expectationsPath).readAsStringSync(),
        path: _expectationsPath,
        refs: NativeRefs.of(ContractSource.load('.')).all,
      ),
      discover: discover,
    );
    File(out)
      ..createSync(recursive: true)
      ..writeAsStringSync(bundle.render());
    bundleReport(bundle, out: out, discover: discover).forEach(stdout.writeln);
  } on BundleProblems catch (e) {
    stderr.writeln('the bundle is not written:');
    for (final problem in e.problems) {
      stderr.writeln('  $problem');
    }
    exit(1);
  } on FileSystemException catch (e) {
    stderr.writeln('${e.path}: ${e.message}');
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  }
}
