/// How a flow or onboarding view is presented on iOS. Android ignores it.
enum AdaptyUIIOSPresentationStyle {
  /// The view covers the whole screen, and the user cannot swipe it away. The default.
  fullScreen,

  /// The view is shown as a sheet that the user can swipe down to close. A flow view closed
  /// this way stays alive: present it again, or release it with [AdaptyUIFlowView.destroy].
  pageSheet,
}

extension AdaptyUIIOSPresentationStyleExtension on AdaptyUIIOSPresentationStyle {
  String get jsonValue => switch (this) {
        AdaptyUIIOSPresentationStyle.fullScreen => 'full_screen',
        AdaptyUIIOSPresentationStyle.pageSheet => 'page_sheet',
      };
}
