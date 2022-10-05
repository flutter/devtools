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
      minor: 18,
      patch: 0,
    ),
    sections: [
      ReleaseSection.emptyNotes(name: inspectorSection),
      ReleaseSection.emptyNotes(name: performanceSection),
      // ReleaseSection.emptyNotes(name: cpuSection),
      // ReleaseSection.emptyNotes(name: memorySection),
    ],
  );
  releaseVersion.addNote(
    inspectorSection,
    ReleaseNote(
      message:
          'Auto scrolling behavior improved when snapping to a widget into focus',
      githubPullRequestUrl: 'https://github.com/flutter/devtools/pull/4283',
    ),
  );
  releaseVersion.addNote(
    inspectorSection,
    ReleaseNote(
      message:
          'Fix issue where widget inspector wouldn\'t load when connecting to a paused  app',
      githubPullRequestUrl: 'https://github.com/flutter/devtools/pull/4527',
    ),
  );
  releaseVersion.addNote(
    inspectorSection,
    ReleaseNote(
      message:
          'Improve widget inspector hover cards to show progress while waiting for data',
      githubPullRequestUrl: 'https://github.com/flutter/devtools/pull/4488',
    ),
  );
  releaseVersion.addNote(
    performanceSection,
    ReleaseNote(
      message:
          'Fix issue where scrollbar would go out of sync with the frame content',
      githubPullRequestUrl: 'https://github.com/flutter/devtools/pull/4503',
    ),
  );
  releaseVersion.addNote(
    performanceSection,
    ReleaseNote(
      message: 'Add offline support for raster stats',
      githubPullRequestUrl: 'https://github.com/flutter/devtools/pull/4491',
    ),
  );
  releaseVersion.addNote(
    performanceSection,
    ReleaseNote(
      message: "Add 'Rendering time' column to Raster Metrics tab",
      githubPullRequestUrl: 'https://github.com/flutter/devtools/pull/4474',
    ),
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
