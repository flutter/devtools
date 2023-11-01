// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

import 'dart:js_interop';

import 'package:web/helpers.dart';

extension MessageExtension on Event {
  bool get isMessageEvent => instanceOfString('MessageEvent');
}

extension NodeListExtension on NodeList {
  external void forEach(JSFunction callback);
}
