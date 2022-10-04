#!/usr/bin/env dart

import 'package:json_annotation/json_annotation.dart';

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
      ReleaseSection(name: inspectorSection),
      ReleaseSection(name: performanceSection),
      ReleaseSection(name: cpuSection),
      ReleaseSection(name: memorySection),
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
}

@JsonSerializable()
class ReleaseVersion {
  ReleaseVersion({
    required this.version,
    List<ReleaseSection>? sections,
  }) {
    sections?.forEach((section) => _sections[section.name] = section);
  }

  final Map<String, ReleaseSection> _sections = {};
  final SemanticVersion version;
  void addNote(
    String sectionName,
    ReleaseNote note,
  ) {
    _sections[sectionName]!.notes.add(note);
  }

  String toMarkdown() {
    String markdown = '';
    markdown += '# DevTools $version release notes\n\n';
    _sections.forEach((_, section) {
      markdown += '# ${section.name}\n\n';
      for (var note in section.notes) {
        markdown += '- ${note.message}';
        if (note.githubPullRequestUrl != null) {
          markdown += ' - ${note.githubPullRequestUrl}';
        }
        markdown += '\n';
      }
      markdown += '\n';
    });
    return markdown;
  }
}

@JsonSerializable()
class SemanticVersion {
  SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.pre,
  });
  final int major;
  final int minor;
  final int patch;
  final String? pre;
  @override
  String toString() {
    String versionString = '$major.$minor.$patch';
    if (pre != null) {
      versionString += '-$pre';
    }
    return versionString;
  }
}

@JsonSerializable()
class ReleaseSection {
  ReleaseSection({
    required this.name,
    List<ReleaseNote>? notes,
  }) : notes = notes ?? [];

  final String name;
  final List<ReleaseNote> notes;
}

@JsonSerializable()
class ReleaseNote {
  ReleaseNote({
    required this.message,
    this.githubPullRequestUrl,
  });

  final String? githubPullRequestUrl;
  final String message;
}
// # Sementic line breaks of 80 chars or fewer
// # each line requires an PR command
