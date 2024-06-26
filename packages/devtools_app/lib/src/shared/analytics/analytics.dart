// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

export '_analytics_stub.dart'
    if (dart.library.js_interop) '_analytics_web.dart';
