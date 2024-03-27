// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file handles json object.
// ignore_for_file: avoid-dynamic

import 'dart:convert';

/// The app link related settings of a Android build of a Flutter project.
class AppLinkSettings {
  const AppLinkSettings._(
    this.applicationId,
    this.deeplinkingFlagEnabled,
    this.deeplinks,
  );

  factory AppLinkSettings.fromJson(String json) {
    final jsonObject = jsonDecode(json) as Map;
    final {
      _kApplicationIdKey: String applicationId,
      _kDeeplinksKey: List<Object?> deepLinks,
      _kDeeplinkingFlagEnabledKey: bool deeplinkingFlagEnabled,
    } = jsonObject;
    return AppLinkSettings._(
      applicationId,
      deeplinkingFlagEnabled,
      deepLinks
          .cast<Map<String, dynamic>>()
          .map<AndroidDeeplink>(AndroidDeeplink._fromJsonObject)
          .toList(),
    );
  }

  /// Used when the the server can't retrieve app link settings.
  static const empty = AppLinkSettings._('', false, <AndroidDeeplink>[]);

  static const _kApplicationIdKey = 'applicationId';
  static const _kDeeplinkingFlagEnabledKey = 'deeplinkingFlagEnabled';
  static const _kDeeplinksKey = 'deeplinks';

  /// The application id of the Android build of this Flutter project.
  final String applicationId;

  /// The flag set by user in android manifest file to enable deep linking.
  final bool deeplinkingFlagEnabled;

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
  AndroidDeeplink._(this.scheme, this.host, this.path, this.intentFilterChecks);

  factory AndroidDeeplink._fromJsonObject(Map<String, dynamic> json) {
    return AndroidDeeplink._(
      json[_kSchemeKey] as String,
      json[_kHostKey] as String,
      json[_kPathKey] as String,
      IntentFilterChecks._fromJsonObject(
        json[_kIntentFilterChecksKey] as Map<String, dynamic>,
      ),
    );
  }

  static const _kSchemeKey = 'scheme';
  static const _kHostKey = 'host';
  static const _kPathKey = 'path';
  static const _kIntentFilterChecksKey = 'intentFilterCheck';

  /// The scheme section of the deeplink.
  final String scheme;

  /// The host section of the deeplink.
  final String host;

  /// The path pattern section of the deeplink.
  final String path;

  /// The intent filter checks section of the deeplink.
  final IntentFilterChecks intentFilterChecks;
}

/// Intent filter checks for a deep link.
///
/// The intent filters are from AndroidManifest.xml in the
/// Android sub-project.
class IntentFilterChecks {
  IntentFilterChecks._(
    this.hasAutoVerify,
    this.hasActionView,
    this.hasDefaultCategory,
    this.hasBrowsableCategory,
  );

  factory IntentFilterChecks._fromJsonObject(Map<String, dynamic> json) {
    return IntentFilterChecks._(
      json[_kHasAutoVerifyKey] as bool,
      json[_kHasActionViewKey] as bool,
      json[_kHasDefaultCategoryKey] as bool,
      json[_kHasBrowsableCategoryKey] as bool,
    );
  }

  static const _kHasAutoVerifyKey = 'hasAutoVerify';
  static const _kHasActionViewKey = 'hasActionView';
  static const _kHasDefaultCategoryKey = 'hasDefaultCategory';
  static const _kHasBrowsableCategoryKey = 'hasBrowsableCategory';

  final bool hasAutoVerify;
  final bool hasActionView;
  final bool hasDefaultCategory;
  final bool hasBrowsableCategory;
}
