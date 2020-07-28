// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';

import '../../notifications.dart';
import 'drag_and_drop.dart';

DragAndDropManager createDragAndDropManager({
  @required NotificationsState notifications,
}) {
  throw Exception(
      'Attempting to create DragAndDrop for unrecognized platform.');
}
