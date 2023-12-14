// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

export '_host_platform_desktop.dart'
    if (dart.library.js_interop) '_host_platform_web.dart';
