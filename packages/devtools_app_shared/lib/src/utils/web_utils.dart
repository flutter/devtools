// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:js_interop';

import 'package:web/web.dart';

extension MessageExtension on Event {
  bool get isMessageEvent => instanceOfString('MessageEvent');
}

extension NodeListExtension on NodeList {
  external void forEach(JSFunction callback);
}
