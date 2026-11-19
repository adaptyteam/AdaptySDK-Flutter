/// The contract of the test runtime helper the runtime tests build on.
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/runtime/adapty_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_runtime.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('at the end of the test the runtime is disposed while still current, then the previous one comes back', () {
    final previous = AdaptyRuntime.current;
    late final AdaptyRuntime runtime;
    AdaptyRuntime? currentWhenClosed;
    // Tear-downs run in reverse order, so this one runs after the helper's own.
    addTearDown(() {
      expect(
        currentWhenClosed,
        same(runtime),
        reason: 'the streams of the runtime were not closed while it was current',
      );
      expect(AdaptyRuntime.current, same(previous));
    });
    runtime = installTestRuntime();
    Adapty().didUpdateProfileStream.listen(null, onDone: () => currentWhenClosed = AdaptyRuntime.current);
  });
}
