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

  /// The package name that this extension is for.
  final String name;

  /// The path that this extension's assets live at.
  ///
  /// This location will be in the user's pub cache.
  final String path;

  // TODO(kenz): we might want to add validation to these issue tracker
  // links to ensure they don't point to the DevTools repo or flutter repo.
  // If an invalid issue tracker link is provided, we can default to
  // 'pub.dev/packages/$name'.
  /// The link to the issue tracker for this DevTools extension.
  ///
  /// This should not point to the flutter/devtools or flutter/flutter issue
  /// trackers, but rather to the issue tracker for the package that provides
  /// the extension, or to the repo where the extension is developed.
  final String issueTrackerLink;

  /// The version for the DevTools extension.
  /// 
  /// This may match the version of the parent package or use a different
  /// versioning system as decided by the extension author.
  final String version;

  /// The code point for the material icon that will parsed by Flutter's
  /// [IconData] class for displaying in DevTools.
  /// 
  /// This code point should be part of the 'MaterialIcons' font family.
  final int materialIconCodePoint;

  Map<String, Object?> toJson() => {
        nameKey: name,
        pathKey: path,
        issueTrackerKey: issueTrackerLink,
        versionKey: version,
        materialIconCodePointKey: materialIconCodePoint,
      };
}
