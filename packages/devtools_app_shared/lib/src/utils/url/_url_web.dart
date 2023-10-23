// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'package:web/helpers.dart';

Map<String, String> loadQueryParams({String Function(String)? urlModifier}) {
  var url = getWebUrl()!;
  url = urlModifier?.call(url) ?? url;
  return Uri.parse(url).queryParameters;
}

String? getWebUrl() => window.location.toString();

void webRedirect(String url) {
  window.location.replace(url);
}
