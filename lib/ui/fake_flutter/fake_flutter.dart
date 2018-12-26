// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Collection of utility classes forked from package:flutter and dart:ui
/// to make it easier to write UI code that can later be ported to flutter.
///
/// At some point you should be able to switch out imports to fake_flutter
/// with imports to package:flutter.
/// Functionality such as I18N and shadows have been arbitrarily ripped out of
/// these classes as it would be hard to implement writing directly to
/// dart:html.
library fake_flutter;

// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import 'collections.dart';
import 'dart_ui/dart_ui.dart' hide TextStyle;
import 'dart_ui/dart_ui.dart' as ui;

export 'collections.dart';
export 'dart_ui/dart_ui.dart' hide TextStyle;

part 'assertions.dart';
part 'text.dart';
part 'text_span.dart';
