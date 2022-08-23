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

void main(List<String> args) async {
  final runner = CommandRunner(
    'update_version.dart',
    'A program for updating the devtools version',
  )
    ..addCommand(ManualUpdateCommand())
    ..addCommand(AutoUpdateCommand());
  runner.run(args).catchError((error) {
    if (error is! UsageException) throw error;
    print(error);
    exit(64); // Exit code 64 indicates a usage error.
  });
  return;
}

Future<void> performTheVersionUpdate(
    {required String currentVersion, required String newVersion}) async {
  print('Updating pubspecs from $currentVersion to version $newVersion...');

  for (final pubspec in _pubspecs) {
    writeVersionToPubspec(pubspec, newVersion);
  }

  print('Updating devtools.dart to version $newVersion...');
  writeVersionToVersionFile(
    File('packages/devtools_app/lib/devtools.dart'),
    newVersion,
  );

  print('Updating CHANGELOG to version $newVersion...');
  writeVersionToChangelog(File('CHANGELOG.md'), newVersion);

  print('Updating index.html to version $newVersion...');
  writeVersionToIndexHtml(
      File('packages/devtools_app/web/index.html'), currentVersion, newVersion);

  final process = await Process.start('./tool/pub_upgrade.sh', []);
  process.stdout.asBroadcastStream().listen((event) {
    print(utf8.decode(event));
  });
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
    'TODO: update changelog\n',
    ...lines,
  ].joinWithNewLine());
}

void writeVersionToIndexHtml(
  File indexHtml,
  String oldVersion,
  String newVersion,
) {
  var updatedVersion = false;
  final lines = indexHtml.readAsLinesSync();
  final revisedLines = <String>[];
  for (final line in lines) {
    if (line.contains(oldVersion)) {
      final versionStart = line.indexOf(oldVersion);
      final lineSegmentBefore = line.substring(0, versionStart);
      final lineSegmentAfter = line.substring(versionStart + oldVersion.length);
      final newLine = '$lineSegmentBefore$newVersion$lineSegmentAfter';
      revisedLines.add(newLine);
      updatedVersion = true;
    } else {
      revisedLines.add(line);
    }
  }
  if (!updatedVersion) {
    throw Exception('Unable to update version in index.html');
  }
  indexHtml.writeAsStringSync(revisedLines.joinWithNewLine());
}

String incrementDevVersion(String currentVersion) {
  final alreadyHasDevVersion = RegExp(r'-dev\.\d+').hasMatch(currentVersion);
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
    if (argResults!['help'] != null) return;
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

class AutoUpdateCommand extends Command {
  @override
  final name = 'auto';
  @override
  final description = 'Automatically update devtools to a new version.';

  AutoUpdateCommand() {
    argParser.addOption('type',
        abbr: 't',
        allowed: ['dev', 'patch', 'minor', 'major'],
        allowedHelp: {
          'dev': 'bumps the version to the next dev pre-release value',
          'patch': 'bumps the version to the next patch value',
          'minor': 'bumps the version to the next minor value',
          'major': 'bumps the version to the next major value',
        },
        mandatory: true,
        help: 'Bumps the devtools version by the selected type.');
  }

  @override
  void run() {
    if (argResults!['help'] != null) return;
    final type = argResults!['type'].toString();
    final currentVersion = versionFromPubspecFile();
    String? newVersion;
    if (currentVersion == null) {
      throw 'Could not automatically determine current version.';
    }
    switch (type) {
      case 'dev':
        newVersion = incrementDevVersion(currentVersion);
        break;
      default:
        newVersion = incrementVersionByType(currentVersion, type);
    }
    if (newVersion == null) {
      throw 'Failed to determine the newVersion.';
    }
    performTheVersionUpdate(
      currentVersion: currentVersion,
      newVersion: newVersion,
    );
  }
}
