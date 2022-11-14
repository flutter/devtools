import 'dart:io';

import 'package:devtools_repo/repo_tool.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:json_annotation/json_annotation.dart';

part 'release_note_classes.g.dart';

@JsonSerializable()
class ReleaseNotes {
  ReleaseNotes({
    required this.releases,
  });

  List<Release> releases;

  String toMarkdown() {
    String markdown = '';
    for (var release in releases) {
      markdown += release.toMarkdown();
      markdown += '\n';
    }
    return markdown;
  }

  factory ReleaseNotes.fromJson(Map<String, dynamic> json) =>
      _$ReleaseNotesFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseNotesToJson(this);
}

@JsonSerializable()
class Release {
  Release({
    required this.version,
    required this.sections,
  }) {
    for (var element in sections) {
      _sectionMap[element.name] = element;
    }
  }

  final SemanticVersion version;
  List<ReleaseSection> sections = [];
  final Map<String, ReleaseSection> _sectionMap = {};

  void addNote(String sectionName, ReleaseNote note) {
    _sectionMap[sectionName]!.notes.add(note);
  }

  String toMarkdown() {
    String markdown = '';
    markdown += '# DevTools $version release notes\n\n';
    sections.forEach((section) {
      markdown += '# ${section.name}\n\n';
      for (var note in section.notes) {
        markdown += note.toMarkdown();
      }
      markdown += '\n';
    });
    return markdown;
  }

  factory Release.fromJson(Map<String, dynamic> json) =>
      _$ReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseToJson(this);
}

@JsonSerializable()
class ReleaseSection {
  ReleaseSection({
    required this.name,
    List<ReleaseNote>? notes,
  }) : notes = notes ?? [];

  ReleaseSection.emptyNotes({
    required this.name,
  }) : notes = [];

  final String name;
  final List<ReleaseNote> notes;

  factory ReleaseSection.fromJson(Map<String, dynamic> json) =>
      _$ReleaseSectionFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseSectionToJson(this);
}

@JsonSerializable()
class ReleaseNote {
  ReleaseNote({
    required this.message,
    this.imageNames,
    this.githubPullRequestUrls,
  }) {
    if (imageNames != null) {
      for (var name in imageNames!) {
        final path = "release_notes/files/$name";
        //TODO: get the proper path?
        if (!File(path).existsSync()) {
          throw Exception(
              "Could not find image file $path for note: \n${toMarkdown()}");
        }
      }
    }
  }

  List<String>? githubPullRequestUrls;
  final String message;
  final List<String>? imageNames;

  String toMarkdown() {
    String markdown = '';
    markdown += '- $message';
    if (githubPullRequestUrls != null) {
      List<String> prUrls = [];
      for (var url in githubPullRequestUrls!) {
        final match = RegExp(
                r'^https://github.com/flutter/devtools/pull/(?<pr_number>\d+)$')
            .firstMatch(url);
        final prNumber = match!.namedGroup('pr_number');
        prUrls.add('[#$prNumber]($url)');
      }
      markdown += ' - [](${prUrls.join(", ")})';
    }

    markdown += '\n';

    if (imageNames != null) {
      for (var imageName in imageNames!) {
        markdown += '![](files/$imageName)\n';
      }
    }

    return markdown;
  }

  factory ReleaseNote.fromJson(Map<String, dynamic> json) =>
      _$ReleaseNoteFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseNoteToJson(this);
}
// # Sementic line breaks of 80 chars or fewer
// # each line requires an PR command
