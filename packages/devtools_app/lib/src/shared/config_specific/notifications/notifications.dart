// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

export 'notifications_stub.dart'
    if (dart.library.js_interop) 'notifications_web.dart'
    if (dart.library.io) 'notifications_desktop.dart';
