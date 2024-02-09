// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

/// The universal link related settings of a iOS build of a Flutter project.
extension type const UniversalLinkSettings._(Map<String, Object?> _json) {
  factory UniversalLinkSettings.fromJson(String json) =>
      UniversalLinkSettings._(jsonDecode(json));

  static const _kBundleIdentifierKey = 'bundleIdentifier';
  static const _kTeamIdentifierKey = 'teamIdentifier';
  static const _kAssociatedDomainsKey = 'associatedDomains';

  /// Used when the the server can't retrieve universal link settings.
  static const empty = UniversalLinkSettings._({
    _kBundleIdentifierKey: '',
    _kTeamIdentifierKey: '',
    _kAssociatedDomainsKey: [],
  });

  /// The bundle identifier of the iOS build of this Flutter project.
  String get bundleIdentifier => _json[_kBundleIdentifierKey] as String;

  /// The team identifier of the iOS build of this Flutter project.
  String get teamIdentifier => _json[_kTeamIdentifierKey] as String;

  /// The associated domains of the iOS build of this Flutter project.
  List<String> get associatedDomains =>
      _json[_kAssociatedDomainsKey] as List<String>;
}
