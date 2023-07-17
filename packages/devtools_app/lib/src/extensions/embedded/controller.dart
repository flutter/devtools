// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../shared/primitives/auto_dispose.dart';
import '_controller_desktop.dart' if (dart.library.html) '_controller_web.dart';

EmbeddedExtensionControllerImpl createEmbeddedExtensionController() {
  return EmbeddedExtensionControllerImpl();
}

abstract class EmbeddedExtensionController extends DisposableController {}
