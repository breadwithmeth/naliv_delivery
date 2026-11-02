# Dart documentation examples

These fragments assume the displayed declarations and behavior already exist.
Do not infer a cache or exception contract from these illustrative names.

### 1. Banned Tags vs. Prose
**Bad:**
```dart
/// This method fetches data.
/// @param force true to force reload.
/// @return the data
/// @throws NetworkException if host is unreachable.
Data load(bool force) { ... }
```
**Good:**
```dart
/// Fetches the remote data.
///
/// If [force] is `true`, this bypasses the local cache and forces a
/// network request.
///
/// Throws a [NetworkException] if the host is unreachable.
Data load(bool force) { ... }
```

### 2. The Annotation Placement Trap
**Bad:**
```dart
@override
/// Renders the widget to the screen.
Widget build(BuildContext context) { ... }
```
**Good:**
```dart
/// Renders the widget to the screen.
@override
Widget build(BuildContext context) { ... }
```

### 3. Openers and Tone
**Bad:**
```dart
/// Gets if the connection is active.
bool get isActive => _active;

/// This method initializes the connection.
void init() { ... }
```
**Good:**
```dart
/// Whether the connection is active.
bool get isActive => _active;

/// Initializes the connection.
void init() { ... }
```

### 4. Constructor Linking
**Bad:**
```dart
/// Creates a new user. Similar to calling [User()].
User.create() { ... }
```
**Good:**
```dart
/// Creates a new user. Similar to calling [User.new].
User.create() { ... }
```

### 5. Out-of-Scope Links (@docImport)
**Bad:**
```dart
import 'package:http/http.dart'; // Ordinary code import used solely for docs

/// To use this, you must pass a [Client].
```
**Good:**
```dart
/// @docImport 'package:http/http.dart';
library;

/// To use this, you must pass a [Client].
```

Both HTTP examples assume `http` is already declared and available to the package.
`@docImport` changes documentation lookup scope, not dependency resolution.
The ordinary import is unnecessary here only because executable code does not use it.
