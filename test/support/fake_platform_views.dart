import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the engine side of the platform views channel, so a `UiKitView` or an `AndroidView` gets created in
/// a widget test, and records which views were created and disposed.
///
/// The view ids come from Flutter's `platformViewsRegistry`, a counter shared by every test in the file, so a test
/// reads the id from [created] rather than expecting a fixed one.
final class FakePlatformViews {
  FakePlatformViews._();

  /// Answers the platform views channel until the end of the test.
  ///
  /// At the end of the test the views still mounted are removed while the channel still answers. A test that fails
  /// leaves its widget tree in place, and the next test would otherwise dispose its views with nothing answering the
  /// channel and fail on that instead of on its own checks.
  static FakePlatformViews install(WidgetTester tester) {
    final views = FakePlatformViews._();
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, views._handle);
    addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform_views, null));
    // Tear-downs run in reverse order: the views go away before the channel stops answering.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    return views;
  }

  /// The id and the view type of each view created, in order.
  final created = <({int id, String viewType})>[];

  /// The id of each view disposed, in order.
  final disposed = <int>[];

  Future<Object?> _handle(MethodCall call) async {
    switch (call.method) {
      case 'create':
        final args = call.arguments as Map<Object?, Object?>;
        created.add((id: args['id']! as int, viewType: args['viewType']! as String));
        // An Android view created with a size is drawn into a texture; its id is the answer.
        return args.containsKey('width') ? 0 : null;
      case 'resize':
        final args = call.arguments as Map<Object?, Object?>;
        return {'width': args['width'], 'height': args['height']};
      case 'dispose':
        // iOS sends the id, Android a map with it.
        final args = call.arguments;
        disposed.add(args is Map ? args['id']! as int : args as int);
        return null;
      default:
        return null;
    }
  }
}
