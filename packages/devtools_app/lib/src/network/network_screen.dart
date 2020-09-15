// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../auto_dispose_mixin.dart';
import '../common_widgets.dart';
import '../dialogs.dart';
import '../screen.dart';
import '../split.dart';
import '../table.dart';
import '../table_data.dart';
import '../theme.dart';
import '../ui/label.dart';
import '../ui/search.dart';
import '../utils.dart';
import 'network_controller.dart';
import 'network_model.dart';
import 'network_request_inspector.dart';

final networkSearchFieldKey = GlobalKey(debugLabel: 'NetworkSearchFieldKey');

class NetworkScreen extends Screen {
  const NetworkScreen()
      : super.conditional(
          id: id,
          requiresDartVm: true,
          title: 'Network',
          icon: Icons.network_check,
        );

  static const id = 'network';

  @visibleForTesting
  static const clearButtonKey = Key('Clear Button');
  @visibleForTesting
  static const stopButtonKey = Key('Stop Button');
  @visibleForTesting
  static const recordButtonKey = Key('Record Button');
  @visibleForTesting
  static const recordingInstructionsKey = Key('Recording Instructions');

  @override
  Widget build(BuildContext context) => const NetworkScreenBody();

  @override
  Widget buildStatus(BuildContext context, TextTheme textTheme) {
    final networkController = Provider.of<NetworkController>(context);
    final color = Theme.of(context).textTheme.bodyText2.color;

    return ValueListenableBuilder<bool>(
      valueListenable: networkController.recordingNotifier,
      builder: (context, recording, _) {
        return ValueListenableBuilder<NetworkRequests>(
          valueListenable: networkController.requests,
          builder: (context, networkRequests, _) {
            return ValueListenableBuilder<List<NetworkRequest>>(
              valueListenable: networkController.filteredRequests,
              builder: (context, filteredRequests, _) {
                final filteredCount = filteredRequests.length;
                final totalCount = networkRequests.requests.length;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Showing ${nf.format(filteredCount)} of '
                      '${nf.format(totalCount)} '
                      '${pluralize('request', totalCount)}',
                    ),
                    const SizedBox(width: denseSpacing),
                    SizedBox(
                      width: smallProgressSize,
                      height: smallProgressSize,
                      child: recording
                          ? CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            )
                          : const SizedBox(),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class NetworkScreenBody extends StatefulWidget {
  const NetworkScreenBody();

  @override
  State<StatefulWidget> createState() => _NetworkScreenBodyState();
}

class _NetworkScreenBodyState extends State<NetworkScreenBody>
    with AutoDisposeMixin, SearchFieldMixin {
  NetworkController _networkController;

  bool recording;

  NetworkRequests requests;

  List<NetworkRequest> filteredRequests;

  @override
  void initState() {
    super.initState();
    ga.screen(NetworkScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<NetworkController>(context);
    if (newController == _networkController) return;

    _networkController?.removeClient();

    _networkController = newController;
    _networkController.addClient();

    requests = _networkController.requests.value;
    addAutoDisposeListener(_networkController.requests, () {
      setState(() {
        requests = _networkController.requests.value;
      });
    });
    recording = _networkController.recordingNotifier.value;
    addAutoDisposeListener(_networkController.recordingNotifier, () {
      setState(() {
        recording = _networkController.recordingNotifier.value;
      });
    });
    filteredRequests = _networkController.filteredRequests.value;
    addAutoDisposeListener(_networkController.filteredRequests, () {
      setState(() {
        filteredRequests = _networkController.filteredRequests.value;
      });
    });
  }

  @override
  void dispose() {
    _networkController?.removeClient();
    super.dispose();
  }

  /// Builds the row of buttons that control the Network profiler (e.g., record,
  /// pause, etc.)
  Row _buildProfilerControls() {
    const double includeTextWidth = 600;
    final hasRequests = filteredRequests.isNotEmpty;
    return Row(
      children: [
        recordButton(
          key: NetworkScreen.recordButtonKey,
          recording: recording,
          labelOverride: 'Record network traffic',
          includeTextWidth: includeTextWidth,
          onPressed: _networkController.startRecording,
        ),
        const SizedBox(width: denseSpacing),
        stopRecordingButton(
          key: NetworkScreen.stopButtonKey,
          recording: recording,
          includeTextWidth: includeTextWidth,
          onPressed: _networkController.stopRecording,
        ),
        const SizedBox(width: denseSpacing),
        clearButton(
          key: NetworkScreen.clearButtonKey,
          onPressed: () {
            _networkController.clear();
          },
        ),
        const Expanded(child: SizedBox()),
        Container(
          width: wideSearchTextWidth,
          height: defaultTextFieldHeight,
          child: buildSearchField(
            controller: _networkController,
            searchFieldKey: networkSearchFieldKey,
            searchFieldEnabled: hasRequests,
            shouldRequestFocus: false,
            supportsNavigation: true,
          ),
        ),
        const SizedBox(width: denseSpacing),
        FilterButton(
          onPressed: _showFilterDialog,
          isFilterActive: filteredRequests.length != requests.requests.length,
        ),
      ],
    );
  }

  Widget _buildProfilerBody() {
    return ValueListenableBuilder<NetworkRequest>(
      valueListenable: _networkController.selectedRequest,
      builder: (context, selectedRequest, _) {
        return Expanded(
          child: (!recording && filteredRequests.isEmpty)
              ? Center(
                  child: recordingInfo(
                    instructionsKey: NetworkScreen.recordingInstructionsKey,
                    recording: recording,
                    // TODO(kenz): create a processing notifier if necessary
                    // for this data.
                    processing: false,
                    recordedObject: 'network traffic',
                    isPause: true,
                  ),
                )
              : Split(
                  initialFractions: const [0.5, 0.5],
                  minSizes: const [200, 200],
                  axis: Axis.horizontal,
                  children: [
                    NetworkRequestsTable(
                      networkController: _networkController,
                      requests: filteredRequests,
                      searchMatchesNotifier: _networkController.searchMatches,
                      activeSearchMatchNotifier:
                          _networkController.activeSearchMatch,
                    ),
                    NetworkRequestInspector(selectedRequest),
                  ],
                ),
        );
      },
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => NetworkFilterDialog(_networkController),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildProfilerControls(),
        const SizedBox(height: denseRowSpacing),
        _buildProfilerBody(),
      ],
    );
  }
}

class NetworkRequestsTable extends StatelessWidget {
  const NetworkRequestsTable({
    Key key,
    @required this.networkController,
    @required this.requests,
    @required this.searchMatchesNotifier,
    @required this.activeSearchMatchNotifier,
  }) : super(key: key);

  static MethodColumn methodColumn = MethodColumn();
  static UriColumn addressColumn = UriColumn();
  static StatusColumn statusColumn = StatusColumn();
  static TypeColumn typeColumn = TypeColumn();
  static DurationColumn durationColumn = DurationColumn();
  static TimestampColumn timestampColumn = TimestampColumn();

  final NetworkController networkController;
  final List<NetworkRequest> requests;
  final ValueListenable<List<NetworkRequest>> searchMatchesNotifier;
  final ValueListenable<NetworkRequest> activeSearchMatchNotifier;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration(
      child: FlatTable<NetworkRequest>(
        columns: [
          methodColumn,
          addressColumn,
          statusColumn,
          typeColumn,
          durationColumn,
          timestampColumn,
        ],
        data: requests,
        keyFactory: (NetworkRequest data) => ValueKey<NetworkRequest>(data),
        onItemSelected: (item) {
          networkController.selectRequest(item);
        },
        autoScrollContent: true,
        sortColumn: timestampColumn,
        sortDirection: SortDirection.ascending,
        searchMatchesNotifier: searchMatchesNotifier,
        activeSearchMatchNotifier: activeSearchMatchNotifier,
      ),
    );
  }
}

class UriColumn extends ColumnData<NetworkRequest>
    implements ColumnRenderer<NetworkRequest> {
  UriColumn() : super.wide('Uri');

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.uri;
  }

  @override
  Widget build(BuildContext context, NetworkRequest data) {
    final value = getDisplayValue(data);

    return Tooltip(
      message: value,
      waitDuration: tooltipWait,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class MethodColumn extends ColumnData<NetworkRequest> {
  MethodColumn() : super('Method', fixedWidthPx: 70);

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.method;
  }
}

class StatusColumn extends ColumnData<NetworkRequest> {
  StatusColumn()
      : super('Status', alignment: ColumnAlignment.right, fixedWidthPx: 62);

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.status;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return dataObject.status == null ? '--' : dataObject.status.toString();
  }
}

class TypeColumn extends ColumnData<NetworkRequest> {
  TypeColumn()
      : super('Type', alignment: ColumnAlignment.right, fixedWidthPx: 62);

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.type;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return dataObject.type == null ? '--' : dataObject.type;
  }
}

class DurationColumn extends ColumnData<NetworkRequest> {
  DurationColumn()
      : super('Duration', alignment: ColumnAlignment.right, fixedWidthPx: 80);

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.duration?.inMilliseconds;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    final ms = getValue(dataObject);
    return ms == null
        ? 'Pending'
        : msText(
            Duration(milliseconds: ms),
            fractionDigits: 0,
          );
  }
}

class TimestampColumn extends ColumnData<NetworkRequest> {
  TimestampColumn()
      : super('Timestamp', alignment: ColumnAlignment.right, fixedWidthPx: 135);

  @override
  dynamic getValue(NetworkRequest dataObject) {
    return dataObject.startTimestamp;
  }

  @override
  String getDisplayValue(NetworkRequest dataObject) {
    return formatDateTime(dataObject.startTimestamp);
  }
}

class NetworkFilterDialog extends StatefulWidget {
  const NetworkFilterDialog(this.controller);

  final NetworkController controller;

  @override
  _NetworkFilterDialogState createState() => _NetworkFilterDialogState();
}

class _NetworkFilterDialogState extends State<NetworkFilterDialog> {
  static const dialogWidth = 400.0;

  NetworkFilter currentFilter;

  TextEditingController uriSubstringTextFieldController;

  TextEditingController methodTextFieldController;

  TextEditingController statusTextFieldController;

  TextEditingController typeTextFieldController;

  @override
  void initState() {
    super.initState();
    currentFilter = NetworkFilter.from(widget.controller.activeFilter.value);
    uriSubstringTextFieldController =
        TextEditingController(text: currentFilter.uriSubstring);
    methodTextFieldController =
        TextEditingController(text: currentFilter.method);
    statusTextFieldController =
        TextEditingController(text: currentFilter.status);
    typeTextFieldController = TextEditingController(text: currentFilter.type);
  }

  @override
  Widget build(BuildContext context) {
    return DevToolsDialog(
      title: _buildDialogTitle(),
      content: Container(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._buildFilterTextFields(),
            const SizedBox(height: defaultSpacing),
            ..._buildFilterCheckboxes(),
          ],
        ),
      ),
      actions: [
        DialogApplyButton(
          onPressed: () {
            widget.controller.filterData(currentFilter);
          },
        ),
        DialogCancelButton(),
      ],
    );
  }

  Widget _buildDialogTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        dialogTitleText(Theme.of(context), 'Filters'),
        FlatButton(
          onPressed: _resetFilter,
          child: const MaterialIconLabel(
            Icons.replay,
            'Reset to default',
          ),
        ),
      ],
    );
  }

  List<Widget> _buildFilterTextFields() {
    return [
      _buildText(
        description: 'Uri',
        textController: uriSubstringTextFieldController,
        onChanged: (value) {
          setState(() {
            currentFilter.uriSubstring = value;
          });
        },
      ),
      const SizedBox(height: defaultSpacing),
      _buildText(
        description: 'Method (e.g. GET, POST, PUT, etc.)',
        textController: methodTextFieldController,
        onChanged: (value) {
          setState(() {
            currentFilter.method = value;
          });
        },
      ),
      const SizedBox(height: defaultSpacing),
      _buildText(
        description: 'Status (e.g. 200, 404, 101, etc.)',
        textController: statusTextFieldController,
        onChanged: (value) {
          setState(() {
            currentFilter.status = value;
          });
        },
      ),
      const SizedBox(height: defaultSpacing),
      _buildText(
        description: 'Type (e.g. htm, json, ws, etc.)',
        textController: typeTextFieldController,
        onChanged: (value) {
          setState(() {
            currentFilter.type = value;
          });
        },
      ),
    ];
  }

  List<Widget> _buildFilterCheckboxes() {
    return [
      _buildCheckbox(
        value: currentFilter.showHttp,
        description: 'HTTP traffic',
        onChanged: (value) {
          setState(() {
            currentFilter.showHttp = value;
          });
        },
      ),
      _buildCheckbox(
        value: currentFilter.showWebSocket,
        description: 'Web socket traffic',
        onChanged: (value) {
          setState(() {
            currentFilter.showWebSocket = value;
          });
        },
      ),
    ];
  }

  Widget _buildCheckbox({
    @required bool value,
    @required String description,
    @required void Function(bool value) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
        ),
        Flexible(
          child: Text(
            description,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }

  Widget _buildText({
    @required String description,
    @required TextEditingController textController,
    @required void Function(String value) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: defaultSpacing,
      ),
      height: defaultTextFieldHeight,
      child: TextField(
        controller: textController,
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(denseSpacing),
          border: const OutlineInputBorder(),
          labelText: description,
          suffix: clearInputButton(textController.clear),
        ),
      ),
    );
  }

  void _resetFilter() {
    setState(() {
      currentFilter = NetworkController.defaultFilter;
      uriSubstringTextFieldController.clear();
      methodTextFieldController.clear();
      statusTextFieldController.clear();
      typeTextFieldController.clear();
    });
  }
}
