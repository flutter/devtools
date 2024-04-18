// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/shared/development_helpers.dart';

final testExtensions = List.of(debugExtensions)..sort();
final barExtension = testExtensions[0];
final fooExtension = testExtensions[1];
final providerExtension = testExtensions[2];
