/// The lines of a native log of the probe that show a defect, as opposed to the errors every call before
/// activation logs.
library;

import '../../contract/src/contract_schema.dart' show ContractPlatform;

/// The lines of [log] from the plugin of [platform] that show a defect. Before activation every call of the SDK
/// logs an error, so a log is never clean; a defect is only:
/// - iOS: a line of the wrapper (`io.adapty.flutter`) that could not read the creation params of a view;
/// - Android: a line of the platform views channel (a view that failed to be created) and a crash.
/// The exceptions of calls on the adapty channel are not defects here: the probe checks them against the
/// recorded outcomes.
List<String> defectLines(String log, ContractPlatform platform) => [
  for (final line in log.split('\n'))
    if (switch (platform) {
      ContractPlatform.ios => line.contains('[io.adapty.flutter') && _couldNotRead.hasMatch(line),
      ContractPlatform.android =>
        line.contains('MethodChannel#flutter/platform_views:') || line.contains('FATAL EXCEPTION'),
    })
      line,
];

/// The text of a decoding error, with either apostrophe.
final _couldNotRead = RegExp('couldn[’\']t be read');
