// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

/// The universal link related settings of a iOS build of a Flutter project.
extension type const UniversalLinkSettings._(Map<String, Object?> _json) {
  factory UniversalLinkSettings.fromJson(String json) =>
      UniversalLinkSettings._(jsonDecode(json));

  /// Used when the server can't retrieve universal link settings.
  ///
  /// The input needs to be in json format from DevTools server response.
  factory UniversalLinkSettings.fromErrorJson(String json) {
    final jsonObject = jsonDecode(json) as Map<String, Object?>;
    final message = jsonObject[_kErrorKey]! as String;
    return UniversalLinkSettings.error(message);
  }

  /// Used when the server can't retrieve universal link settings.
  factory UniversalLinkSettings.error(String message) =>
      UniversalLinkSettings._({
        _kBundleIdentifierKey: '',
        _kTeamIdentifierKey: '',
        _kAssociatedDomainsKey: const <String>[],
        _kErrorKey: message,
      });

  static const _kBundleIdentifierKey = 'bundleIdentifier';
  static const _kTeamIdentifierKey = 'teamIdentifier';
  static const _kAssociatedDomainsKey = 'associatedDomains';
  static const _kErrorKey = 'error';

  /// Used when the the server can't retrieve universal link settings.
  static const empty = UniversalLinkSettings._({
    _kBundleIdentifierKey: '',
    _kTeamIdentifierKey: '',
    _kAssociatedDomainsKey: [],
  });

  /// The bundle identifier of the iOS build of this Flutter project.
  String get bundleIdentifier =>
      (_json[_kBundleIdentifierKey] as String?) ?? '';

  /// The team identifier of the iOS build of this Flutter project.
  String get teamIdentifier => (_json[_kTeamIdentifierKey] as String?) ?? '';

  /// The associated domains of the iOS build of this Flutter project.
  List<String> get associatedDomains =>
      (_json[_kAssociatedDomainsKey] as List).cast<String>().toList();

  /// The error message when requesting universal link settings.
  String? get error => _json[_kErrorKey] as String?;
}
