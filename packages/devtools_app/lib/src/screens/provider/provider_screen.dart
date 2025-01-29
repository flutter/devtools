// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/framework/screen.dart';
import '../../shared/ui/common_widgets.dart';

class ProviderScreen extends Screen {
  ProviderScreen() : super.fromMetaData(ScreenMetaData.provider);

  static final id = ScreenMetaData.provider.id;

  @override
  Widget buildScreenBody(BuildContext context) {
    return CenteredMessage(
      richMessage: [
        const TextSpan(
          text:
              'The Provider screen is now shipped as a DevTools extension.\n'
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
