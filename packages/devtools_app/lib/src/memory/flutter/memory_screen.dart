// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:path/path.dart' as _path;

import '../../flutter/controllers.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../globals.dart';
import '../../ui/flutter/label.dart';
import '../memory_controller.dart';
import 'memory_chart.dart';

const String _filenamePrefix = 'memory_log_';

// Memory Log filename.
final String _memoryLogFilename =
    '$_filenamePrefix${DateFormat("yyyyMMdd_hh_mm").format(DateTime.now())}';

class MemoryScreen extends Screen {
  const MemoryScreen();

  @override
  Widget build(BuildContext context) => const MemoryBody();

  @override
  Widget buildTab(BuildContext context) {
    return const Tab(
      text: 'Memory',
      icon: Icon(Octicons.package),
    );
  }
}

class MemoryBody extends StatefulWidget {
  const MemoryBody();

  @override
  MemoryBodyState createState() => MemoryBodyState();
}

class MemoryBodyState extends State<MemoryBody> {
  MemoryChart _memoryChart;

  MemoryController get _controller => Controllers.of(context).memory;

  @override
  void initState() {
    _updateListeningState();

    super.initState();
  }

  @override
  void dispose() {
    // TODO(terry): make my controller disposable via DisposableController and dispose here.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _memoryChart = MemoryChart();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _leftsideButtons(),
            _rightsideButtons(),
          ],
        ),
        Expanded(
          child: Split(
            axis: Axis.vertical,
            firstChild: _memoryChart,
            secondChild: const Text('Memory Panel TBD capacity'),
            initialFirstFraction: 0.25,
          ),
        ),
      ],
    );
  }

  static const String _liveFeed = 'Live Feed';
  String memorySource = _liveFeed;

  Widget createMenuItem(String name) {
    final rowChildren = memorySource == name
        ? [
            Icon(Icons.check, size: 12),
            const SizedBox(width: 10),
            Text(name),
          ]
        : [
            const SizedBox(width: 22),
            Text(name),
          ];

    return PopupMenuItem<String>(
      value: name,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: rowChildren,
      ),
    );
  }

  Widget _selectMemoryFile() {
    final List<String> files = offlineFiles();

    final List<PopupMenuItem<String>> items = [
      createMenuItem(_liveFeed),
    ];

    for (var index = 0; index < files.length; index++) {
      items.add(createMenuItem(files[index]));
    }

    return PopupMenuButton<String>(
      onSelected: (value) {
        setState(() {
          memorySource = value;

          if (memorySource == _liveFeed) {
            if (_controller.offline) {
              // User is switching back to 'Live Feed'.
              _controller.memoryTimeline.offflineData.clear();
              _controller.offline = false; // We're live again...
            } else {
              // Still a live feed - keep collecting.
              assert(!_controller.offline);
            }
          } else {
            // Switching to an offline memory log (JSON file in /tmp).
            _loadOffline(memorySource);
          }

          // Notify the Chart state there's new data from a different memory
          // source to plot.
          _controller.notifyMemorySourceListeners();
        });
      },
      itemBuilder: (BuildContext context) => items,
    );
  }

  void _updateListeningState() async {
    await serviceManager.serviceAvailable.future;

    if (_controller.hasStarted) return;

    await _controller.startTimeline();

    // TODO(terry): Need to set the initial state of buttons.
/*
      pauseButton.disabled = false;
      resumeButton.disabled = true;

      vmMemorySnapshotButton.disabled = false;
      resetAccumulatorsButton.disabled = false;
      gcNowButton.disabled = false;

      memoryChart.disabled = false;
*/
  }

  Widget _leftsideButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        OutlineButton(
          onPressed: _controller.paused ? null : _pauseLiveTimeline,
          child: const MaterialIconLabel(
            Icons.pause,
            'Pause',
            minIncludeTextWidth: 900,
          ),
        ),
        OutlineButton(
          onPressed: _controller.paused ? _resumeLiveTimeline : null,
          child: const MaterialIconLabel(
            Icons.play_arrow,
            'Resume',
            minIncludeTextWidth: 900,
          ),
        ),
      ],
    );
  }

  Widget _rightsideButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(children: [
          Text(
            'Memory Source:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 5),
          Text(
            memorySource == _liveFeed ? memorySource : 'memory log',
            style: TextStyle(fontWeight: FontWeight.w100),
          ),
          const SizedBox(width: 5),
          _selectMemoryFile(),
        ]),
        OutlineButton(
          onPressed: _exportMemory,
          child: MaterialIconLabel(
            Icons.file_download,
            'Export',
            minIncludeTextWidth: 1100,
          ),
        ),
        const SizedBox(width: 32.0),
        OutlineButton(
          onPressed: _snapshot,
          child: MaterialIconLabel(
            Icons.camera,
            'Snapshot',
            minIncludeTextWidth: 1100,
          ),
        ),
        OutlineButton(
          onPressed: _reset,
          child: MaterialIconLabel(
            Icons.settings_backup_restore,
            'Reset',
            minIncludeTextWidth: 1100,
          ),
        ),
        OutlineButton(
          onPressed: _gc,
          child: MaterialIconLabel(
            Icons.delete_sweep,
            'GC',
            minIncludeTextWidth: 1100,
          ),
        ),
      ],
    );
  }

  // Callbacks for button actions:

  void _pauseLiveTimeline() {
    // TODO(terry): Implement real pause when connected to live feed.
    _controller.pauseLiveFeed();
    setState(() {});
  }

  void _resumeLiveTimeline() {
    // TODO(terry): Implement real resume when connected to live feed.
    _controller.resumeLiveFeed();
    setState(() {});
  }

  /// Persist the the live data to a JSON file in the /tmp directory.
  void _exportMemory() {
    final liveData = _controller.memoryTimeline.data;

    final jsonPayload = MemoryTimeline.encodeHeapSamples(liveData);
    final realData = MemoryTimeline.decodeHeapSamples(jsonPayload);

    assert(realData.length == liveData.length);

    final previousCurrentDirectory = Directory.current;

    // TODO(terry): Consider path_provider's getTemporaryDirectory
    //              or getApplicationDocumentsDirectory when
    //              available in Flutter Web/Desktop.
    Directory.current = Directory.systemTemp;

    final memoryLogFile = File(_memoryLogFilename);
    final openFile = memoryLogFile.openSync(mode: FileMode.write);
    memoryLogFile.writeAsStringSync(jsonPayload);
    openFile.closeSync();

    // TODO(terry): Display filename created in a toast.

    Directory.current = previousCurrentDirectory;
  }

  // Return a list of offline memory logs in the /tmp directory that
  // are available to open and plot.
  List<String> offlineFiles() {
    final List<String> memoryLogs = [];

    final previousCurrentDirectory = Directory.current;

    // TODO(terry): Use path_provider when available?
    Directory.current = Directory.systemTemp;

    final allFiles = Directory.current.listSync();
    for (FileSystemEntity entry in allFiles) {
      final basename = _path.basename(entry.path);
      if (FileSystemEntity.isFileSync(entry.path) &&
          basename.startsWith(_filenamePrefix)) {
        memoryLogs.add(basename);
      }
    }

    // Sort by newest file top-most (DateTime is in the filename).
    memoryLogs.sort((a, b) => b.compareTo(a));

    Directory.current = previousCurrentDirectory;

    return memoryLogs;
  }

  //
  void _loadOffline(String filename) {
    _controller.offline = true;

    final previousCurrentDirectory = Directory.current;

    // TODO(terry): Use path_provider when available?
    Directory.current = Directory.systemTemp;

    final memoryLogFile = File(filename);
    final openFile = memoryLogFile.openSync(mode: FileMode.read);
    final jsonPayload = memoryLogFile.readAsStringSync();
    openFile.closeSync();

    final realData = MemoryTimeline.decodeHeapSamples(jsonPayload);

    _controller.memoryTimeline.offflineData.clear();
    _controller.memoryTimeline.offflineData.addAll(realData);

    Directory.current = previousCurrentDirectory;
  }

  void _snapshot() {
    // TODO(terry): Implementation needed.
  }

  void _reset() {
    // TODO(terry): TBD real implementation needed.
  }

  void _gc() {
    // TODO(terry): Implementation needed.
  }
}
