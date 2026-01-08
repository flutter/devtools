// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_shared/devtools_shared.dart';

import '../utils/enum_utils.dart';

/// Flutter version service registered by Flutter Tools.
///
/// We call this service to get version information about the Flutter framework,
/// the Flutter engine, and the Dart sdk.
const flutterVersionService = RegisteredService(
  service: 'flutterVersion',
  title: 'Flutter Version',
);

final class FlutterVersion extends SemanticVersion {
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

  factory FlutterVersion.unknown() {
    return FlutterVersion._(
      version: null,
      channel: null,
      repositoryUrl: null,
      frameworkRevision: null,
      frameworkCommitDate: null,
      engineRevision: null,
      dartSdkVersion: null,
    );
  }

  final String? version;

  final String? channel;

  final String? repositoryUrl;

  final String? frameworkRevision;

  final String? frameworkCommitDate;

  final String? engineRevision;

  final SemanticVersion? dartSdkVersion;

  bool get unknown =>
      version == null &&
      channel == null &&
      repositoryUrl == null &&
      frameworkRevision == null &&
      frameworkCommitDate == null &&
      engineRevision == null &&
      dartSdkVersion == null;

  @override
  bool operator ==(Object other) {
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
  int get hashCode => Object.hash(
        version,
        channel,
        repositoryUrl,
        frameworkRevision,
        frameworkCommitDate,
        engineRevision,
        dartSdkVersion,
      );

  static final _stableVersionRegex = RegExp(r'^\d+\.\d+\.\d+$');
  static final _isNumericRegex = RegExp(r'\d');

  /// Identifies the Flutter channel from a version string.
  ///
  /// This method will first attempt to use [channelStr] if it is provided.
  /// Otherwise, it will fall back to parsing the channel from [versionStr].
  ///
  /// This method will return `null` if the channel cannot be determined from
  /// the provided information.
  ///
  /// Examples of versions that can be parsed:
  ///  * '2.3.0' -> [FlutterChannel.stable]
  ///  * '2.3.0-17.0.pre' -> [FlutterChannel.beta]
  ///  * '2.3.0-17.0.pre.355' -> [FlutterChannel.dev]
  static FlutterChannel? identifyChannel(
    String versionStr, {
    String? channelStr,
  }) {
    // Check if channel string is valid.
    if (channelStr != null) {
      final channel = FlutterChannel.fromName(channelStr);
      if (channel != null) return channel;
    }

    // Check if version matches stable release format.
    final sanitized = SemanticVersion.sanitizeVersionStr(versionStr);
    if (_stableVersionRegex.hasMatch(sanitized)) return FlutterChannel.stable;

    // Check if version matches pre-release format.
    const preReleaseIndicator = '.pre';
    final isValidPreRelease = sanitized.contains(preReleaseIndicator);
    if (!isValidPreRelease) return null;

    // Check if version matches beta release format.
    if (sanitized.endsWith(preReleaseIndicator)) return FlutterChannel.beta;

    // Check if version matches dev release format.
    final versionParts = sanitized.split('$preReleaseIndicator.');
    final suffix = versionParts.last;
    if (versionParts.length == 2 && _isNumericRegex.hasMatch(suffix)) {
      return FlutterChannel.dev;
    }

    // Matches no known release format, return null.
    return null;
  }

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

/// An enum representing the different Flutter channels.
enum FlutterChannel with EnumIndexOrdering {
  dev,
  beta,
  stable;

  static FlutterChannel? fromName(String? name) {
    try {
      return FlutterChannel.values.byName(name ?? '');
    } catch (_) {
      return null;
    }
  }
}
