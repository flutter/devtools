// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/elements.dart';
import 'inspector_tree.dart';

/// Base class for all inspector tree classes that can be used on the web.
abstract class InspectorTreeWeb implements InspectorTree, CoreElementView {}
