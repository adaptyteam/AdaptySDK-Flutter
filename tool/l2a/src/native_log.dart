/// The lines of a native log of the probe that show a defect, as opposed to the errors every call before
/// activation logs.
library;

import '../../contract/src/contract_schema.dart' show ContractPlatform;

/// The lines of [log] from the plugin of [platform] that show a defect. Before activation every call of the SDK
/// logs an error, so a log is never clean; a defect is only:
/// - iOS: a line of the wrapper (`io.adapty.flutter`) that could not read the creation params of a view, that
///   could not encode an event (the event is lost), or that met a second registration of the plugin (the app
///   runs one engine);
/// - Android: a line of the platform views channel (a view that failed to be created), a crash of the app or of its
///   native code, and a line of the SDK that could not parse the arguments of a call (with the log level of the SDK at
///   verbose; the plugin answers nothing then, so only the log shows it).
/// The exceptions of calls on the adapty channel are not defects here: the probe checks them against the
/// recorded outcomes.
List<String> defectLines(String log, ContractPlatform platform) => [
  for (final line in log.split('\n'))
    if (switch (platform) {
      ContractPlatform.ios => line.contains('[io.adapty.flutter') && _iosDefect.hasMatch(line),
      ContractPlatform.android =>
        line.contains('MethodChannel#flutter/platform_views:') ||
            line.contains('FATAL EXCEPTION') ||
            line.contains('Fatal signal') ||
            (line.contains('Adapty_v') && line.contains('could not parse args as')),
    })
      line,
];

/// How many lines of the iOS wrapper in [log] say that an onboarding view met an inactive SDK (AdaptyUI error 4002):
/// one for each onboarding view created before activation whose creation params decoded.
int onboardingNotActivatedLines(String log) => [
  for (final line in log.split('\n'))
    if (line.contains('[io.adapty.flutter') && line.contains('AdaptyUIErrorDomain error 4002')) line,
].length;

/// What the wrapper logs on a defect: a decoding error (with either apostrophe), an event it cannot encode and a
/// second registration.
final _iosDefect = RegExp('couldn[\u2019\']t be read|Plugin encoding error|Attempt to register the plugin twice');

/// What is wrong with the native log [log] of a test on [platform]: a log that was lost (on iOS `log show` did not
/// write it, or its window has no line of the app process `Runner`; on Android the log of the emulator has no line
/// of the app process, as when it was cleared under the test), its defect lines, with [onboardingViews] (iOS) a number of onboarding views that met an inactive SDK other
/// than that, and with [flowViews] (Android) a number of flow views that asked for their configuration other than
/// that. Empty when the log is good.
List<String> nativeLogProblems(String log, ContractPlatform platform, {int? onboardingViews, int? flowViews}) {
  final lines = log.split('\n');
  if (platform == ContractPlatform.ios && !lines.any((line) => line.startsWith('Timestamp '))) {
    return ['log show did not write the log'];
  }
  final ofApp = switch (platform) {
    ContractPlatform.ios => lines.any(_iosAppProcess.hasMatch),
    ContractPlatform.android => lines.any((line) => line.trim().isNotEmpty && !line.startsWith('#')),
  };
  if (!ofApp) return ['no line of the app process in the log: it was not running or the log was lost'];
  final onboardings = onboardingNotActivatedLines(log);
  final flows = flowViewConfigurationLines(log);
  return [
    for (final line in defectLines(log, platform)) 'defect: $line',
    if (onboardingViews != null && onboardings != onboardingViews)
      '$onboardings onboarding views met an inactive SDK, $onboardingViews expected',
    if (flowViews != null && flows != flowViews) '$flows flow views asked for their configuration, $flowViews expected',
  ];
}

/// How many lines of the SDK on Android in [log] say that a flow view could not get its configuration (the SDK is not
/// activated): one for each flow view created before activation whose creation params parsed.
int flowViewConfigurationLines(String log) => [
  for (final line in log.split('\n'))
    if (line.contains('Adapty_v') && line.contains('Failed to get view configuration')) line,
].length;

/// A line of the iOS app process in `log show` (`… Runner: (Flutter) flutter: …`).
final _iosAppProcess = RegExp(r'\sRunner[:\[]');
