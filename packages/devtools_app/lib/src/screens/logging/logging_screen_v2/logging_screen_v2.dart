// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../../service/service_extension_widgets.dart';
import '../../../shared/analytics/analytics.dart' as ga;
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/screen.dart';
import '../../../shared/utils.dart';
import 'logging_controller_v2.dart';
import 'logging_table_v2.dart';

/// Presents logs from the connected app.
class LoggingScreenV2 extends Screen {
  LoggingScreenV2()
      : super(
          id,
          title: ScreenMetaData.logging.title,
          icon: ScreenMetaData.logging.icon,
        );

  static final id = ScreenMetaData.logging.id;

  @override
  String get docPageId => screenId;

  @override
  Widget buildScreenBody(BuildContext context) => const LoggingScreenBodyV2();

  @override
  Widget buildStatus(BuildContext context) {
    final LoggingControllerV2 controller =
        Provider.of<LoggingControllerV2>(context);

    return StreamBuilder<String>(
      initialData: controller.statusText,
      stream: controller.onLogStatusChanged,
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        return Text(snapshot.data ?? '');
      },
    );
  }
}

class LoggingScreenBodyV2 extends StatefulWidget {
  const LoggingScreenBodyV2({super.key});

  @override
  State<LoggingScreenBodyV2> createState() => _LoggingScreenBodyV2State();
}

class _LoggingScreenBodyV2State extends State<LoggingScreenBodyV2>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<LoggingControllerV2, LoggingScreenBodyV2> {
  List<String> items = [];
  late List<LogDataV2> filteredLogs;
  @override
  void initState() {
    super.initState();
    ga.screen(gac.logging);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    cancelListeners();

    filteredLogs = controller.filteredData.value;
    addAutoDisposeListener(controller.filteredData, () {
      setState(() {
        filteredLogs = controller.filteredData.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoggingTableV2(
      model: controller.loggingModel,
    );
  }
}

class LoggingSettingsDialogV2 extends StatelessWidget {
  const LoggingSettingsDialogV2({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DevToolsDialog(
      title: const DialogTitleText('Logging Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...dialogSubHeader(
            theme,
            'General',
          ),
          const StructuredErrorsToggle(),
        ],
      ),
      actions: const [
        DialogCloseButton(),
      ],
    );
  }
}
