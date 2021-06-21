// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

import 'utils.dart';

class FlutterVersion extends SemanticVersion {
  FlutterVersion._({
    @required this.version,
    @required this.channel,
    @required this.repositoryUrl,
    @required this.frameworkRevision,
    @required this.frameworkCommitDate,
    @required this.engineRevision,
    @required this.dartSdkVersion,
  }) {
    // Flutter versions are expected in the format '2.3.1-16.1-pre', so we split
    // on the dash char to separate the main semantic version from the pre
    // release version.
    final splitOnDash = version.split('-');
    assert(splitOnDash.length <= 2);

    final semVersion = splitOnDash.first;
    final _versionParts = semVersion.split('.');
    major =
        _versionParts.isNotEmpty ? int.tryParse(_versionParts.first) ?? 0 : 0;
    minor = _versionParts.length > 1 ? int.tryParse(_versionParts[1]) ?? 0 : 0;
    patch = _versionParts.length > 2 ? int.tryParse(_versionParts[2]) ?? 0 : 0;

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
  }

  factory FlutterVersion.parse(Map<String, dynamic> json) {
    return FlutterVersion._(
      version: json['frameworkVersion'],
      channel: json['channel'],
      repositoryUrl: json['repositoryUrl'],
      frameworkRevision: json['frameworkRevisionShort'],
      frameworkCommitDate: json['frameworkCommitDate'],
      engineRevision: json['engineRevisionShort'],
      dartSdkVersion: json['dartSdkVersion'],
    );
  }

  final String version;

  final String channel;

  final String repositoryUrl;

  final String frameworkRevision;

  final String frameworkCommitDate;

  final String engineRevision;

  final String dartSdkVersion;

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
}

class SemanticVersion with CompareMixin {
  SemanticVersion({
    this.major = 0,
    this.minor = 0,
    this.patch = 0,
    this.preReleaseMajor,
    this.preReleaseMinor,
  });

  int major;

  int minor;

  int patch;

  int preReleaseMajor;

  int preReleaseMinor;

  bool get isPreRelease => preReleaseMajor != null || preReleaseMinor != null;

  bool isSupported({@required SemanticVersion supportedVersion}) =>
      compareTo(supportedVersion) >= 0;

  @override
  int compareTo(other) {
    if (major == other.major &&
        minor == other.minor &&
        patch == other.patch &&
        preReleaseMajor == other.preReleaseMajor &&
        preReleaseMinor == other.preReleaseMinor) {
      return 0;
    }
    if (major > other.major ||
        (major == other.major && minor > other.minor) ||
        (major == other.major && minor == other.minor && patch > other.patch)) {
      return 1;
    }
    if (major == other.major && minor == other.minor && patch == other.patch) {
      if (isPreRelease != other.isPreRelease) {
        return isPreRelease ? 1 : -1;
      }
      if (preReleaseMajor > other.preReleaseMajor ||
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
