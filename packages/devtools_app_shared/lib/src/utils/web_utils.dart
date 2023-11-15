// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:js_interop';

import 'package:web/helpers.dart';

extension MessageExtension on Event {
  bool get isMessageEvent =>
      // TODO(srujzs): This is necessary in order to support package:web 0.4.0.
      // This was not needed with 0.3.0, hence the lint.
      // ignore: avoid-unnecessary-type-casts
      (this as JSObject).instanceOfString('MessageEvent');
}

extension NodeListExtension on NodeList {
  external void forEach(JSFunction callback);
}
