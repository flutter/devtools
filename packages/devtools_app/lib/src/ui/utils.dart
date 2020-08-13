/*
 * Copyright 2020 The Chromium Authors. All rights reserved.
 * Use of this source code is governed by a BSD-style license that can be
 * found in the LICENSE file.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../auto_dispose_mixin.dart';

/// Stateful Checkbox Widget class using a [ValueNotifier].
///
/// Used to create a Checkbox widget who's boolean value is attached
/// to a [ValueNotifier<bool>].  This allows for the pattern:
///
/// Create the [NotifierCheckbox] widget in build e.g.,
///
///   myCheckboxWidget = NotifierCheckbox(notifier: controller.myCheckbox);
///
/// The checkbox and the value notifier are now linked with clicks updating the
/// [ValueNotifier] and changes to the [ValueNotifier] updating the checkbox.
class NotifierCheckbox extends StatefulWidget {
  const NotifierCheckbox({
    Key key,
    @required this.notifier,
  }) : super(key: key);

  final ValueNotifier<bool> notifier;

  @override
  _NotifierCheckboxState createState() => _NotifierCheckboxState();
}

class _NotifierCheckboxState extends State<NotifierCheckbox>
    with AutoDisposeMixin {
  bool currentValue;

  @override
  void initState() {
    super.initState();
    _trackValue();
  }

  @override
  void didUpdateWidget(NotifierCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.notifier == widget.notifier) return;

    cancel();
    _trackValue();
  }

  void _trackValue() {
    _updateValue();
    addAutoDisposeListener(widget.notifier, _updateValue);
  }

  void _updateValue() {
    if (currentValue == widget.notifier.value) return;
    setState(() {
      currentValue = widget.notifier.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: currentValue,
      onChanged: (value) {
        widget.notifier.value = value;
      },
    );
  }
}
