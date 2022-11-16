// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:devtools_shared/devtools_shared.dart';
import 'package:json_annotation/json_annotation.dart';

part 'release_note_classes.g.dart';

@JsonSerializable()

/// Stores all of the release note [sections] for a given [version].
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
    for (var section in sections) {
      markdown += '# ${section.name}\n\n';
      for (var note in section.notes) {
        markdown += note.toMarkdown();
      }
      markdown += '\n';
    }
    return markdown;
  }

  factory Release.fromJson(Map<String, dynamic> json) =>
      _$ReleaseFromJson(json);

  Map<String, dynamic> toJson() => _$ReleaseToJson(this);
}

@JsonSerializable()

/// Represents a section of release [notes] with a given [name].
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

/// An individual release note entry, with a given [message].
///
/// The names of images relating to the releaseNote can be passed
/// in [imageNames]. WThe GitHub pull request url that the message is added to,
/// can be reflected through [githubPullRequestUrls].
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
        if (match == null) {
          throw Exception(
              "Invalid github PR Url($url) found in message: $message}");
        }
        final prNumber = match.namedGroup('pr_number');
        prUrls.add('[#$prNumber]($url)');
      }
      markdown += ' - ${prUrls.join(", ")}';
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
