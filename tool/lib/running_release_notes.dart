import 'package:json_annotation/json_annotation.dart';

part 'running_release_notes.g.dart';

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

  factory Release.fromJson(Map<String, dynamic> json) =>
      _$ReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseToJson(this);
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
    this.githubPullRequestUrl,
  });
  // TODO add ability to add image

  final String? githubPullRequestUrl;
  final String message;

  factory ReleaseNote.fromJson(Map<String, dynamic> json) =>
      _$ReleaseNoteFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseNoteToJson(this);
}
// # Sementic line breaks of 80 chars or fewer
// # each line requires an PR command
