/// The lines of a native log of the probe that show a defect, as opposed to the errors every call before
/// activation logs.
library;

import '../../contract/src/contract_schema.dart' show ContractPlatform;

/// The lines of [log] from the plugin of [platform] that show a defect. Before activation every call of the SDK
/// logs an error, so a log is never clean; a defect is only:
/// - iOS: a line of the wrapper (`io.adapty.flutter`) that could not read the creation params of a view, that
///   could not encode an event (the event is lost), or that met a second registration of the plugin (the app
///   runs one engine);
/// - Android: a line of the platform views channel (a view that failed to be created) and a crash.
/// The exceptions of calls on the adapty channel are not defects here: the probe checks them against the
/// recorded outcomes.
List<String> defectLines(String log, ContractPlatform platform) => [
  for (final line in log.split('\n'))
    if (switch (platform) {
      ContractPlatform.ios => line.contains('[io.adapty.flutter') && _iosDefect.hasMatch(line),
      ContractPlatform.android =>
        line.contains('MethodChannel#flutter/platform_views:') || line.contains('FATAL EXCEPTION'),
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
/// write it; on Android the log of the emulator has no line of the app process, as when it was cleared under the
/// test), its defect lines, and, with [onboardingViews] (iOS), a number of onboarding views that met an inactive
/// SDK other than that. Empty when the log is good.
List<String> nativeLogProblems(String log, ContractPlatform platform, {int? onboardingViews}) {
  final lines = log.split('\n');
  final written = switch (platform) {
    ContractPlatform.ios => lines.any((line) => line.startsWith('Timestamp ')),
    ContractPlatform.android => lines.any((line) => line.trim().isNotEmpty && !line.startsWith('#')),
  };
  if (!written) {
    return [
      switch (platform) {
        ContractPlatform.ios => 'log show did not write the log',
        ContractPlatform.android => 'no line of the app process in the log: it was not running or the log was lost',
      },
    ];
  }
  final onboardings = onboardingNotActivatedLines(log);
  return [
    for (final line in defectLines(log, platform)) 'defect: $line',
    if (onboardingViews != null && onboardings != onboardingViews)
      '$onboardings onboarding views met an inactive SDK, $onboardingViews expected',
  ];
}
