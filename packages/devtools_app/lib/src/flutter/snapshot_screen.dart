// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../globals.dart';
import 'common_widgets.dart';
import 'controllers.dart';
import 'screen.dart';

/// The screen in the app responsible for connecting to the Dart VM.
///
/// We need to use this screen to get a guarantee that the app has a Dart VM
/// available.
class SnapshotScreenBody extends StatefulWidget {
  const SnapshotScreenBody(this.args, this.possibleScreens);

  final SnapshotArguments args;

  /// All possible screens, both visible and hidden, that DevTools was started
  /// with.
  ///
  /// This will include screens that are only available when connected to an app
  /// as well as screens that are only available based on the presence of a
  /// conditional library.
  ///
  /// These screens are stored here so that we can import files for all screens,
  /// regardless of whether an app is connected to DevTools or whether a
  /// connected app contains the correct conditional library.
  final List<Screen> possibleScreens;

  @override
  _SnapshotScreenBodyState createState() => _SnapshotScreenBodyState();
}

class _SnapshotScreenBodyState extends State<SnapshotScreenBody> {
  var _dataProcessed = Completer();

  Screen _screen;

  OfflineControllerMixin _screenController;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _buildScreenAndProcessData();
  }

  @override
  void didUpdateWidget(SnapshotScreenBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.args != oldWidget.args ||
        widget.possibleScreens != oldWidget.possibleScreens) {
      _dataProcessed = Completer();
      _initScreen();
      _buildScreenAndProcessData();
    }
  }

  void _initScreen() {
    _screen = widget.possibleScreens.firstWhere(
      (screen) => screen.screenId == widget.args?.screenId,
      orElse: () => null,
    );
  }

  // TODO(kenz): ensure conditional screens have a way to provide the controller
  // they need since it will not be provided by `Controller.of(context)` as is.
  Future<void> _buildScreenAndProcessData() async {
    if (_screen != null && widget.args?.data != null) {
      _screenController = _screen.conditionalController ??
          Controllers.of(context).offlineLookup[_screen.screenId];
      await _screenController?.processOfflineData(widget.args.data);
    }
    setState(() {
      _dataProcessed.complete();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (_dataProcessed.isCompleted)
              exitOfflineButton(() {
                Navigator.pop(context);
                reset();
                offlineMode = false;
              }),
          ],
        ),
        Expanded(
          child: _screen != null && widget.args?.data != null
              ? _buildSnapshotScreen()
              : _buildSnapshotError(),
        ),
      ],
    );
  }

  Widget _buildSnapshotScreen() {
    // We put these two items in a stack because the snapshot screen's UI needs
    // to be built before the data is processed in order to initialize listeners
    // that respond to data processing events. The spinner hides the snapshot
    // screen's empty UI while data is being processed.
    return Stack(children: [
      _screen.build(context),
      if (!_dataProcessed.isCompleted)
        Container(
          color: Colors.grey[50],
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
    ]);
  }

  Widget _buildSnapshotError() {
    return CenteredMessage(
        'Cannot load snapshot for screen \'${widget.args?.screenId}\'');
  }

  void reset() {
    setState(() {
      _dataProcessed = Completer();
      _screen = null;
      _screenController = null;
    });
  }
}

class SnapshotArguments {
  SnapshotArguments(this.screenId, this.data);
  final String screenId;
  final Object data;
}
