// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

// This script must be executed from the top level devtools/ directory.
// TODO(kenz): If changes are made to this script, first consider refactoring to
// use https://github.com/dart-lang/pubspec_parse.

void main(List<String> args) async {
  final pubspecs = [
    'packages/devtools_app/pubspec.yaml',
    'packages/devtools_test/pubspec.yaml',
    'packages/devtools_shared/pubspec.yaml',
  ].map((path) => File(path)).toList();

  final currentVersion = args.isNotEmpty && args.length > 1
      ? args[1]
      : versionFromPubspecFile(pubspecs.first);

  if (currentVersion == null) {
    print('Could not resolve current version number. Please explicitly pass in '
        'the current version as the second argument, eg'
        'dart tool/update_version.dart 2.7.1 2.7.0');
    return;
  }

  final version =
      args.isNotEmpty ? args.first : incrementVersion(currentVersion);

  if (version == null) {
    print('Something went wrong. Could not resolve version number.');
    return;
  }

  print('Updating pubspecs to version $version...');
  for (final pubspec in pubspecs) {
    writeVersionToPubspec(pubspec, version);
  }

  print('Updating devtools.dart to version $version...');
  writeVersionToVersionFile(
    File('packages/devtools_app/lib/devtools.dart'),
    version,
  );

  print('Updating CHANGELOG to version $version...');
  writeVersionToChangelog(File('CHANGELOG.md'), version);

  print('Updating index.html to version $version...');
  writeVersionToIndexHtml(
      File('packages/devtools_app/web/index.html'), currentVersion, version);

  final process = await Process.start('./tool/pub_upgrade.sh', []);
  process.stdout.asBroadcastStream().listen((event) {
    print(utf8.decode(event));
  });
}

String? incrementVersion(String oldVersion) {
  final semVer = RegExp(r'[0-9]+\.[0-9]\.[0-9]+').firstMatch(oldVersion)![0];

  const devTag = '-dev';
  final isDevVersion = oldVersion.contains(devTag);
  if (isDevVersion) {
    return semVer;
  }

  final parts = semVer!.split('.');

  // Versions should have the form 'x.y.z'.
  if (parts.length != 3) return null;

  final patch = int.parse(parts.last);
  final nextPatch = patch + 1;
  return [parts[0], parts[1], nextPatch].join('.');
}

String? versionFromPubspecFile(File pubspec) {
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
