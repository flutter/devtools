// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';

/// This example demonstrates using shared utility methods from
/// 'package:devtools_app_shared/utils.dart'.
void main() {
  helperExample();
  immediateValueNotifierExample();
}

/// This method demonstrates using a helper methods [pluralize] and
/// [equalsWithinEpsilon] provided by 'package:devtools_app_shared/utils.dart'.
///
/// Other helper methods in this file can be used in a similar manner, as they
/// are documented.
void helperExample() {
  pluralize('dog', 1); // 'dog'
  pluralize('dog', 2); // 'dogs'
  pluralize('dog', 0); // 'dogs'

  pluralize('index', 1, plural: 'indices'); // 'index'
  pluralize('index', 2, plural: 'indices'); // 'indices'

  // Note: the [defaultEpsilon] this method uses is equal to 1 / 1000.
  // [defaultEpsilon] is also exposed by 'utils.dart'.
  equalsWithinEpsilon(1.111, 1.112); // true
  equalsWithinEpsilon(1.111, 1.113); // false
}

/// This method demonstrates using an [ImmediateValueNotifier] from
/// 'package:devtools_app_shared/utils.dart'.
void immediateValueNotifierExample() {
  final fooNotifier = ImmediateValueNotifier<int>(0);

  var count = 0;
  fooNotifier.addListener(() {
    count++;
  });

  print('count: $count'); // count = 1, since the listener is called immediately

  // change the value of the notifier to trigger the listener.
  fooNotifier.value = 1;

  print('count: $count'); // count = 2
}
