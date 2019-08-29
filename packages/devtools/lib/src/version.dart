// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

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

  static FlutterVersion parse(Map<String, dynamic> json) {
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

  String get flutterDisplay =>
      '${version == 'unknown' ? '' : version} • channel $channel • '
      '${repositoryUrl ?? 'unknown source'}';

  String get frameworkDisplay =>
      'revision $frameworkRevision • $frameworkCommitDate';

  String get engineDisplay => 'revision $engineRevision';
}
