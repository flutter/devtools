// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

export '_fake_sse.dart'
    if (dart.library.html) 'package:sse/client/sse_client.dart' show SseClient;
