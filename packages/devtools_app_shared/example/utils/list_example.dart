// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/widgets.dart';

void main() {
  useListValueNotifier();
}

/// This is an example of using the [ListValueNotifier] that is exposed from
/// 'package:devtools_app_shared/utils.dart'.
///
/// A [ListValueNotifier] will holds a list object, and will notify listeners
/// on modifications to the list.
///
/// This should be used in place of ValueNotifier<List<Object>> when list
/// updates should notify listeners, and not just changing the notifier's value
/// with a new list.
void useListValueNotifier() {
  final myListNotifier = ListValueNotifier<int>([1, 2, 3]);

  // These calls will notify all listeners of [myListNotifier].
  myListNotifier.add(4);
  myListNotifier.removeAt(0);
  // ...

  // As opposed to:
  final myValueNotifierWithAList = ValueNotifier<List<int>>([1, 2, 3]);

  // These calls will not notify listeners of [myValueNotifierWithAList]
  myValueNotifierWithAList.value.add(4);
  myValueNotifierWithAList.value.removeAt(0);
}
