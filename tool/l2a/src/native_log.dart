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

/// What the wrapper logs on a defect: a decoding error (with either apostrophe), an event it cannot encode and a
/// second registration.
final _iosDefect = RegExp('couldn[\u2019\']t be read|Plugin encoding error|Attempt to register the plugin twice');
