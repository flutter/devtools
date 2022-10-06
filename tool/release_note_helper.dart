#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'lib/running_release_notes.dart';

final releaseNoteJsonPath =
    '../packages/devtools_app/lib/src/framework/release_notes/release_notes.json';

void main(List<String> args) {
  final runner = CommandRunner(
    'release_note_helper',
    'Helps manage version notes for release.',
  )..addCommand(VerifyCommand());

  runner.run(args).catchError((error) {
    if (error is! UsageException) throw error;
    print(error);
    exit(64); // Exit code 64 indicates a usage error.
  });
  return;
}

class VerifyCommand extends Command {
  @override
  final name = 'verify';
  @override
  final description =
      'Verifies that the release_notes.json file is still readable with the serializable dart classes.';

  VerifyCommand() {
    argParser.addOption(
      'file',
      abbr: 'f',
      mandatory: true,
      help:
          'The json release file to verify. The file will be decoded and parsed to ensure that it\'s format is still what is expected.',
    );
  }

  @override
  void run() async {
    final filePath = argResults!['file'].toString();
    print("The filepath $filePath");
    final file = await File(filePath).readAsString();
    // This step will fail if the json is not valid, or can't be unserialized
    ReleaseNotes.fromJson(jsonDecode(filePath));

    print('Release notes were successfully decoded and serialized');
  }
}
