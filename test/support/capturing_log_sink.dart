import 'package:adapty_flutter/src/models/adapty_log_level.dart';
import 'package:adapty_flutter/src/runtime/adapty_log_sink.dart';

/// Keeps every log line the SDK writes, in order, and hands out the stamps `0001`, `0002`, … in turn.
final class CapturingLogSink implements AdaptyLogSink {
  final records = <AdaptyLogRecord>[];
  var _stamps = 0;

  /// The level and the message of every record, in order.
  List<(AdaptyLogLevel, String)> get lines => [for (final record in records) (record.level, record.message)];

  @override
  void write(AdaptyLogRecord record) => records.add(record);

  @override
  String nextStamp() => '${++_stamps}'.padLeft(4, '0');
}
