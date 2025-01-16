// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder findDebuggerButtonWithIcon(IconData icon) => find.ancestor(
  of: find.byWidgetPredicate(
    (Widget widget) => widget is MaterialIconLabel && widget.iconData == icon,
  ),
  matching: find.byType(OutlinedButton),
);

Finder findDebuggerButtonWithIconAsset(String iconName) => find.ancestor(
  of: find.byWidgetPredicate(
    (Widget widget) =>
        widget is MaterialIconLabel &&
        widget.iconAsset != null &&
        widget.iconAsset!.contains(iconName),
  ),
  matching: find.byType(OutlinedButton),
);
