// ignore_for_file: deprecated_member_use
import 'package:adapty_flutter/adapty_flutter.dart';
import 'package:adapty_flutter/src/models/adaptyui/adaptyui_onboarding_view.dart'
    show AdaptyUIOnboardingViewJSONBuilder;
import 'package:flutter_test/flutter_test.dart';

AdaptyUIOnboardingView _view(String id) => AdaptyUIOnboardingViewJSONBuilder.fromJsonValue({
  'id': id,
  'placement_id': 'placement-id',
  'variation_id': 'variation-id',
});

void main() {
  test('an onboarding view whose id the widget assigned is rendered in a Flutter widget', () {
    final view = _view('flutter_native_3');

    expect(view.isWidgetRendering, isTrue);
    expect(view.isNativeRendering, isFalse);
  });

  test('an onboarding view whose id the native SDK assigned is rendered as a native modal view', () {
    final view = _view('5C1D9E2A-7B4F-4E8A-9D3C-1F2E3A4B5C6D');

    expect(view.isWidgetRendering, isFalse);
    expect(view.isNativeRendering, isTrue);
  });
}
