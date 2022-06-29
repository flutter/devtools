// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:logging/logging.dart';

import 'model.dart';

/// If true, leak detection is enabled for the application.
bool leakTrackingEnabled = false;

/// Detects creation location for an object.
late ObjectDetailsProvider objectDetailsProvider;

late Logger appLogger;
