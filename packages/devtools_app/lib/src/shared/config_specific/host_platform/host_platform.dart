// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

export '_host_platform_desktop.dart'
    if (dart.library.js_interop) '_host_platform_web.dart';
