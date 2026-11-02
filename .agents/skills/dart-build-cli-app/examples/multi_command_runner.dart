// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Example template for a production multi-command Dart CLI application.
///
/// Demonstrates structured subcommands using `CommandRunner<int>`, conventional
/// process exit statuses, and proper `stderr` usage formatting.
/// Uses the project's existing args dependency and Dart's built-in I/O.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

Future<void> main(List<String> args) async {
  final runner = ToolCommandRunner();

  try {
    final status = await runner.run(args);
    exitCode = status ?? 0;
  } on UsageException catch (e) {
    // Usage errors (invalid flags/arguments) must write to stderr.
    stderr
      ..writeln(e.message)
      ..writeln(e.usage);
    exitCode = 64; // Conventional usage-error status.
  } catch (e, st) {
    stderr.writeln('Fatal error: $e');
    if (args.contains('-v') || args.contains('--verbose')) {
      stderr.writeln(st);
    }
    exitCode = 70; // Conventional software-error status.
  }
}

class ToolCommandRunner extends CommandRunner<int> {
  ToolCommandRunner() : super('tool', 'Multi-command production CLI utility.') {
    argParser
      ..addFlag(
        'verbose',
        abbr: 'v',
        negatable: false,
        help: 'Show verbose stack traces on failure.',
      )
      ..addFlag('version', negatable: false, help: 'Print tool version.');

    addCommand(ProcessCommand());
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    if (topLevelResults.flag('version')) {
      // Reuse a real tool's existing version source; generation is optional.
      stdout.writeln('tool version 1.0.0');
      return 0;
    }
    return super.runCommand(topLevelResults);
  }
}

class ProcessCommand extends Command<int> {
  @override
  final String name = 'process';

  @override
  final String description = 'Process input files.';

  ProcessCommand() {
    argParser.addOption(
      'input',
      abbr: 'i',
      mandatory: true,
      help: 'Path to input file.',
    );
  }

  @override
  Future<int> run() async {
    late final String input;
    try {
      input = argResults!.option('input')!;
    } on ArgumentError {
      throw UsageException('Missing required option --input.', usage);
    }
    stdout.writeln('Processing $input...');
    return 0;
  }
}
