// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

// This script must be executed from the top level devtools/ directory.
// TODO(kenz): If changes are made to this script, first consider refactoring to
// use https://github.com/dart-lang/pubspec_parse.

final _pubspecs = [
  'packages/devtools_app/pubspec.yaml',
  'packages/devtools_test/pubspec.yaml',
  'packages/devtools_shared/pubspec.yaml',
].map((path) => File(path)).toList();
const _releaseNoteDirPath = './packages/devtools_app/release_notes';

void main(List<String> args) async {
  final runner = CommandRunner(
    'update_version.dart',
    'A program for updating the devtools version',
  )
    ..addCommand(ManualUpdateCommand())
    ..addCommand(AutoUpdateCommand())
    ..addCommand(CurrentVersionCommand());
  runner.run(args).catchError((error) {
    if (error is! UsageException) throw error;
    print(error);
    exit(64); // Exit code 64 indicates a usage error.
  });
  return;
}

Future<void> performTheVersionUpdate({
  required String currentVersion,
  required String newVersion,
  bool modifyChangeLog = true,
}) async {
  print('Updating pubspecs from $currentVersion to version $newVersion...');

  for (final pubspec in _pubspecs) {
    writeVersionToPubspec(pubspec, newVersion);
  }

  print('Updating devtools.dart to version $newVersion...');
  writeVersionToVersionFile(
    File('packages/devtools_app/lib/devtools.dart'),
    newVersion,
  );

  if (modifyChangeLog) {
    print('Updating CHANGELOG to version $newVersion...');
    writeVersionToChangelog(File('CHANGELOG.md'), newVersion);
  }

  final process = await Process.start('./tool/pub_upgrade.sh', []);
  process.stdout.asBroadcastStream().listen((event) {
    print(utf8.decode(event));
  });
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
  imagesDir.create();
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
  var major = int.parse(semVerMatch.namedGroup('major')!, radix: 10);
  var minor = int.parse(semVerMatch.namedGroup('minor')!, radix: 10);
  final normalizedVersionNumber = '$major.$minor.0';

  final templateFile =
      File('$_releaseNoteDirPath/helpers/release_notes_template.md');
  final templateFileContents = await templateFile.readAsString();
  currentReleaseNotesFile.writeAsString(
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
  final pubspec = _pubspecs.first;
  final lines = pubspec.readAsLinesSync();
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
    if (editablePubspecSections.contains(currentSection)) {
      if (line.startsWith(pubspecVersionPrefix)) {
        line = [
          line.substring(
            0,
            line.indexOf(pubspecVersionPrefix) + pubspecVersionPrefix.length,
          ),
          ' $version',
        ].join();
      } else {
        for (final prefix in devToolsDependencyPrefixes) {
          if (line.contains(prefix)) {
            line = [
              line.substring(0, line.indexOf(prefix) + prefix.length),
              version,
            ].join();
            break;
          }
        }
      }
    }
    revisedLines.add(line);
  }
  final content = revisedLines.joinWithNewLine();
  pubspec.writeAsStringSync(content);
}

void writeVersionToVersionFile(File versionFile, String version) {
  const prefix = 'const String version = ';
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

void writeVersionToChangelog(File changelog, String version) {
  final lines = changelog.readAsLinesSync();
  final versionString = '## $version';
  if (lines.first.endsWith(versionString)) {
    print('Changelog already has an entry for version $version');
    return;
  }
  changelog.writeAsString([
    versionString,
    isDevVersion(version) ? '* Dev version\n' : 'TODO: update changelog\n',
    ...lines,
  ].joinWithNewLine());
}

String incrementDevVersion(String currentVersion) {
  final alreadyHasDevVersion = isDevVersion(currentVersion);
  if (alreadyHasDevVersion) {
    final devVerMatch = RegExp(
            r'^(?<prefix>\d+\.\d+\.\d+.*-dev\.)(?<devVersion>\d+)(?<suffix>.*)$')
        .firstMatch(currentVersion);

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
const editablePubspecSections = [
  pubspecVersionPrefix,
  'dependencies:',
  'dev_dependencies:',
];

const devToolsDependencyPrefixes = [
  'devtools_app: ',
  'devtools_test: ',
  'devtools_shared: ',
];

extension JoinExtension on List<String> {
  String joinWithNewLine() {
    return '${join('\n')}\n';
  }
}

class ManualUpdateCommand extends Command {
  @override
  final name = 'manual';
  @override
  final description = 'Manually update devtools to a new version.';

  ManualUpdateCommand() {
    argParser.addOption(
      'new-version',
      abbr: 'n',
      mandatory: true,
      help: 'The new version code that devtools will be set to.',
    );
    argParser.addOption(
      'current-version',
      abbr: 'c',
      help: '''The current devtools version, this should be set to the version
          inside the index.html. This is only necessary to set this if automatic
          detection is failing.''',
    );
  }

  @override
  void run() {
    final newVersion = argResults!['new-version'].toString();
    final currentVersion =
        argResults!['current-version']?.toString() ?? versionFromPubspecFile();

    if (currentVersion == null) {
      throw 'Could not determine the version, please set the current-version or determine why getting the version is failing.';
    }

    performTheVersionUpdate(
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
  @override
  final name = 'auto';
  @override
  final description = 'Automatically update devtools to a new version.';
  AutoUpdateCommand() {
    argParser.addOption(
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
    );
    argParser.addFlag(
      'dry-run',
      abbr: 'd',
      defaultsTo: false,
      help: 'Displays the version change that would happen, without performing '
          'it.',
    );
  }

  @override
  void run() async {
    final type = argResults!['type'].toString();
    final isDryRun = argResults!['dry-run'];
    final currentVersion = versionFromPubspecFile();
    bool modifyChangeLog = false;
    String? newVersion;
    if (currentVersion == null) {
      throw 'Could not automatically determine current version.';
    }
    switch (type) {
      case 'release':
        newVersion = stripPreReleases(currentVersion);
        modifyChangeLog = true;
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

    performTheVersionUpdate(
      currentVersion: currentVersion,
      newVersion: newVersion,
      modifyChangeLog: modifyChangeLog,
    );
    if (['minor', 'major'].contains(type)) {
      // Only cycle the release notes when doing a minor or major version bump
      resetReleaseNotes(
        version: newVersion,
      );
    }
  }
}
