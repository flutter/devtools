// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'utils.dart';

class FlutterVersion extends SemanticVersion {
  FlutterVersion._({
    required this.version,
    required this.channel,
    required this.repositoryUrl,
    required this.frameworkRevision,
    required this.frameworkCommitDate,
    required this.engineRevision,
    required this.dartSdkVersion,
  }) {
    final semVer = SemanticVersion.parse(version);
    major = semVer.major;
    minor = semVer.minor;
    patch = semVer.patch;
    preReleaseMajor = semVer.preReleaseMajor;
    preReleaseMinor = semVer.preReleaseMinor;
  }

  factory FlutterVersion.parse(Map<String, dynamic> json) {
    return FlutterVersion._(
      version: json['frameworkVersion'],
      channel: json['channel'],
      repositoryUrl: json['repositoryUrl'],
      frameworkRevision: json['frameworkRevisionShort'],
      frameworkCommitDate: json['frameworkCommitDate'],
      engineRevision: json['engineRevisionShort'],
      dartSdkVersion: _parseDartVersion(json['dartSdkVersion']),
    );
  }

  final String? version;

  final String? channel;

  final String? repositoryUrl;

  final String? frameworkRevision;

  final String? frameworkCommitDate;

  final String? engineRevision;

  final SemanticVersion? dartSdkVersion;

  String get flutterVersionSummary => [
        if (version != 'unknown') version,
        'channel $channel',
        repositoryUrl ?? 'unknown source',
      ].join(' • ');

  String get frameworkVersionSummary =>
      'revision $frameworkRevision • $frameworkCommitDate';

  String get engineVersionSummary => 'revision $engineRevision';

  @override
  bool operator ==(other) {
    if (other is! FlutterVersion) return false;
    return version == other.version &&
        channel == other.channel &&
        repositoryUrl == other.repositoryUrl &&
        frameworkRevision == other.frameworkRevision &&
        frameworkCommitDate == other.frameworkCommitDate &&
        engineRevision == other.engineRevision &&
        dartSdkVersion == other.dartSdkVersion;
  }

  @override
  int get hashCode => hashValues(
        version,
        channel,
        repositoryUrl,
        frameworkRevision,
        frameworkCommitDate,
        engineRevision,
        dartSdkVersion,
      );

  static SemanticVersion? _parseDartVersion(String? versionString) {
    if (versionString == null) return null;

    // Example Dart version string: "2.15.0 (build 2.15.0-178.1.beta)"
    const prefix = '(build ';
    final indexOfPrefix = versionString.indexOf(prefix);

    String rawVersion;
    if (indexOfPrefix != -1) {
      final startIndex = indexOfPrefix + prefix.length;
      rawVersion = versionString.substring(
        startIndex,
        versionString.length - 1,
      );
    } else {
      rawVersion = versionString;
    }
    return SemanticVersion.parse(rawVersion);
  }
}

class SemanticVersion with CompareMixin {
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
    final _versionParts = semVersion.split('.');
    final major =
        _versionParts.isNotEmpty ? int.tryParse(_versionParts.first) ?? 0 : 0;
    final minor =
        _versionParts.length > 1 ? int.tryParse(_versionParts[1]) ?? 0 : 0;
    final patch =
        _versionParts.length > 2 ? int.tryParse(_versionParts[2]) ?? 0 : 0;

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
    var _major = major;
    var _minor = minor;
    var _patch = patch;
    if (downgradeMajor) {
      _major = math.max(0, _major - 1);
    }
    if (downgradeMinor) {
      _minor = math.max(0, _minor - 1);
    }
    if (downgradePatch) {
      _patch = math.max(0, _patch - 1);
    }
    return SemanticVersion(
      major: _major,
      minor: _minor,
      patch: _patch,
    );
  }

  int major;

  int minor;

  int patch;

  int? preReleaseMajor;

  int? preReleaseMinor;

  bool get isPreRelease => preReleaseMajor != null || preReleaseMinor != null;

  bool isSupported({required SemanticVersion supportedVersion}) =>
      compareTo(supportedVersion) >= 0;

  @override
  int compareTo(other) {
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
      if (preReleaseMajor! > other.preReleaseMajor ||
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
