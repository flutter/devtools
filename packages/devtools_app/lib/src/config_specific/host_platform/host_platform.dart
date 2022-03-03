// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be found
// in the LICENSE file.

export 'host_platform_stub.dart'
    if (dart.library.html) 'host_platform_web.dart'
    if (dart.library.io) 'host_platform_desktop.dart';
