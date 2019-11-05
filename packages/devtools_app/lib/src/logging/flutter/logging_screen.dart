// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';

import '../../flutter/screen.dart';
import '../../globals.dart';
import '../../service_extensions.dart';
import '../../ui/flutter/service_extension_widgets.dart';

/// Presents logs from the connected app.
class LoggingScreen extends Screen {
  const LoggingScreen() : super('Logging');

  @override
  Widget build(BuildContext context) {
    return LoggingScreenBody();
  }

  @override
  Widget buildTab(BuildContext context) {
    return Tab(
      text: 'Logging',
      icon: Icon(Octicons.getIconData('clippy')),
    );
  }
}

class LoggingScreenBody extends StatefulWidget {
  @override
  _LoggingScreenState createState() => _LoggingScreenState();
}

class _LoggingScreenState extends State<LoggingScreenBody> {
  @override
  void initState() {
    super.initState();
    // Enable structured errors by default as soon as the user opens the
    // logging page.
    serviceManager.serviceExtensionManager.setServiceExtensionState(
      structuredErrors.extension,
      true,
      true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RaisedButton(onPressed: _clearLogs, child: const Text('Clear logs')),
          StructuredErrorsCheckbox(),
        ],
      ),
    ]);
  }

  void _clearLogs() {
    // TODO(https://github.com/flutter/devtools/issues/1286): do this.
  }
}
