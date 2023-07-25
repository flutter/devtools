// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Describes an extension that can be dynamically loaded into a custom screen
/// in DevTools.
class DevToolsExtensionConfig {
  DevToolsExtensionConfig._({
    required this.name,
    required this.path,
    required this.issueTrackerLink,
    required this.version,
    required this.materialIconCodePoint,
  });

  factory DevToolsExtensionConfig.parse(Map<String, Object?> json) {
    // Defaults to the code point for [Icons.extensions_outlined] if null.
    late int codePoint;
    final codePointFromJson = json[materialIconCodePointKey];
    const defaultCodePoint = 0xf03f;
    if (codePointFromJson is String?) {
      codePoint =
          int.tryParse(codePointFromJson ?? '0xf03f') ?? defaultCodePoint;
    } else {
      codePoint = codePointFromJson as int? ?? defaultCodePoint;
    }

    final name = json[nameKey] as String?;
    final path = json[pathKey] as String?;
    final issueTrackerLink = json[issueTrackerKey] as String?;
    final version = json[versionKey] as String?;

    final nullFields = [
      if (name == null) nameKey,
      if (path == null) pathKey,
      if (issueTrackerLink == null) issueTrackerKey,
      if (version == null) versionKey,
    ];
    if (nullFields.isNotEmpty) {
      throw StateError(
        'missing required fields ${nullFields.toString()} in the extension '
        'config.json',
      );
    }

    return DevToolsExtensionConfig._(
      name: name!,
      path: path!,
      issueTrackerLink: issueTrackerLink!,
      version: version!,
      materialIconCodePoint: codePoint,
    );
  }

  static const nameKey = 'name';
  static const pathKey = 'path';
  static const issueTrackerKey = 'issueTracker';
  static const versionKey = 'version';
  static const materialIconCodePointKey = 'materialIconCodePoint';

  final String name;
  final String path;
  final String issueTrackerLink;
  final String version;
  final int materialIconCodePoint;

  Map<String, Object?> toJson() => {
        nameKey: name,
        pathKey: path,
        issueTrackerKey: issueTrackerLink,
        versionKey: version,
        materialIconCodePointKey: materialIconCodePoint,
      };
}
