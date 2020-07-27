// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'drag_and_drop.dart';

DragAndDrop createDragAndDrop({
  @required Key key,
  @required void Function(Map<String, dynamic> data) handleDrop,
  @required Widget child,
}) {
  throw Exception(
      'Attempting to create DragAndDrop for unrecognized platform.');
}
