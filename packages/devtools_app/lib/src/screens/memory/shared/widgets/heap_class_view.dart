// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../../../devtools_app.dart';
import '../heap/model.dart';

class HeapClassView extends StatelessWidget {
  const HeapClassView({super.key, required this.theClass});

  final HeapClassName theClass;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        maybeWrapWithTooltip(
          tooltip: theClass.fullName,
          child: Text(theClass.className),
        ),
        CopyToClipboardControl(
          dataProvider: () => theClass.fullName,
          tooltip: 'Copy full class name to clipboard.',
        ),
      ],
    );
  }
}
