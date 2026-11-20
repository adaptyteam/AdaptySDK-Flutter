import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/l2a_probe.dart';
import 'support/l2a_types.dart';

/// Sends every case of the bundle to the plugin before activation and prints what it answered, one
/// `L2A_OUTCOME` line per case and an `L2A_SUMMARY` line, to record the expectations from.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the plugin answers every case of the bundle', (tester) async {
    await l2aReadinessBarrier(tester);
    final counts = <String, int>{};
    final unexpected = <String>[];
    for (final c in l2aPlatformCases) {
      final line = <String, Object?>{
        'id': c.id,
        'method': c.method,
        'platform': l2aPlatform,
        'expected': c.expected.toJson(),
        if (c.variant != null) 'variant': c.variant,
        if (c.instancePath != null) 'path': c.instancePath,
      };
      if (c.expected is L2aSkip) {
        counts.update('skip', (n) => n + 1, ifAbsent: () => 1);
        print('L2A_OUTCOME ${jsonEncode(line)}');
        continue;
      }
      final observed = await l2aInvoke(c);
      final matches = l2aMatches(c.expected, observed);
      counts.update(observed.kind, (n) => n + 1, ifAbsent: () => 1);
      if (!matches) unexpected.add(c.id);
      print('L2A_OUTCOME ${jsonEncode({...line, 'observed': observed.toJson(), 'matches': matches})}');
    }
    print(
      'L2A_SUMMARY ${jsonEncode({'platform': l2aPlatform, 'cases': l2aPlatformCases.length, 'observed': counts, 'unexpected': unexpected.length})}',
    );
    expect(counts['missing_plugin'], isNull, reason: 'the plugin does not handle its channel');
  });
}
