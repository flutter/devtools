// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:html';

import '../../primitives/utils.dart';

Map<String, String> loadQueryParams() {
  return devToolsQueryParams(window.location.toString());
}

String? getWebUrl() => window.location.toString();

void webRedirect(String url) {
  window.location.replace(url);
}
