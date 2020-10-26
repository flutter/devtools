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
        RecordButton(
          recording: recording,
          labelOverride: 'Record network traffic',
          includeTextWidth: includeTextWidth,
          onPressed: _networkController.startRecording,
        ),
        const SizedBox(width: denseSpacing),
        StopRecordingButton(
          recording: recording,
          includeTextWidth: includeTextWidth,
          onPressed: _networkController.stopRecording,
        ),
        const SizedBox(width: denseSpacing),
        ClearButton(
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
                  child: RecordingInfo(
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

class StatusColumn extends ColumnData<NetworkRequest>
    implements ColumnRenderer<NetworkRequest> {
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

  @override
  Widget build(BuildContext context, NetworkRequest data) {
    final theme = Theme.of(context);
    return Text(
      getDisplayValue(data),
      style: data.didFail
          ? theme.regularTextStyle.copyWith(color: devtoolsError)
          : theme.regularTextStyle,
    );
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
  static const dialogWidth = 500.0;

  static const queryInstructions = '''
Type a filter query to show specific requests.

Any text that is not paired with an available filter key below will be queried against all categories (method, uri, status, type).

Available filters:
    'method', 'm'       (e.g. 'm:get', 'm:put')
    'status', 's'           (e.g. 's:200', 's:404')
    'type', 't'               (e.g. 't:json', 't:ws')

Example queries:
    'my-endpoint method:put status:404 type:json'
    'example.com m:get s:200 t:htm'
    'http s:404'
    'POST'
''';

  TextEditingController queryTextFieldController;

  @override
  void initState() {
    super.initState();
    queryTextFieldController =
        TextEditingController(text: widget.controller.activeFilter.value.query);
  }

  @override
  Widget build(BuildContext context) {
    return DevToolsDialog(
      title: _buildDialogTitle(),
      content: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: defaultSpacing,
        ),
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQueryTextField(),
            const SizedBox(height: defaultSpacing),
            _buildQueryInstructions(),
          ],
        ),
      ),
      actions: [
        DialogApplyButton(
          onPressed: () {
            widget.controller.filterData(
                NetworkFilter.fromQuery(queryTextFieldController.value.text));
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
          onPressed: queryTextFieldController.clear,
          child: const MaterialIconLabel(
            Icons.replay,
            'Reset to default',
          ),
        ),
      ],
    );
  }

  Widget _buildQueryTextField() {
    return Container(
      height: defaultTextFieldHeight,
      child: TextField(
        controller: queryTextFieldController,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.all(denseSpacing),
          border: const OutlineInputBorder(),
          labelText: 'Filter query',
          suffix: clearInputButton(queryTextFieldController.clear),
        ),
      ),
    );
  }

  Widget _buildQueryInstructions() {
    return Text(
      queryInstructions,
      style: Theme.of(context).subtleTextStyle,
    );
  }
}
