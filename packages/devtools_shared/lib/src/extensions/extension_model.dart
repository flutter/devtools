// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';

/// Describes an extension that can be dynamically loaded into a custom screen
/// in DevTools.
class DevToolsExtensionConfig implements Comparable {
  DevToolsExtensionConfig._({
    required this.name,
    required this.path,
    required this.issueTrackerLink,
    required this.version,
    required this.materialIconCodePoint,
    required this.isPubliclyHosted,
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

    if (json
        case {
          nameKey: final String name,
          pathKey: final String path,
          issueTrackerKey: final String issueTracker,
          versionKey: final String version,
          isPubliclyHostedKey: final String isPubliclyHosted,
        }) {
      final underscoresAndLetters = RegExp(r'^[a-z0-9_]*$');
      if (!underscoresAndLetters.hasMatch(name)) {
        throw StateError(
          'The "name" field in the extension config.yaml should only contain '
          'lowercase letters, numbers, and underscores but instead was '
          '"$name". This should be a valid Dart package name that matches the '
          'package name this extension belongs to.',
        );
      }
      return DevToolsExtensionConfig._(
        name: name,
        path: path,
        issueTrackerLink: issueTracker,
        version: version,
        materialIconCodePoint: codePoint,
        isPubliclyHosted: bool.parse(isPubliclyHosted),
      );
    } else {
      if (!json.keys.contains(isPubliclyHostedKey)) {
        throw StateError(
          'Missing key "$isPubliclyHostedKey" when trying to parse '
          'DevToolsExtensionConfig object.',
        );
      }

      const requiredKeysFromConfigFile = {
        nameKey,
        pathKey,
        issueTrackerKey,
        versionKey,
      };
      // We do not expect the config.yaml file to contain
      // [isPubliclyHostedKey], as this should be inferred.
      final jsonKeysFromConfigFile = Set.of(json.keys.toSet())
        ..remove(isPubliclyHostedKey);

      final diff = requiredKeysFromConfigFile.difference(
        jsonKeysFromConfigFile,
      );

      if (diff.isNotEmpty) {
        throw StateError(
          'Missing required fields ${diff.toString()} in the extension '
          'config.yaml.',
        );
      } else {
        // All the required keys are present, but the value types did not match.
        final sb = StringBuffer();
        for (final entry in json.entries) {
          sb.writeln(
            '   ${entry.key}: ${entry.value} (${entry.value.runtimeType})',
          );
        }
        throw StateError(
          'Unexpected value types in the extension config.yaml. Expected all '
          'values to be of type String, but one or more had a different type:\n'
          '${sb.toString()}',
        );
      }
    }
  }

  static const nameKey = 'name';
  static const pathKey = 'path';
  static const issueTrackerKey = 'issueTracker';
  static const versionKey = 'version';
  static const materialIconCodePointKey = 'materialIconCodePoint';
  static const isPubliclyHostedKey = 'isPubliclyHosted';

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
  /// See https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/icons.dart.
  final int materialIconCodePoint;

  /// Whether this extension is distrubuted in a public package on pub.dev.
  final bool isPubliclyHosted;

  String get displayName => name.toLowerCase();

  String get analyticsSafeName => isPubliclyHosted ? name : 'private';

  Map<String, Object?> toJson() => {
        nameKey: name,
        pathKey: path,
        issueTrackerKey: issueTrackerLink,
        versionKey: version,
        materialIconCodePointKey: materialIconCodePoint,
        isPubliclyHostedKey: isPubliclyHosted.toString(),
      };

  @override
  // ignore: avoid-dynamic, avoids invalid_override error
  int compareTo(other) {
    final otherConfig = other as DevToolsExtensionConfig;
    final compare = name.compareTo(otherConfig.name);
    if (compare == 0) {
      return path.compareTo(otherConfig.path);
    }
    return compare;
  }

  @override
  bool operator ==(Object? other) {
    return other is DevToolsExtensionConfig &&
        other.name == name &&
        other.path == path &&
        other.issueTrackerLink == issueTrackerLink &&
        other.version == version &&
        other.materialIconCodePoint == materialIconCodePoint &&
        other.isPubliclyHosted == isPubliclyHosted;
  }

  @override
  int get hashCode => Object.hash(
        name,
        path,
        issueTrackerLink,
        version,
        materialIconCodePoint,
        isPubliclyHosted,
      );
}

/// Describes the enablement state of a DevTools extension.
enum ExtensionEnabledState {
  /// The extension has been enabled manually by the user.
  enabled,

  /// The extension has been disabled manually by the user.
  disabled,

  /// The extension has been neither enabled nor disabled by the user.
  none,

  /// Something went wrong with reading or writing the activation state.
  ///
  /// We should ignore extensions with this activation state.
  error;

  /// Parses [value] and returns the matching [ExtensionEnabledState] if found.
  static ExtensionEnabledState from(String? value) {
    return ExtensionEnabledState.values
            .firstWhereOrNull((e) => e.name == value) ??
        ExtensionEnabledState.none;
  }
}
