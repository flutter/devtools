// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

/// The universal link related settings of a iOS build of a Flutter project.
class UniversalLinkSettings {
  const UniversalLinkSettings._(
    this.bundleIdentifier,
    this.teamIdentifier,
    this.associatedDomains,
  );

  factory UniversalLinkSettings.fromJson(String json) {
    final jsonObject = jsonDecode(json);
    return UniversalLinkSettings._(
      jsonObject[_kBundleIdentifierKey] as String? ?? '',
      jsonObject[_kTeamIdentifierKey] as String? ?? '',
      jsonObject[_kAssociatedDomainsKey].cast<String>() as List<String>,
    );
  }

  static const _kBundleIdentifierKey = 'bundleIdentifier';
  static const _kTeamIdentifierKey = 'teamIdentifier';
  static const _kAssociatedDomainsKey = 'associatedDomains';

  /// Used when the the server can't retrieve universal link settings.
  static const empty = UniversalLinkSettings._('', '', <String>[]);

  /// The bundle identifier of the iOS build of this Flutter project.
  final String bundleIdentifier;

  /// The team identifier of the iOS build of this Flutter project.
  final String teamIdentifier;

  /// The associated domains of the iOS build of this Flutter project.
  final List<String> associatedDomains;
}
