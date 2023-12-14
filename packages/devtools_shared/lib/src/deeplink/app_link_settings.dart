// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file handles json object.
// ignore_for_file: avoid-dynamic

import 'dart:convert';

/// The app link related settings of a Android build of a Flutter project.
class AppLinkSettings {
  const AppLinkSettings._(this.applicationId, this.deeplinks);

  factory AppLinkSettings.fromJson(String json) {
    final jsonObject = jsonDecode(json);
    return AppLinkSettings._(
      jsonObject[_kApplicationIdKey] as String,
      (jsonObject[_kDeeplinksKey] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map<AndroidDeeplink>(AndroidDeeplink._fromJsonObject)
          .toList(),
    );
  }

  /// Used when the the server can't retrieve app link settings.
  static const empty = AppLinkSettings._('', <AndroidDeeplink>[]);

  static const _kApplicationIdKey = 'applicationId';
  static const _kDeeplinksKey = 'deeplinks';

  /// The application id of the Android build of this Flutter project.
  final String applicationId;

  /// The supported deep link of the Android build of this Flutter project.
  ///
  /// This list also include deeplinks with custom scheme.
  final List<AndroidDeeplink> deeplinks;
}

/// A deep link in a Android build of a Flutter project.
///
/// The deeplink is defined in intent filters of AndroidManifest.xml in the
/// Android sub-project.
class AndroidDeeplink {
  AndroidDeeplink._(this.scheme, this.host, this.path);

  factory AndroidDeeplink._fromJsonObject(Map<String, dynamic> json) {
    return AndroidDeeplink._(
      json[_kSchemeKey] as String,
      json[_kHostKey] as String,
      json[_kPathKey] as String,
    );
  }

  static const _kSchemeKey = 'scheme';
  static const _kHostKey = 'host';
  static const _kPathKey = 'path';

  /// The scheme section of the deeplink.
  final String scheme;

  /// The host section of the deeplink.
  final String host;

  /// The path pattern section of the deeplink.
  final String path;
}
