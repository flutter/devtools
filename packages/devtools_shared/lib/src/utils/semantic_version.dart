// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'compare.dart';

class SemanticVersion with CompareMixin<SemanticVersion> {
  SemanticVersion({
    this.major = 0,
    this.minor = 0,
    this.patch = 0,
    this.preReleaseMajor,
    this.preReleaseMinor,
  });

  factory SemanticVersion.parse(String? versionString) {
    if (versionString == null) return SemanticVersion();

    // Remove any build metadata, denoted by a '+' character and whatever
    // follows.
    final buildMetadataIndex = versionString.indexOf('+');
    if (buildMetadataIndex != -1) {
      versionString = versionString.substring(0, buildMetadataIndex);
    }

    // [versionString] is expected to be of the form for VM.version, Dart, and
    // Flutter, respectively:
    // 2.15.0-233.0.dev (dev) (Mon Oct 18 14:06:26 2021 -0700) on "ios_x64"
    // 2.15.0-178.1.beta
    // 2.6.0-12.0.pre.443
    //
    // So split on the spaces to the version, and then on the dash char to
    // separate the main semantic version from the pre release version.
    final splitOnSpaces = versionString.split(' ');
    final version = splitOnSpaces.first;
    final splitOnDash = version.split('-');
    assert(splitOnDash.length <= 2, 'version: $version');

    final semVersion = splitOnDash.first;
    final versionParts = semVersion.split('.');
    final major =
        versionParts.isNotEmpty ? int.tryParse(versionParts.first) ?? 0 : 0;
    final minor =
        versionParts.length > 1 ? int.tryParse(versionParts[1]) ?? 0 : 0;
    final patch =
        versionParts.length > 2 ? int.tryParse(versionParts[2]) ?? 0 : 0;

    int? preReleaseMajor;
    int? preReleaseMinor;
    if (splitOnDash.length == 2) {
      final preRelease = splitOnDash.last;
      final preReleaseParts = preRelease
          .split('.')
          .map((part) => RegExp(r'\d+').stringMatch(part) ?? '')
          .toList()
        ..removeWhere((part) => part.isEmpty);
      preReleaseMajor = preReleaseParts.isNotEmpty
          ? int.tryParse(preReleaseParts.first) ?? 0
          : 0;
      preReleaseMinor = preReleaseParts.length > 1
          ? int.tryParse(preReleaseParts[1]) ?? 0
          : 0;
    }
    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      preReleaseMajor: preReleaseMajor,
      preReleaseMinor: preReleaseMinor,
    );
  }

  /// Returns a new [SemanticVersion] that is downgraded from [this].
  ///
  /// At a minimum, the pre-release version will be removed. Other downgrades
  /// can be applied by specifying any of [downgradeMajor], [downgradeMinor],
  /// and [downgradePatch], which will decrement the value of their respective
  /// version part by one (unless the value is already 0).
  ///
  /// This method may return a version equal to [this] if no downgrade options
  /// are specified.
  SemanticVersion downgrade({
    bool downgradeMajor = false,
    bool downgradeMinor = false,
    bool downgradePatch = false,
  }) {
    var major = this.major;
    var minor = this.minor;
    var patch = this.patch;
    if (downgradeMajor) {
      major = math.max(0, major - 1);
    }
    if (downgradeMinor) {
      minor = math.max(0, minor - 1);
    }
    if (downgradePatch) {
      patch = math.max(0, patch - 1);
    }
    return SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
    );
  }

  int major;

  int minor;

  int patch;

  int? preReleaseMajor;

  int? preReleaseMinor;

  bool get isPreRelease => preReleaseMajor != null || preReleaseMinor != null;

  bool isSupported({required SemanticVersion minSupportedVersion}) =>
      compareTo(minSupportedVersion) >= 0;

  @override
  int compareTo(SemanticVersion other) {
    if (major == other.major &&
        minor == other.minor &&
        patch == other.patch &&
        (preReleaseMajor ?? 0) == (other.preReleaseMajor ?? 0) &&
        (preReleaseMinor ?? 0) == (other.preReleaseMinor ?? 0)) {
      return 0;
    }
    if (major > other.major ||
        (major == other.major && minor > other.minor) ||
        (major == other.major && minor == other.minor && patch > other.patch)) {
      return 1;
    }
    if (major == other.major && minor == other.minor && patch == other.patch) {
      if (isPreRelease != other.isPreRelease) {
        return isPreRelease ? -1 : 1;
      }
      if (preReleaseMajor! > other.preReleaseMajor! ||
          (preReleaseMajor == other.preReleaseMajor &&
              (preReleaseMinor ?? 0) > (other.preReleaseMinor ?? 0))) {
        return 1;
      }
    }

    return -1;
  }

  @override
  String toString() {
    final semVer = [major, minor, patch].join('.');

    return [
      semVer,
      if (preReleaseMajor != null || preReleaseMinor != null)
        [
          if (preReleaseMajor != null) preReleaseMajor,
          if (preReleaseMajor == null && preReleaseMinor != null) '0',
          if (preReleaseMinor != null) preReleaseMinor,
        ].join('.'),
    ].join('-');
  }
}
