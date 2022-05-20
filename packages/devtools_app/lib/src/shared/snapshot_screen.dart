// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'globals.dart';
import 'routing.dart';
import 'screen.dart';
import 'theme.dart';

/// The screen used for displaying a snapshot of imported data.
///
/// This screen can be displayed both when DevTools is and is not connected to
/// an app.
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
  Screen? _screen;

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
    _screen = widget.possibleScreens.firstWhereOrNull(
      (s) => s.screenId == widget.args.screenId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final routerDelegate = DevToolsRouterDelegate.of(context);
    return Column(
      Row(
        ExitOfflineButton(
          onPressed: () {
            offlineController.exitOfflineMode();
            reset();
            // Use Router.neglect to replace the current history entry with
            // the homepage so that clicking Back will not return here.
            Router.neglect(
              context,
              () => routerDelegate.navigateHome(clearScreenParam: true),
            );
          },
        ),
      ),
      const SizedBox(height: denseRowSpacing),
      Expanded(
        _screen != null ? _screen!.build(context) : _buildSnapshotError(),
      ),
    );
  }

  Widget _buildSnapshotError() {
    return CenteredMessage(
      'Cannot load snapshot for screen \'${widget.args.screenId}\'',
    );
  }

  void reset() {
    setState(() {
      offlineController.offlineDataJson.clear();
      _screen = null;
    });
  }
}

class SnapshotArguments {
  SnapshotArguments(this.screenId);

  SnapshotArguments.fromArgs(Map<String, String?> args) : this(args['screen']);

  final String? screenId;
}
