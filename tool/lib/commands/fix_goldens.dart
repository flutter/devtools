// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import '../utils.dart';

const _runIdArg = 'run-id';

/// A command for downloading and applying golden fixes, when they are broken.
class FixGoldensCommand extends Command {
  FixGoldensCommand() {
    argParser.addOption(
      _runIdArg,
      help: 'The ID of the workflow run where the goldens are failing. '
          'e.g.https://github.com/flutter/devtools/actions/runs/<run-id>/job/16691428186',
      valueHelp: '12345',
      mandatory: true,
    );
  }
  @override
  String get description =>
      'A command for downloading and applying golden fixes when they are broken on the CI.';

  @override
  String get name => 'fix-goldens';

  final processManager = ProcessManager();

  @override
  FutureOr? run() async {
    // Change the CWD to the repo root
    Directory.current = pathFromRepoRoot("");

    final runId = argResults![_runIdArg] as String;
    final tmpDownloadDir = await Directory.systemTemp.createTemp();
    try {
      print('Downloading the artifacts to ${tmpDownloadDir.path}');
      await processManager.runProcess(
        CliCommand(
          'gh',
          [
            'run',
            'download',
            runId,
            '-p',
            '*golden_image_failures*',
            '-R',
            'github.com/flutter/devtools',
            '-D',
            tmpDownloadDir.path,
          ],
        ),
      );

      final downloadedGoldens = tmpDownloadDir
          .listSync(recursive: true)
          .where((e) => e.path.endsWith('testImage.png'));
      final allLocalGoldenPngs =
          Directory(pathFromRepoRoot("packages/devtools_app/test/"))
              .listSync(recursive: true)
            ..where((e) => e.path.endsWith('.png'));

      for (final downloadedGolden in downloadedGoldens) {
        final downloadedGoldenBaseName = path.basename(downloadedGolden.path);
        final expectedGoldenFileName =
            '${RegExp(r'(^.*)_testImage.png').firstMatch(downloadedGoldenBaseName)?.group(1)}.png';

        final fileMatches = allLocalGoldenPngs.where(
          (e) => e.path.endsWith(expectedGoldenFileName),
        );

        final String destinationPath;
        if (fileMatches.isEmpty) {
          throw 'Could not find a golden Image for $downloadedGoldenBaseName using $expectedGoldenFileName as '
              'the name of the search.';
        } else if (fileMatches.length == 1) {
          destinationPath = fileMatches.first.path;
        } else {
          print("Multiple goldens found for ${downloadedGolden.path}");
          print("Select which golden should be overridden:");

          for (int i = 0; i < fileMatches.length; i++) {
            final fileMatch = fileMatches.elementAt(i);
            print('${i + 1}) ${fileMatch.path}');
          }

          final userSelection = int.parse(stdin.readLineSync()!);

          destinationPath = fileMatches.elementAt(userSelection - 1).path;
        }
        await downloadedGolden.rename(destinationPath);

        print("Fixed: $destinationPath");
      }

      print('Done updating ${downloadedGoldens.length} goldens');
    } finally {
      tmpDownloadDir.deleteSync(recursive: true);
    }
  }
}
