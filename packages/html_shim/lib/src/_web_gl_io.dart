// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// This library is a minimal fork of webgl with just functionality needed to
/// make the html library valid.
library web_gl;

// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '_html_io.dart';
import '_html_common_io.dart';

@Unstable()
@Native("WebGLContextEvent")
class ContextEvent extends Event {
  // To suppress missing implicit constructor warnings.
  factory ContextEvent._() {
    throw new UnsupportedError("Not supported");
  }

  factory ContextEvent(String type, [Map eventInit]) {
    if (eventInit != null) {
      var eventInit_1 = convertDartToNative_Dictionary(eventInit);
      return ContextEvent._create_1(type, eventInit_1);
    }
    return ContextEvent._create_2(type);
  }
  static ContextEvent _create_1(type, eventInit) =>
      JS('ContextEvent', 'new WebGLContextEvent(#,#)', type, eventInit);
  static ContextEvent _create_2(type) =>
      JS('ContextEvent', 'new WebGLContextEvent(#)', type);

  final String statusMessage;
}
