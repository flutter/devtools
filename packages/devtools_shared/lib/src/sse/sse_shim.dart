// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

export '_fake_sse.dart'
    if (dart.library.js_interop) 'package:sse/client/sse_client.dart'
    show SseClient;
