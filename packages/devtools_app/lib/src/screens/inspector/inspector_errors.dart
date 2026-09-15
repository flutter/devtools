// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import '../../shared/managers/error_badge_manager.dart';

/// An error associated with a specific widget that can be inspected in the
/// Inspector screen.
class InspectableWidgetError extends DevToolsError {
  InspectableWidgetError(super.errorMessage, super.id, {super.read});

  @override
  InspectableWidgetError asRead() =>
      InspectableWidgetError(errorMessage, id, read: true);
}
