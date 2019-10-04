// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'ui/fake_flutter/fake_flutter.dart';

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
    // Flutter versions can come in as '1.10.7-pre.42', so we strip out any
    // characters that are not digits. We do not currently have a need to know
    // more version parts than major, minor, and patch. If this changes, we can
    // add support for the extra values.
    final _versionParts = version
        .split('.')
        .map((part) => RegExp(r'\d+').stringMatch(part) ?? '0')
        .toList();
    major =
        _versionParts.isNotEmpty ? int.tryParse(_versionParts.first) ?? 0 : 0;
    minor = _versionParts.length > 1 ? int.tryParse(_versionParts[1]) ?? 0 : 0;
    patch = _versionParts.length > 2 ? int.tryParse(_versionParts[2]) ?? 0 : 0;
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

class SemanticVersion implements Comparable {
  SemanticVersion({this.major = 0, this.minor = 0, this.patch = 0});

  int major;

  int minor;

  int patch;

  bool isSupported({@required SemanticVersion supportedVersion}) =>
      compareTo(supportedVersion) >= 0;

  @override
  int compareTo(other) {
    if (major == other.major && minor == other.minor && patch == other.patch) {
      return 0;
    }
    if (major > other.major ||
        (major == other.major && minor > other.minor) ||
        (major == other.major && minor == other.minor && patch > other.patch)) {
      return 1;
    }
    return -1;
  }
}
