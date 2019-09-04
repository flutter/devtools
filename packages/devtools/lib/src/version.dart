// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'ui/fake_flutter/fake_flutter.dart';

class FlutterVersion {
  FlutterVersion._({
    @required this.version,
    @required this.channel,
    @required this.repositoryUrl,
    @required this.frameworkRevision,
    @required this.frameworkCommitDate,
    @required this.engineRevision,
    @required this.dartSdkVersion,
  });

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
