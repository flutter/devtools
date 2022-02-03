// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

// @dart=2.9

import 'dart:html';

import '../../shared/utils.dart';

Map<String, String> loadQueryParams() {
  return devToolsQueryParams(window.location.toString());
}
