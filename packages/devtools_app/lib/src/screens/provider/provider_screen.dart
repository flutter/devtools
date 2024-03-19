// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.


import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import '../../shared/screen.dart';

class ProviderScreen extends Screen {
  ProviderScreen() : super.fromMetaData(ScreenMetaData.provider);

  static final id = ScreenMetaData.provider.id;

  @override
  Widget buildScreenBody(BuildContext context) {
    return CenteredMessage(
      richMessage: [
        const TextSpan(
          text: 'The Provider screen is now shipped as a DevTools extension.\n'
              'If you want to use this tool, please upgrade your ',
        ),
        TextSpan(
          text: 'package:provider',
          style: Theme.of(context).fixedFontStyle,
        ),
        const TextSpan(
          text: ' dependency to the latest version, and then re-open DevTools.',
        ),
      ],
    );
  }
}
