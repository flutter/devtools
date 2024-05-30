// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:devtools_tool/model.dart';
import 'package:devtools_tool/utils.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;

class ReleaseNotesCommand extends Command {
  ReleaseNotesCommand() {
    argParser
      ..addOption(
        _websiteRepoPath,
        abbr: 'w',
        help: 'The absolute path to the flutter/website repo clone on disk.',
      )
      ..addFlag(
        _useCurrentBranch,
        abbr: 'c',
        help: 'Whether to use the current branch on the local flutter/website '
            'checkout instead of creating a new one.',
      );
  }

  static const _websiteRepoPath = 'website-repo';
  static const _useCurrentBranch = 'use-current-branch';

  @override
  String get description =>
      'Creates a PR on the flutter/website repo with the current release notes.';

  @override
  String get name => 'release-notes';

  @override
  FutureOr? run() async {
    final log = Logger.standard();
    final processManager = ProcessManager();

    final devToolsReleaseNotesDirectory = Directory(
      p.join(
        DevToolsRepo.getInstance().devtoolsAppDirectoryPath,
        'release_notes',
      ),
    );
    final devToolsReleaseNotes = _DevToolsReleaseNotes.fromFile(
      File(p.join(devToolsReleaseNotesDirectory.path, 'NEXT_RELEASE_NOTES.md')),
    );
    final releaseNotesVersion = devToolsReleaseNotes.version;
    log.stdout(
      'Drafting release notes for DevTools version $releaseNotesVersion...',
    );

    // Maybe create a new branch on the flutter/website repo.
    final websiteRepoPath = argResults![_websiteRepoPath] as String;
    final useCurrentBranch = argResults![_useCurrentBranch] as bool;
    if (!useCurrentBranch) {
      try {
        await processManager.runAll(
          commands: [
            CliCommand.git(['stash']),
            CliCommand.git(['checkout', 'main']),
            CliCommand.git(['pull']),
            CliCommand.git(['submodule', 'update', '--init', '--recursive']),
            CliCommand.git(
              ['checkout', '-b', 'devtools-release-notes-$releaseNotesVersion'],
            ),
          ],
          workingDirectory: websiteRepoPath,
        );
      } catch (e) {
        log.stderr(
          'Something went wrong while trying to prepare a branch on the '
          'flutter/website repo. Please make sure your flutter/website clone '
          'is set up as specified by the contributing instructions: '
          'https://github.com/flutter/website?tab=readme-ov-file#contributing.'
          '\n\n$e',
        );
        return;
      }
    }

    final websiteReleaseNotesDir = Directory(
      p.join(
        websiteRepoPath,
        'src',
        'content',
        'tools',
        'devtools',
        'release-notes',
      ),
    );
    if (!websiteReleaseNotesDir.existsSync()) {
      throw FileSystemException(
        'Website release notes directory does not exist.',
        websiteReleaseNotesDir.path,
      );
    }

    // Write the 'release-notes-<x.y.z>.md' file.
    File(
      p.join(
        websiteReleaseNotesDir.path,
        'release-notes-$releaseNotesVersion.md',
      ),
    )
      ..createSync()
      ..writeAsStringSync(
        '''---
short-title: $releaseNotesVersion release notes
description: Release notes for Dart and Flutter DevTools version $releaseNotesVersion.
toc: false
---

{% include ./release-notes-$releaseNotesVersion-src.md %}
''',
        flush: true,
      );

    // Create the 'release-notes-<x.y.z>-src.md' file.
    final releaseNotesSrcMd = File(
      p.join(
        websiteReleaseNotesDir.path,
        'release-notes-$releaseNotesVersion-src.md',
      ),
    )..createSync();

    final srcLines = devToolsReleaseNotes.srcLines;

    // Copy release notes images and fix image reference paths.
    if (devToolsReleaseNotes.imageLineIndices.isNotEmpty) {
      // This set of release notes contains images. Perform the line
      // transformations and copy the image files.
      final websiteImagesDirName = 'images-$releaseNotesVersion';
      final devtoolsImagesDir =
          Directory(p.join(devToolsReleaseNotesDirectory.path, 'images'));
      final websiteImagesDir = Directory(
        p.join(websiteReleaseNotesDir.path, websiteImagesDirName),
      )..createSync();
      await copyPath(devtoolsImagesDir.path, websiteImagesDir.path);

      // Remove the .gitkeep file that was copied over.
      File(p.join(websiteImagesDir.path, '.gitkeep')).deleteSync();

      for (final index in devToolsReleaseNotes.imageLineIndices) {
        final line = srcLines[index];
        final transformed = line.replaceFirst(
          _DevToolsReleaseNotes._imagePathMarker,
          '/tools/devtools/release-notes/$websiteImagesDirName',
        );
        srcLines[index] = transformed;
      }
    }

    // Write the 'release-notes-<x.y.z>-src.md' file, including any updates for
    // image paths.
    releaseNotesSrcMd.writeAsStringSync(
      srcLines.joinWithNewLine(),
      flush: true,
    );

    // Write the 'devtools_releases.yml' file.
    final releasesYml =
        File(p.join(websiteRepoPath, 'src', '_data', 'devtools_releases.yml'));
    if (!releasesYml.existsSync()) {
      throw FileSystemException(
        'The devtools_releases.yml file does not exist.',
        releasesYml.path,
      );
    }
    final releasesYmlContent =
        releasesYml.readAsStringSync().replaceFirst('releases:', '''releases:
  - '$releaseNotesVersion\'''');
    releasesYml.writeAsStringSync(releasesYmlContent, flush: true);

    const firstPartInstructions =
        'Release notes successfully drafted in a local flutter/website branch. '
        'Please clean them up by deleting empty sections and fixing any '
        'grammar mistakes or typos. Run the following to open the release '
        'notes source file:';
    log.stdout(
      '''
$firstPartInstructions

cd $websiteRepoPath;
code ${releaseNotesSrcMd.absolute.path}

Create a PR on the flutter/website repo when you are finished.
''',
    );
  }
}

class _DevToolsReleaseNotes {
  _DevToolsReleaseNotes._({
    required this.file,
    required this.version,
    required this.srcLines,
    required this.imageLineIndices,
  });

  factory _DevToolsReleaseNotes.fromFile(File file) {
    if (!file.existsSync()) {
      throw FileSystemException(
        'NEXT_RELEASE_NOTES.md file does not exist.',
        file.path,
      );
    }

    final rawLines = file.readAsLinesSync();

    late String version;
    late int titleLineIndex;
    final versionRegExp = RegExp(r"\d+\.\d+\.\d+");
    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final matches = versionRegExp.allMatches(line);
      if (matches.isEmpty) continue;
      // This match should be from the line "# DevTools <x.y.z> release notes".
      version = matches.first.group(0)!;
      // This is the markdown title where the release notes src begins.
      titleLineIndex = i;
      break;
    }

    // TODO(kenz): one nice polish task could be to remove sections that are
    // empty (i.e. sections that have the line
    // "TODO: Remove this section if there are not any general updates.").
    final srcLines = rawLines.sublist(titleLineIndex);
    final imageLineIndices = <int>{};
    for (int i = 0; i < srcLines.length; i++) {
      final line = srcLines[i];
      if (line.contains(_imagePathMarker)) {
        imageLineIndices.add(i);
      }
    }

    return _DevToolsReleaseNotes._(
      file: file,
      version: version,
      srcLines: srcLines,
      imageLineIndices: imageLineIndices,
    );
  }

  final File file;
  final String version;
  final List<String> srcLines;
  final Set<int> imageLineIndices;

  static final _imagePathMarker = RegExp(r'images\/.*\.png');
}
