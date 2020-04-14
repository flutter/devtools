// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
import 'common.dart';

class Console extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return OutlinedBorder(
      child: Column(
        children: [
          debuggerSectionTitle(theme, text: 'Console'),
          const Expanded(
            child: Center(child: Text('todo:')),
          ),
        ],
      ),
    );
  }
}
