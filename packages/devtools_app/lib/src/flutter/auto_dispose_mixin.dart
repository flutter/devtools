// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../auto_dispose.dart';

/// Mixin to simplifying managing the lifetime of listeners used by a
/// [StatefulWidget].
///
/// See also:
/// * [AutoDisposeControllerMixin], which provides the same functionality for
///   controller classes.
mixin AutoDisposeMixin<T extends StatefulWidget> on State<T>, AutoDisposeBase {
  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}
