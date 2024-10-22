// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../service/service_extension_widgets.dart';
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/search.dart';
import 'logging_controller.dart';
import 'shared/constants.dart';

class LoggingControls extends StatelessWidget {
  const LoggingControls({super.key});

  static const filterQueryInstructions = '''
Type a filter query to show or hide specific logs.

Any text that is not paired with an available filter key below will be queried against all categories (kind, message).

Available filters:
    'kind', 'k'       (e.g. 'k:flutter.frame', '-k:gc,stdout')

Example queries:
    'my log message k:stdout,stdin'
    'flutter -k:gc'
''';

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<LoggingController>(context);
    final hasData = controller.filteredData.value.isNotEmpty;
    return Row(
      children: [
        ClearButton(
          onPressed: controller.clear,
          gaScreen: gac.logging,
          gaSelection: gac.clear,
          minScreenWidthForTextBeforeScaling: loggingMinVerboseWidth,
        ),
        const SizedBox(width: denseSpacing),
        Expanded(
          // TODO(kenz): fix focus issue when state is refreshed
          child: SearchField<LoggingController>(
            searchFieldWidth: isScreenWiderThan(context, loggingMinVerboseWidth)
                ? wideSearchFieldWidth
                : defaultSearchFieldWidth,
            searchController: controller,
            searchFieldEnabled: hasData,
            containerPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: denseSpacing),
        Expanded(
          child: StandaloneFilterField<LogData>(
            controller: controller,
            filteredItem: 'log',
          ),
        ),
        const SizedBox(width: denseSpacing),
        CopyToClipboardControl(
          dataProvider: () => controller.filteredData.value
              .map((e) => '${e.timestamp} [${e.kind}] ${e.prettyPrinted()}')
              .joinWithTrailing('\n'),
          tooltip: 'Copy filtered logs',
        ),
        const SizedBox(width: denseSpacing),
        SettingsOutlinedButton(
          gaScreen: gac.logging,
          gaSelection: gac.loggingSettings,
          tooltip: 'Logging Settings',
          onPressed: () {
            unawaited(
              showDialog(
                context: context,
                builder: (context) => const LoggingSettingsDialog(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class LoggingSettingsDialog extends StatelessWidget {
  const LoggingSettingsDialog({super.key});

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
