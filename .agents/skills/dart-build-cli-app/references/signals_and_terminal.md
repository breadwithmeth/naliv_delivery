# Signals, terminal teardown and stream errors

## Cross-platform cancellation

On Windows, watch supported signals such as `ProcessSignal.sigint`; guard
`ProcessSignal.sigterm.watch()` with `!Platform.isWindows`. If async is already a
dependency, the following combines them; otherwise reuse existing cancellation
plumbing rather than adding a package for this helper.

```dart
import 'dart:io';
import 'package:async/async.dart';

Stream<ProcessSignal> watchTerminationSignals() => StreamGroup.merge([
  ProcessSignal.sigint.watch(),
  if (!Platform.isWindows) ProcessSignal.sigterm.watch(),
]);
```

A watched signal no longer necessarily causes default process termination. Its
listener should request cancellation of the running operation, stop accepting
work and let `finally` release owned resources. Set the desired process status
(for example 130 for user interruption); avoid `exit()` as a substitute for
teardown. Cancel signal subscriptions when the operation ends.

## Preserve terminal state

Only change `stdin.echoMode`/`stdin.lineMode` when `stdin.hasTerminal` is true.
Save their **original values** before changing either; restore both in `finally`
and on controlled cancellation. Do not blindly restore both to `true`.
In raw mode, Ctrl+C can arrive as input byte 3 rather than a SIGINT event; handle
that input through the same cancellation path.

Only emit cursor escape sequences when the output stream supports them. If the
tool hides the cursor, show it again during cleanup and flush pending writes.

```dart
bool get useAnsi =>
    stdout.hasTerminal &&
    stdout.supportsAnsiEscapes &&
    !Platform.environment.containsKey('NO_COLOR');
```

This check applies to stdout; inspect stderr separately if formatting diagnostics.

## Servers and children

Close the actual owned resource using its API: `HttpServer.close(force: true)`
can terminate active connections, whereas `ServerSocket.close()` has no `force`
parameter. Await closure. Forward cancellation to owned child processes using
platform-supported process termination, then await their exit. Windows process
termination semantics differ from POSIX signal delivery; do not assume signal
forwarding is identical or kills an entire descendant tree.

## Broken pipes are asynchronous

`IOSink.writeln` is buffered. A synchronous `try` around that call does not catch
all output errors. Observe the sink's `done` future from the start and handle
errors from `flush`/`close` according to sink ownership. Use the existing streaming
pipeline's cancellation mechanism to stop producing when the consumer closes.

If the CLI contract treats a closed downstream pipe as normal completion,
recognize the actual platform error narrowly and set the corresponding status.
Do not swallow every `SocketException`, match arbitrary message fragments, or
call `exit(0)` from a write helper: those patterns hide unrelated failures and
skip cleanup. Retain diagnostic failure behavior for other I/O errors.

See the [IOSink API](https://api.dart.dev/dart-io/IOSink-class.html) and
[ProcessSignal API](https://api.dart.dev/dart-io/ProcessSignal-class.html).
