// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'globals.dart';
import 'routing.dart';
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
  Screen _screen;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(SnapshotScreenBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.args != oldWidget.args ||
        widget.possibleScreens != oldWidget.possibleScreens) {
      _initScreen();
    }
  }

  void _initScreen() {
    _screen = widget.possibleScreens.firstWhere(
      (s) => s.screenId == widget.args?.screenId,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final routerDelegate = DevToolsRouterDelegate.of(context);
    return Column(
      children: [
        Row(
          children: [
            ExitOfflineButton(onPressed: () {
              offlineMode = false;
              reset();
              // Use Router.neglect to replace the current history entry with
              // the homepage so that clicking Back will not return here.
              Router.neglect(
                context,
                () => routerDelegate.navigate(
                  homePageId,
                  {'screen': null},
                ),
              );
            }),
          ],
        ),
        Expanded(
          child:
              _screen != null ? _screen.build(context) : _buildSnapshotError(),
        ),
      ],
    );
  }

  Widget _buildSnapshotError() {
    return CenteredMessage(
        'Cannot load snapshot for screen \'${widget.args?.screenId}\'');
  }

  void reset() {
    setState(() {
      offlineDataJson.clear();
      _screen = null;
    });
  }
}

class SnapshotArguments {
  SnapshotArguments(this.screenId);

  SnapshotArguments.fromArgs(Map<String, String> args) : this(args['screen']);

  final String screenId;
}
