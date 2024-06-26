// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'file_system.dart';

/// Provides access to the local Flutter store (~/.flutter).
class FlutterStore {
  static const storeName = '.flutter';
  static const firstRunKey = 'firstRun';
  static const gaEnabledKey = 'enabled';
  static const flutterClientIdKey = 'clientId';

  final properties = IOPersistentProperties(storeName);

  bool get isFirstRun => properties[firstRunKey] == true;

  bool get gaEnabled => properties[gaEnabledKey] == true;

  String get flutterClientId => properties[flutterClientIdKey] as String;
}
