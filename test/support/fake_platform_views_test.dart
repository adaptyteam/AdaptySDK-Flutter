// The contract of the stand-in for the engine side of platform views: every view the framework creates is recorded
// with its id and view type, and its id is recorded again when the view goes away.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_platform_views.dart';

void main() {
  testWidgets('a UiKitView is recorded when created and when disposed', (tester) async {
    final views = FakePlatformViews.install(tester);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: UiKitView(viewType: 'test_view', creationParams: '{}', creationParamsCodec: StandardMessageCodec()),
      ),
    );
    expect(views.created.map((view) => view.viewType), ['test_view']);
    expect(views.disposed, isEmpty);

    await tester.pumpWidget(const SizedBox());

    expect(views.disposed, [views.created.single.id]);
  });

  testWidgets('an AndroidView is recorded when created and when disposed', (tester) async {
    final views = FakePlatformViews.install(tester);

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: AndroidView(viewType: 'test_view', creationParams: '{}', creationParamsCodec: StandardMessageCodec()),
      ),
    );
    expect(views.created.map((view) => view.viewType), ['test_view']);
    expect(views.disposed, isEmpty);

    await tester.pumpWidget(const SizedBox());

    expect(views.disposed, [views.created.single.id]);
  });
}
