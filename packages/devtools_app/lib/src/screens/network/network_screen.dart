// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/config_specific/copy_to_clipboard/copy_to_clipboard.dart';
import '../../shared/config_specific/import_export/import_export.dart';
import '../../shared/feature_flags.dart';
import '../../shared/framework/screen.dart';
import '../../shared/http/curl_command.dart';
import '../../shared/http/http_request_data.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/ui/common_widgets.dart';
import '../../shared/ui/file_import.dart';
import '../../shared/ui/filter.dart';
import '../../shared/ui/search.dart';
import '../../shared/ui/utils.dart';
import '../../shared/utils/utils.dart';
import 'network_controller.dart';
import 'network_model.dart';
import 'network_request_inspector.dart';

class NetworkScreen extends Screen {
  NetworkScreen() : super.fromMetaData(ScreenMetaData.network);

  static final id = ScreenMetaData.network.id;

  @override
  String get docPageId => screenId;

  @override
  Widget buildScreenBody(BuildContext context) => const NetworkScreenBody();

  @override
  Widget buildDisconnectedScreenBody(BuildContext context) {
    return const DisconnectedNetworkScreenBody();
  }

  @override
  Widget buildStatus(BuildContext context) {
    final networkController = Provider.of<NetworkController>(context);
    final color = Theme.of(context).colorScheme.onPrimary;
    return MultiValueListenableBuilder(
      listenables: [networkController.requests, networkController.filteredData],
      builder: (context, values, child) {
        final networkRequests = values.first as List<NetworkRequest>;
        final filteredRequests = values.second as List<NetworkRequest>;
        final filteredCount = filteredRequests.length;
        final totalCount = networkRequests.length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Showing ${nf.format(filteredCount)} of '
              '${nf.format(totalCount)} '
              '${pluralize('request', totalCount)}',
            ),
            const SizedBox(width: denseSpacing),
            child!,
          ],
        );
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: networkController.recordingNotifier,
        builder: (context, recording, _) {
          return SizedBox(
            width: smallProgressSize,
            height: smallProgressSize,
            child:
                recording
                    ? SmallCircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    )
                    : const SizedBox(),
          );
        },
      ),
    );
  }
}

class DisconnectedNetworkScreenBody extends StatelessWidget {
  const DisconnectedNetworkScreenBody({super.key});

  static const importInstructions =
      'Open a network data file that was previously saved from DevTools.';

  @override
  Widget build(BuildContext context) {
    return FileImportContainer(
      instructions: importInstructions,
      actionText: 'Load data',
      gaScreen: gac.network,
      gaSelectionImport: gac.PerformanceEvents.openDataFile.name,
      gaSelectionAction: gac.PerformanceEvents.loadDataFromFile.name,
      onAction: (jsonFile) {
        Provider.of<ImportController>(
          context,
          listen: false,
        ).importData(jsonFile, expectedScreenId: NetworkScreen.id);
      },
    );
  }
}

class NetworkScreenBody extends StatefulWidget {
  const NetworkScreenBody({super.key});

  @override
  State<StatefulWidget> createState() => _NetworkScreenBodyState();
}

class _NetworkScreenBodyState extends State<NetworkScreenBody>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<NetworkController, NetworkScreenBody> {
  @override
  void initState() {
    super.initState();
    ga.screen(NetworkScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;
  }

  @override
  void dispose() {
    // TODO(kenz): this won't work well if we eventually have multiple clients
    // that want to listen to network data.
    super.dispose();
    unawaited(controller.stopRecording());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OfflineAwareControls(
          controlsBuilder:
              (offline) => _NetworkProfilerControls(
                controller: controller,
                offline: offline,
              ),
          gaScreen: gac.network,
        ),
        const SizedBox(height: intermediateSpacing),
        Expanded(child: _NetworkProfilerBody(controller: controller)),
      ],
    );
  }
}

/// The row of controls that control the Network profiler (e.g., record, pause,
/// clear, search, filter, etc.).
class _NetworkProfilerControls extends StatefulWidget {
  const _NetworkProfilerControls({
    required this.controller,
    required this.offline,
  });

  static const _includeTextWidth = 810.0;

  final NetworkController controller;

  final bool offline;

  @override
  State<_NetworkProfilerControls> createState() =>
      _NetworkProfilerControlsState();
}

class _NetworkProfilerControlsState extends State<_NetworkProfilerControls>
    with AutoDisposeMixin {
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _recording = widget.controller.recordingNotifier.value;
    addAutoDisposeListener(widget.controller.recordingNotifier, () {
      setState(() {
        _recording = widget.controller.recordingNotifier.value;
      });
    });

    addAutoDisposeListener(widget.controller.filteredData);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = ScreenSize(context).width;
    final hasRequests = widget.controller.filteredData.value.isNotEmpty;
    return Row(
      children: [
        if (!widget.offline) ...[
          StartStopRecordingButton(
            recording: _recording,
            onPressed:
                () async => await widget.controller.togglePolling(!_recording),
            tooltipOverride:
                _recording
                    ? 'Stop recording network traffic'
                    : 'Resume recording network traffic',
            minScreenWidthForTextBeforeScaling: double.infinity,
            gaScreen: gac.network,
            gaSelection: _recording ? gac.pause : gac.resume,
          ),
          const SizedBox(width: denseSpacing),
          ClearButton(
            minScreenWidthForTextBeforeScaling:
                _NetworkProfilerControls._includeTextWidth,
            gaScreen: gac.network,
            gaSelection: gac.clear,
            onPressed: widget.controller.clear,
          ),
          const SizedBox(width: denseSpacing),
          // TODO(kenz): fix focus issue when state is refreshed
          Expanded(
            child: SearchField<NetworkController>(
              searchController: widget.controller,
              searchFieldEnabled: hasRequests,
              searchFieldWidth:
                  screenWidth <= MediaSize.xs
                      ? defaultSearchFieldWidth
                      : wideSearchFieldWidth,
            ),
          ),
          const SizedBox(width: denseSpacing),
          Expanded(
            child: StandaloneFilterField<NetworkRequest>(
              controller: widget.controller,
              filteredItem: 'request',
            ),
          ),
          const SizedBox(width: denseSpacing),
          if (FeatureFlags.networkSaveLoad)
            OpenSaveButtonGroup(
              screenId: ScreenMetaData.network.id,
              saveFormats: const [SaveFormat.devtools, SaveFormat.har],
              gaItemForSaveFormatSelection:
                  (SaveFormat format) => switch (format) {
                    SaveFormat.devtools => gac.saveFile,
                    SaveFormat.har => gac.NetworkEvent.downloadAsHar.name,
                  },
              onSave: (SaveFormat format) async {
                switch (format) {
                  case SaveFormat.devtools:
                    await widget.controller.fetchFullDataBeforeExport();
                    widget.controller.exportData();
                  case SaveFormat.har:
                    await widget.controller.exportAsHarFile();
                }
              },
            )
          else
            DownloadButton(
              tooltip: 'Download as .har file',
              minScreenWidthForTextBeforeScaling:
                  _NetworkProfilerControls._includeTextWidth,
              onPressed: widget.controller.exportAsHarFile,
              gaScreen: gac.network,
              gaSelection: gac.NetworkEvent.downloadAsHar.name,
            ),
        ],
      ],
    );
  }
}

class _NetworkProfilerBody extends StatelessWidget {
  const _NetworkProfilerBody({required this.controller});

  final NetworkController controller;

  @override
  Widget build(BuildContext context) {
    final splitAxis = SplitPane.axisFor(context, 1.0);
    return SplitPane(
      initialFractions: splitAxis == Axis.horizontal ? [0.6, 0.4] : [0.5, 0.5],
      minSizes: const [200, 200],
      axis: splitAxis,
      children: [
        ValueListenableBuilder<List<NetworkRequest>>(
          valueListenable: controller.filteredData,
          builder: (context, filteredRequests, _) {
            return NetworkRequestsTable(
              networkController: controller,
              requests: filteredRequests,
              searchMatchesNotifier: controller.searchMatches,
              activeSearchMatchNotifier: controller.activeSearchMatch,
            );
          },
        ),
        NetworkRequestInspector(controller),
      ],
    );
  }
}

class NetworkRequestsTable extends StatelessWidget {
  const NetworkRequestsTable({
    super.key,
    required this.networkController,
    required this.requests,
    required this.searchMatchesNotifier,
    required this.activeSearchMatchNotifier,
  });

  static final methodColumn = MethodColumn();
  static final addressColumn = AddressColumn();
  static final statusColumn = StatusColumn();
  static final typeColumn = TypeColumn();
  static final durationColumn = DurationColumn();
  static final timestampColumn = TimestampColumn();
  static final actionsColumn = ActionsColumn();
  static final columns = <ColumnData<NetworkRequest>>[
    methodColumn,
    addressColumn,
    statusColumn,
    typeColumn,
    durationColumn,
    timestampColumn,
    actionsColumn,
  ];

  final NetworkController networkController;
  final List<NetworkRequest> requests;
  final ValueListenable<List<NetworkRequest>> searchMatchesNotifier;
  final ValueListenable<NetworkRequest?> activeSearchMatchNotifier;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      clip: true,
      child: SearchableFlatTable<NetworkRequest>(
        searchController: networkController,
        keyFactory: (NetworkRequest data) => ValueKey<NetworkRequest>(data),
        data: requests,
        dataKey: 'network-requests',
        autoScrollContent: true,
        columns: columns,
        selectionNotifier: networkController.selectedRequest,
        defaultSortColumn: timestampColumn,
        defaultSortDirection: SortDirection.ascending,
        onItemSelected: (item) {
          if (item is DartIOHttpRequestData) {
            unawaited(item.getFullRequestData());
            networkController.resetDropDown();
          }
        },
      ),
    );
  }
}

class AddressColumn extends ColumnData<NetworkRequest>
    implements ColumnRenderer<NetworkRequest> {
  AddressColumn()
    : super.wide(
        'Address',
        minWidthPx: scaleByFontFactor(isEmbedded() ? 100 : 150.0),
        showTooltip: true,
      );

  @override
  String getValue(NetworkRequest dataObject) {
    return dataObject.uri;
  }

  @override
  Widget build(
    BuildContext context,
    NetworkRequest data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    final value = getDisplayValue(data);

    return SelectableText(
      value,
      maxLines: 1,
      style: const TextStyle(overflow: TextOverflow.ellipsis),
      // [onPressed] needs to be passed along to [SelectableText] so that a
      // click on the text will still trigger the [onPressed] action for the
      // row.
      onTap: onPressed,
    );
  }
}

class MethodColumn extends ColumnData<NetworkRequest> {
  MethodColumn() : super('Method', fixedWidthPx: scaleByFontFactor(60));

  @override
  String getValue(NetworkRequest dataObject) {
    return dataObject.method;
  }
}

class ActionsColumn extends ColumnData<NetworkRequest>
    implements ColumnRenderer<NetworkRequest> {
  ActionsColumn()
    : super(
        '',
        fixedWidthPx: scaleByFontFactor(32),
        alignment: ColumnAlignment.right,
      );

  @override
  bool get supportsSorting => false;

  @override
  bool get includeHeader => false;

  @override
  String getValue(NetworkRequest dataObject) {
    return '';
  }

  @override
  Widget build(
    BuildContext context,
    NetworkRequest data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    // Only show the actions button when there are options and the row is
    // currently selected.
    if (data is! DartIOHttpRequestData || !isRowSelected) {
      return const SizedBox.shrink();
    }

    return ContextMenuButton(
      menuChildren: [
        MenuItemButton(
          child: const Text('Copy as URL'),
          onPressed: () {
            unawaited(
              copyToClipboard(
                data.uri,
                successMessage: 'Copied the URL to the clipboard',
              ),
            );
          },
        ),
        MenuItemButton(
          child: const Text('Copy as cURL'),
          onPressed: () {
            unawaited(
              copyToClipboard(
                CurlCommand.from(data).toString(),
                successMessage: 'Copied the cURL command to the clipboard',
              ),
            );
          },
        ),
      ],
    );
  }
}

class StatusColumn extends ColumnData<NetworkRequest>
    implements ColumnRenderer<NetworkRequest> {
  StatusColumn()
    : super(
        'Status',
        alignment: ColumnAlignment.right,
        headerAlignment: TextAlign.right,
        fixedWidthPx: scaleByFontFactor(50),
      );

  @override
  String? getValue(NetworkRequest dataObject) {
    return dataObject.status;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return dataObject.status == null ? '--' : dataObject.status.toString();
  }

  @override
  Widget build(
    BuildContext context,
    NetworkRequest data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    final theme = Theme.of(context);
    return Text(
      getDisplayValue(data),
      style:
          data.didFail
              ? TextStyle(color: theme.colorScheme.error)
              : theme.regularTextStyle,
    );
  }
}

class TypeColumn extends ColumnData<NetworkRequest> {
  TypeColumn()
    : super(
        'Type',
        alignment: ColumnAlignment.right,
        headerAlignment: TextAlign.right,
        fixedWidthPx: scaleByFontFactor(50),
      );

  @override
  String getValue(NetworkRequest dataObject) {
    return dataObject.type;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return dataObject.type;
  }
}

class DurationColumn extends ColumnData<NetworkRequest> {
  DurationColumn()
    : super(
        'Duration',
        alignment: ColumnAlignment.right,
        headerAlignment: TextAlign.right,
        fixedWidthPx: scaleByFontFactor(75),
      );

  @override
  int? getValue(NetworkRequest dataObject) {
    return dataObject.duration?.inMilliseconds;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    final ms = getValue(dataObject);
    return ms == null
        ? 'Pending'
        : durationText(Duration(milliseconds: ms), fractionDigits: 0);
  }
}

class TimestampColumn extends ColumnData<NetworkRequest> {
  TimestampColumn()
    : super(
        'Timestamp',
        alignment: ColumnAlignment.right,
        headerAlignment: TextAlign.right,
        fixedWidthPx: scaleByFontFactor(115),
      );

  @override
  DateTime? getValue(NetworkRequest dataObject) {
    return dataObject.startTimestamp;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return formatDateTime(dataObject.startTimestamp!);
  }
}
