// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../service/service_extension_widgets.dart';
import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/common_widgets.dart';
import '../../../shared/globals.dart';
import 'logging_model.dart';
import 'logging_table_row.dart';

/// A builder that includes an Offset to draw the context menu at.
typedef ContextMenuBuilder = Widget Function(
  BuildContext context,
  Offset offset,
);

/// A Widget for displaying logs with line wrapping, along with log metadata.
class LoggingTableV2 extends StatefulWidget {
  // TODO(danchevalier): Use SearchControllerMixin and FilterControllerMixin.
  const LoggingTableV2({super.key, required this.model});

  final LoggingTableModel model;

  @override
  State<LoggingTableV2> createState() => _LoggingTableV2State();
}

class _LoggingTableV2State extends State<LoggingTableV2> {
  final selections = <int>{};
  final cachedOffets = <int, double>{};
  String lastSearch = '';
  double maxWidth = 0.0;

  @override
  void initState() {
    super.initState();
    // On web, disable the browser's context menu since this example uses a custom
    // Flutter-rendered context menu.
    if (kIsWeb) {
      unawaited(BrowserContextMenu.disableContextMenu());
    }
  }

  @override
  void dispose() {
    if (kIsWeb) {
      unawaited(BrowserContextMenu.enableContextMenu());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DevToolsClearableTextField(
                labelText: 'Filter',
                onSubmitted: (value) {},
              ),
            ),
            const SizedBox(width: defaultSpacing),
            Expanded(
              child: DevToolsClearableTextField(
                labelText: 'Search',
              ),
            ),
            const SizedBox(width: defaultSpacing),
            SettingsOutlinedButton(
              gaScreen: gac.logging,
              gaSelection: gac.loggingSettings,
              tooltip: 'Logging Settings',
              onPressed: () {
                unawaited(
                  showDialog(
                    context: context,
                    builder: (context) => const LoggingSettingsDialogV2(),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: denseSpacing),
        Expanded(
          child: _LoggingTableProgress(
            model: widget.model,
          ),
        ),
      ],
    );
  }
}

class _LoggingTableProgress extends StatefulWidget {
  const _LoggingTableProgress({
    required this.model,
  });

  final LoggingTableModel model;

  @override
  State<_LoggingTableProgress> createState() => _LoggingTableProgressState();
}

class _LoggingTableProgressState extends State<_LoggingTableProgress> {
  static const _millisecondsUntilCacheProgressShows = 500;
  static const _millisecondsUntilCacheProgressHelperShows = 2000;

  final _progressStopwatch = Stopwatch();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.model.tableWidth = constraints.maxWidth;
        _progressStopwatch.reset();
        return ValueListenableBuilder(
          valueListenable: widget.model.cacheLoadProgress,
          builder: (context, cacheLoadProgress, _) {
            if (cacheLoadProgress != null) {
              double progress = cacheLoadProgress;
              if (!_progressStopwatch.isRunning) {
                _progressStopwatch.start();
              }

              if (_progressStopwatch.elapsedMilliseconds <
                  _millisecondsUntilCacheProgressShows) {
                progress = 0.0;
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Resizing... this will only take a moment.',
                    ),
                    const SizedBox(height: defaultSpacing),
                    SizedBox(
                      width: defaultLinearProgressIndicatorWidth,
                      height: defaultLinearProgressIndicatorHeight,
                      child: LinearProgressIndicator(
                        value: progress,
                      ),
                    ),
                    const SizedBox(height: defaultSpacing),
                    if (_progressStopwatch.elapsedMilliseconds >
                        _millisecondsUntilCacheProgressHelperShows)
                      const Text(
                        'To make this process faster, reduce the "Log Retention" setting.',
                      ),
                  ],
                ),
              );
            } else {
              _progressStopwatch
                ..stop()
                ..reset();
              return _LoggingTableRows(model: widget.model);
            }
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _progressStopwatch.stop();
    super.dispose();
  }
}

class _LoggingTableRows extends StatefulWidget {
  const _LoggingTableRows({required this.model});

  final LoggingTableModel model;

  @override
  State<_LoggingTableRows> createState() => _LoggingTableRowsState();
}

class _LoggingTableRowsState extends State<_LoggingTableRows>
    with AutoDisposeMixin {
  late final _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(widget.model);
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      controller: _verticalController,
      child: CustomScrollView(
        controller: _verticalController,
        slivers: <Widget>[
          SliverVariedExtentList.builder(
            itemCount: widget.model.filteredLogCount,
            itemBuilder: (context, index) {
              return LoggingTableRow(
                index: index,
                data: widget.model.filteredLogAt(index),
                isSelected: false,
              );
            },
            itemExtentBuilder: (index, _) =>
                widget.model.getFilteredLogHeight(index),
          ),
        ],
      ),
    );
  }
}

class LoggingSettingsDialogV2 extends StatefulWidget {
  const LoggingSettingsDialogV2({super.key});

  @override
  State<LoggingSettingsDialogV2> createState() =>
      _LoggingSettingsDialogV2State();
}

class _LoggingSettingsDialogV2State extends State<LoggingSettingsDialogV2> {
  late final ValueNotifier<int> newRetentionLimit;

  @override
  void initState() {
    super.initState();
    newRetentionLimit =
        ValueNotifier<int>(preferences.logging.retentionLimit.value);
  }

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
          const SizedBox(height: defaultSpacing),
          PositiveIntegerSetting(
            title: preferences.logging.retentionLimitTitle,
            subTitle: 'Used to limit the number of log messages retained.',
            notifier: newRetentionLimit,
          ),
        ],
      ),
      actions: [
        DialogApplyButton(
          onPressed: () {
            preferences.logging.retentionLimit.value = newRetentionLimit.value;
          },
        ),
        const DialogCloseButton(),
      ],
    );
  }
}
