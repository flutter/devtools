import 'package:json_annotation/json_annotation.dart';

part 'running_release_notes.g.dart';

@JsonSerializable()
class ReleaseVersion {
  ReleaseVersion({
    required this.version,
    required this.sections,
  });

  ReleaseVersion.sectionsList({
    required this.version,
    required List<ReleaseSection> sectionsList,
  }) {
    for (var section in sectionsList) {
      sections[section.name] = section;
    }
  }

  Map<String, ReleaseSection> sections = {};
  final SemanticVersion version;
  void addNote(
    String sectionName,
    ReleaseNote note,
  ) {
    sections[sectionName]!.notes.add(note);
  }

  String toMarkdown() {
    String markdown = '';
    markdown += '# DevTools $version release notes\n\n';
    sections.forEach((_, section) {
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

  factory ReleaseVersion.fromJson(Map<String, dynamic> json) =>
      _$ReleaseVersionFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseVersionToJson(this);
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

  factory SemanticVersion.fromJson(Map<String, dynamic> json) =>
      _$SemanticVersionFromJson(json);

  Map<String, dynamic> toJson() => _$SemanticVersionToJson(this);
}

@JsonSerializable()
class ReleaseSection {
  ReleaseSection({
    required this.name,
    required this.notes,
  });

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
    required this.githubPullRequestUrl,
  });
  ReleaseNote.noGithubUrl({
    required this.message,
  }) : githubPullRequestUrl = null;

  final String? githubPullRequestUrl;
  final String message;

  factory ReleaseNote.fromJson(Map<String, dynamic> json) =>
      _$ReleaseNoteFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseNoteToJson(this);
}
// # Sementic line breaks of 80 chars or fewer
// # each line requires an PR command
