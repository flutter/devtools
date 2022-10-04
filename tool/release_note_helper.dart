#!/usr/bin/env dart

import 'dart:convert';

import 'lib/running_release_notes.dart';

void main() {
  final inspectorSection = 'Inspector updates';
  final performanceSection = 'Performance updates';
  final cpuSection = 'CPU profiler updates';
  final memorySection = 'Memory updates';

  final releaseVersion = ReleaseVersion(
    version: SemanticVersion(
      major: 2,
      minor: 3,
      patch: 4,
    ),
    sections: [
      ReleaseSection.emptyNotes(name: inspectorSection),
      ReleaseSection.emptyNotes(name: performanceSection),
      ReleaseSection.emptyNotes(name: cpuSection),
      ReleaseSection.emptyNotes(name: memorySection),
    ],
  );
  releaseVersion.addNote(
    inspectorSection,
    ReleaseNote(
      message: 'This is an inspector note',
      githubPullRequestUrl: 'https://github.com/flutter/devtools/pull/4553',
    ),
  );
  releaseVersion.addNote(
    inspectorSection,
    ReleaseNote(message: 'This is a 2nd inspector note'),
  );
  releaseVersion.addNote(
    performanceSection,
    ReleaseNote(message: 'This is a performance note'),
  );
  releaseVersion.addNote(
    cpuSection,
    ReleaseNote(message: 'This is a cpu note'),
  );
  releaseVersion.addNote(
    memorySection,
    ReleaseNote(message: 'This is a memory note'),
  );

  print(releaseVersion.toMarkdown());
  print('JSON');
  JsonEncoder encoder = JsonEncoder.withIndent('  ');
  String jsonString = encoder.convert(releaseVersion);
  print(jsonString);
  print('\n\n\nELLLALAAAAA');
  final releaseVersionMap = jsonDecode(jsonString);
  print(releaseVersionMap);
  print('----------');
  print(ReleaseVersion.fromJson(jsonDecode(jsonString)).toMarkdown());
}
