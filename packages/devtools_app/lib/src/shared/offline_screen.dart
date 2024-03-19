// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import 'analytics/constants.dart' as gac;
import 'common_widgets.dart';
import 'globals.dart';
import 'screen.dart';

/// The screen used for displaying offline data (data that does not require a
/// connected app to explore).
///
/// This screen can be displayed both when DevTools is and is not connected to
/// an app.
class OfflineScreenBody extends StatefulWidget {
  const OfflineScreenBody(this.args, this.possibleScreens, {super.key});

  final OfflineDataArguments args;

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
  State<OfflineScreenBody> createState() => _OfflineScreenBodyState();
}

class _OfflineScreenBodyState extends State<OfflineScreenBody>
    with AutoDisposeMixin {
  Screen? _screen;

  @override
  void initState() {
    super.initState();
    _initScreen();
    addAutoDisposeListener(offlineController.offlineMode, () {
      if (!offlineController.offlineMode.value) {
        setState(() {
          _screen = null;
        });
      }
    });
  }

  @override
  void didUpdateWidget(OfflineScreenBody oldWidget) {
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
    return _screen != null
        ? _screen!.build(context)
        : _OfflineLoadError(screenId: widget.args.screenId);
  }
}

class _OfflineLoadError extends StatelessWidget {
  const _OfflineLoadError({required this.screenId});

  final String? screenId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CenteredMessage(
          message: 'Cannot load offline data for screen \'$screenId\'',
        ),
        const SizedBox(height: defaultSpacing),
        ExitOfflineButton(gaScreen: gac.simple),
      ],
    );
  }
}

class OfflineDataArguments {
  OfflineDataArguments(this.screenId);

  OfflineDataArguments.fromArgs(Map<String, String?> args)
      : this(args['screen']);

  final String? screenId;
}
