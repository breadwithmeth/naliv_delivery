// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Example template for a single-command Dart CLI script or utility.
///
/// Demonstrates argument parsing with `ArgParser`, standard I/O stream routing,
/// and non-destructive exit code assignment via `exitCode`.
/// Uses the project's existing args dependency and Dart's built-in I/O.
library;

import 'dart:io';

import 'package:args/args.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information.',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show detailed stack traces on fatal error.',
    )
    ..addOption(
      'input',
      abbr: 'i',
      mandatory: true,
      help: 'Path to the input file to process.',
    );

  late final String inputPath;
  try {
    final results = parser.parse(args);

    if (results.flag('help')) {
      // Explicit help requested by user: write usage to stdout.
      stdout
        ..writeln('Usage: tool [options]')
        ..writeln(parser.usage);
      return;
    }

    inputPath = results.option('input')!;
  } on FormatException catch (e) {
    // Argument parse error: write error message AND usage to stderr.
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln(parser.usage);
    exitCode = 64; // Conventional usage-error status.
  } on ArgumentError catch (e) {
    // Missing mandatory option error thrown by results.option():
    stderr
      ..writeln('Error: ${e.message}')
      ..writeln(parser.usage);
    exitCode = 64;
  }
  if (exitCode != 0) return;

  try {
    await _runTool(inputPath);
  } catch (e, st) {
    stderr.writeln('Fatal error: $e');
    if (args.contains('-v') || args.contains('--verbose')) {
      stderr.writeln(st);
    }
    exitCode = 70; // Conventional software-error status.
  }
}

/// Encapsulates the tool's core business logic.
///
/// In larger applications, place this logic in `lib/src/` rather than
/// directly in `bin/` so unit tests can import and test functions directly
/// without needing to spawn an OS subprocess.
Future<void> _runTool(String inputPath) async {
  stdout.writeln('Processing $inputPath...');
}
