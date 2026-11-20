/// The cases of the native probe and the outcomes it expects, as the generated bundle declares them.
///
/// Plain Dart without the app or Flutter, so that the tests of the bundle generator can read it too.
library;

/// The kind of a native error message.
enum L2aMessageClass {
  /// The plugin knows the method and could not decode its arguments.
  params('params'),

  /// The plugin does not know the method.
  unknownMethod('unknown-method'),

  /// Any other message.
  other('other');

  const L2aMessageClass(this.wireName);

  /// The name of the class in the log of the probe and in the expectations file.
  final String wireName;
}

/// What a plugin is expected to answer a case with.
sealed class L2aOutcome {
  const L2aOutcome();

  /// The outcome as a JSON value for the log of the probe.
  Object? toJson();
}

/// A success reply.
final class L2aSuccess extends L2aOutcome {
  const L2aSuccess();

  @override
  Object? toJson() => 'success';
}

/// An error reply with [code] and a message of [messageClass].
final class L2aError extends L2aOutcome {
  const L2aError(this.code, this.messageClass);

  final int code;
  final L2aMessageClass messageClass;

  @override
  Object? toJson() => {
    'error': {'code': code, 'class': messageClass.wireName},
  };
}

/// The plugin throws: the call ends in a `PlatformException` instead of a reply.
final class L2aNativeException extends L2aOutcome {
  const L2aNativeException();

  @override
  Object? toJson() => 'native_exception';
}

/// No reply in time.
final class L2aTimeout extends L2aOutcome {
  const L2aTimeout();

  @override
  Object? toJson() => 'timeout';
}

/// The case is not called, for [reason].
final class L2aSkip extends L2aOutcome {
  const L2aSkip(this.reason);

  final String reason;

  @override
  Object? toJson() => {'skip': reason};
}

/// The case is called and its answer recorded, not checked.
final class L2aObserve extends L2aOutcome {
  const L2aObserve();

  @override
  Object? toJson() => 'observe';
}

/// One call of the probe: [method] with the JSON string [arguments]; a payload broken by [variant] at
/// [instancePath] when [variant] is not null.
final class L2aCase {
  const L2aCase({
    required this.id,
    required this.method,
    required this.arguments,
    required this.expected,
    this.variant,
    this.instancePath,
  });

  final String id;
  final String method;
  final String arguments;
  final L2aOutcome expected;
  final String? variant;
  final String? instancePath;
}
