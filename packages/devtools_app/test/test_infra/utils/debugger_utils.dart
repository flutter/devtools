// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder findDebuggerButtonWithIcon(IconData icon) => find.ancestor(
      of: find.byWidgetPredicate(
        (Widget widget) =>
            widget is MaterialIconLabel && widget.iconData == icon,
      ),
      matching: find.byType(OutlinedButton),
    );
