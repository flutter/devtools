// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'running_release_notes.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReleaseVersion _$ReleaseVersionFromJson(Map<String, dynamic> json) =>
    ReleaseVersion(
      version:
          SemanticVersion.fromJson(json['version'] as Map<String, dynamic>),
      sections: (json['sections'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, ReleaseSection.fromJson(e as Map<String, dynamic>)),
      ),
    );

Map<String, dynamic> _$ReleaseVersionToJson(ReleaseVersion instance) =>
    <String, dynamic>{
      'sections': instance.sections,
      'version': instance.version,
    };

SemanticVersion _$SemanticVersionFromJson(Map<String, dynamic> json) =>
    SemanticVersion(
      major: json['major'] as int,
      minor: json['minor'] as int,
      patch: json['patch'] as int,
      pre: json['pre'] as String?,
    );

Map<String, dynamic> _$SemanticVersionToJson(SemanticVersion instance) =>
    <String, dynamic>{
      'major': instance.major,
      'minor': instance.minor,
      'patch': instance.patch,
      'pre': instance.pre,
    };

ReleaseSection _$ReleaseSectionFromJson(Map<String, dynamic> json) =>
    ReleaseSection(
      name: json['name'] as String,
      notes: (json['notes'] as List<dynamic>)
          .map((e) => ReleaseNote.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ReleaseSectionToJson(ReleaseSection instance) =>
    <String, dynamic>{
      'name': instance.name,
      'notes': instance.notes,
    };

ReleaseNote _$ReleaseNoteFromJson(Map<String, dynamic> json) => ReleaseNote(
      message: json['message'] as String,
      githubPullRequestUrl: json['githubPullRequestUrl'] as String?,
    );

Map<String, dynamic> _$ReleaseNoteToJson(ReleaseNote instance) =>
    <String, dynamic>{
      'githubPullRequestUrl': instance.githubPullRequestUrl,
      'message': instance.message,
    };
