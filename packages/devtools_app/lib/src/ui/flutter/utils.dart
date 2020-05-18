/*
 * Copyright 2020 The Chromium Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Used to create a Checkbox widget who's boolean value is attached
/// to a ValueNotifier<bool>.  This allows for the pattern:
///
/// Create the NotifierCheckbox widget in build e.g.,
///
///   myCheckboxWidget = NotifierCheckbox(notifier: controller.myCheckbox);
///
/// Add a listener in didChangeDependencies to rebuild when checkbox value
/// changes e.g.,
///
/// addAutoDisposeListener(controller.myCheckboxListenable, () {
///   setState(() {
///     myCheckbox.notifier.value = controller.myCheckbox.value;
///   });
/// });

/// Checkbox Widget class using a ValueNotifier.
class NotifierCheckbox extends Checkbox {
  NotifierCheckbox({
    Key key,
    @required this.notifier,
  }) : super(
          key: key,
          value: notifier.value,
          onChanged: notifier.onChanged,
        );

  final CheckboxValueNotifier notifier;

  /// Notifies that the value of the checkbox has changed.
  ValueListenable<bool> get valueListenable => notifier;
}

/// ValueNotifier associated with a Checkbox widget.
class CheckboxValueNotifier extends ValueNotifier<bool> {
  CheckboxValueNotifier(bool value) : super(value);

  void onChanged(bool newValue) {
    value = newValue;
  }
}
