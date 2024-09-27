// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import '../utils.dart';

// This script must be executed from the top level devtools/ directory.
// TODO(kenz): If changes are made to this script, first consider refactoring to
// use https://github.com/dart-lang/pubspec_parse.

// All other devtools_* pubspecs have their own versioning strategies, or do not
// have a version at all (in the case of devtools_test).
final _devtoolsAppPubspec =
    File(pathFromRepoRoot('packages/devtools_app/pubspec.yaml'));

final _releaseNoteDirPath =
    pathFromRepoRoot('packages/devtools_app/release_notes');

class UpdateDevToolsVersionCommand extends Command {
  UpdateDevToolsVersionCommand() {
    addSubcommand(ManualUpdateCommand());
    addSubcommand(AutoUpdateCommand());
    addSubcommand(CurrentVersionCommand());
  }

  @override
  String get name => 'update-version';

  @override
  String get description =>
      'Updates the main DevTools version and any packages that are versioned '
      'in lock-step.';
}

Future<void> performTheVersionUpdate({
  required String currentVersion,
  required String newVersion,
}) async {
  print(
    'Updating devtools_app/pubspec.yaml from $currentVersion to version '
    '$newVersion...',
  );
  writeVersionToPubspec(_devtoolsAppPubspec, newVersion);

  print('Updating devtools.dart to version $newVersion...');
  writeVersionToVersionFile(
    File(pathFromRepoRoot('packages/devtools_app/lib/devtools.dart')),
    newVersion,
  );
}

Future<void> resetReleaseNotes({
  required String version,
}) async {
  print('Resetting the release notes');
  // Clear out the current notes
  final imagesDir = Directory('$_releaseNoteDirPath/images');
  if (imagesDir.existsSync()) {
    await imagesDir.delete(recursive: true);
  }
  await imagesDir.create();
  await File('$_releaseNoteDirPath/images/.gitkeep').create();

  final currentReleaseNotesFile =
      File('$_releaseNoteDirPath/NEXT_RELEASE_NOTES.md');
  if (currentReleaseNotesFile.existsSync()) {
    await currentReleaseNotesFile.delete();
  }

  // Normalize the version number so that it onl
  final semVerMatch = RegExp(r'^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)')
      .firstMatch(version);
  if (semVerMatch == null) {
    throw 'Version format is unexpected';
  }
  final major = int.parse(semVerMatch.namedGroup('major')!, radix: 10);
  final minor = int.parse(semVerMatch.namedGroup('minor')!, radix: 10);
  final normalizedVersionNumber = '$major.$minor.0';

  final templateFile =
      File('$_releaseNoteDirPath/helpers/release_notes_template.md');
  final templateFileContents = await templateFile.readAsString();
  await currentReleaseNotesFile.writeAsString(
    templateFileContents.replaceAll(
      RegExp(r'<number>'),
      normalizedVersionNumber,
    ),
  );
}

String? incrementVersionByType(String version, String type) {
  final semVerMatch = RegExp(r'^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)')
      .firstMatch(version);
  if (semVerMatch == null) {
    throw 'Version format is unexpected';
  }
  var major = int.parse(semVerMatch.namedGroup('major')!, radix: 10);
  var minor = int.parse(semVerMatch.namedGroup('minor')!, radix: 10);
  var patch = int.parse(semVerMatch.namedGroup('patch')!, radix: 10);
  switch (type) {
    case 'major':
      major++;
      minor = 0;
      patch = 0;
      break;
    case 'minor':
      minor++;
      patch = 0;
      break;
    case 'patch':
      patch++;
      break;
    default:
      return null;
  }

  return '$major.$minor.$patch';
}

String? versionFromPubspecFile() {
  final lines = _devtoolsAppPubspec.readAsLinesSync();
  for (final line in lines) {
    if (line.startsWith(pubspecVersionPrefix)) {
      return line.substring(pubspecVersionPrefix.length).trim();
    }
  }
  return null;
}

void writeVersionToPubspec(File pubspec, String version) {
  final lines = pubspec.readAsLinesSync();
  final revisedLines = <String>[];
  String? currentSection = '';
  final sectionRegExp = RegExp('([a-z]|_)+:');
  for (var line in lines) {
    if (line.startsWith(sectionRegExp)) {
      // This is a top level section of the pubspec.
      currentSection = sectionRegExp.firstMatch(line)![0];
    }
    if (currentSection == pubspecVersionPrefix &&
        line.startsWith(pubspecVersionPrefix)) {
      line = [
        line.substring(
          0,
          line.indexOf(pubspecVersionPrefix) + pubspecVersionPrefix.length,
        ),
        ' $version',
      ].join();
    }
    revisedLines.add(line);
  }
  final content = revisedLines.joinWithNewLine();
  pubspec.writeAsStringSync(content);
}

void writeVersionToVersionFile(File versionFile, String version) {
  const prefix = 'const version = ';
  final lines = versionFile.readAsLinesSync();
  final revisedLines = <String>[];
  for (var line in lines) {
    if (line.startsWith(prefix)) {
      line = [prefix, '\'$version\';'].join();
    }
    revisedLines.add(line);
  }
  versionFile.writeAsStringSync(revisedLines.joinWithNewLine());
}

String incrementDevVersion(String currentVersion) {
  final alreadyHasDevVersion = isDevVersion(currentVersion);
  if (alreadyHasDevVersion) {
    final devVerMatch = RegExp(
      r'^(?<prefix>\d+\.\d+\.\d+.*-dev\.)(?<devVersion>\d+)(?<suffix>.*)$',
    ).firstMatch(currentVersion);

    if (devVerMatch == null) {
      throw 'Invalid version, could not increment dev version';
    } else {
      final prefix = devVerMatch.namedGroup('prefix')!;
      final devVersion = devVerMatch.namedGroup('devVersion')!;
      final suffix = devVerMatch.namedGroup('suffix')!;
      final bumpedDevVersion = int.parse(devVersion, radix: 10) + 1;
      final newVersion = '$prefix$bumpedDevVersion$suffix';

      return newVersion;
    }
  } else {
    return '$currentVersion-dev.0';
  }
}

String stripPreReleases(String currentVersion) {
  final devVerMatch =
      RegExp(r'^(?<semver>\d+\.\d+\.\d+).*$').firstMatch(currentVersion);
  if (devVerMatch == null) {
    throw 'Could not strip pre-releases from version: $currentVersion';
  } else {
    return devVerMatch.namedGroup('semver')!;
  }
}

bool isDevVersion(String version) {
  return RegExp(r'-dev\.\d+').hasMatch(version);
}

const pubspecVersionPrefix = 'version:';

class ManualUpdateCommand extends Command {
  ManualUpdateCommand() {
    argParser
      ..addOption(
        'new-version',
        abbr: 'n',
        mandatory: true,
        help: 'The new version code that devtools will be set to.',
      )
      ..addOption(
        'current-version',
        abbr: 'c',
        help: '''The current devtools version, this should be set to the version
          inside the index.html. This is only necessary to set this if automatic
          detection is failing.''',
      );
  }
  @override
  final name = 'manual';

  @override
  final description = 'Manually update devtools to a new version.';

  @override
  Future<void> run() async {
    final newVersion = argResults!['new-version'] as String;
    final currentVersion =
        (argResults!['current-version'] as String?) ?? versionFromPubspecFile();

    if (currentVersion == null) {
      throw 'Could not determine the version, please set the current-version or determine why getting the version is failing.';
    }

    await performTheVersionUpdate(
      currentVersion: currentVersion,
      newVersion: newVersion,
    );
  }
}

class CurrentVersionCommand extends Command {
  @override
  final name = 'current-version';

  @override
  final description = 'Print the current devtools_app version.';

  @override
  void run() async {
    print(versionFromPubspecFile());
  }
}

class AutoUpdateCommand extends Command {
  AutoUpdateCommand() {
    argParser
      ..addOption(
        'type',
        abbr: 't',
        allowed: ['release', 'dev', 'patch', 'minor', 'major'],
        allowedHelp: {
          'release': [
            'strips any pre-release versions from the version.',
            'Examples:',
            '\t1.2.3       => 1.2.3',
            '\t1.2.3-dev.4 => 1.2.3',
          ].join('\n'),
          'dev': [
            'bumps the version to the next dev pre-release value (minor by default).',
            'Examples:',
            '\t1.2.3       => 1.2.3-dev.0',
            '\t1.2.3-dev.4 => 1.2.3-dev.5',
          ].join('\n'),
          'patch': [
            'bumps the version to the next patch value.',
            'Examples:',
            '\t1.2.3       => 1.2.4',
            '\t1.2.3-dev.4 => 1.2.4',
          ].join('\n'),
          'minor': [
            'bumps the version to the next minor value.',
            'Examples:',
            '\t1.2.3       => 1.3.0',
            '\t1.2.3-dev.4 => 1.3.0',
          ].join('\n'),
          'major': [
            'bumps the version to the next major value.',
            'Examples:',
            '\t1.2.3       => 2.0.0',
            '\t1.2.3-dev.4 => 2.0.0',
          ].join('\n'),
        },
        mandatory: true,
        help: 'Bumps the devtools version by the selected type.',
      )
      ..addFlag(
        'dry-run',
        abbr: 'd',
        defaultsTo: false,
        help:
            'Displays the version change that would happen, without performing '
            'it.',
      );
  }

  @override
  final name = 'auto';

  @override
  final description = 'Automatically update devtools to a new version.';

  @override
  Future<void> run() async {
    final type = argResults!['type'] as String;
    final isDryRun = argResults!['dry-run'] as bool;
    final currentVersion = versionFromPubspecFile();
    String? newVersion;
    if (currentVersion == null) {
      throw 'Could not automatically determine current version.';
    }
    switch (type) {
      case 'release':
        newVersion = stripPreReleases(currentVersion);
        break;
      case 'dev':
        newVersion = incrementDevVersion(currentVersion);
        break;
      default:
        newVersion = incrementVersionByType(currentVersion, type);
        if (newVersion == null) {
          throw 'Failed to determine the newVersion.';
        }
    }
    print('Bump version from $currentVersion to $newVersion');

    if (isDryRun) {
      return;
    }

    await performTheVersionUpdate(
      currentVersion: currentVersion,
      newVersion: newVersion,
    );
    if (['minor', 'major'].contains(type)) {
      // Only cycle the release notes when doing a minor or major version bump
      await resetReleaseNotes(
        version: newVersion,
      );
    }
  }
}
