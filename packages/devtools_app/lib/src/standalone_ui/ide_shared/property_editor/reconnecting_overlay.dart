// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import 'utils/utils.dart';

class ReconnectingOverlay extends StatefulWidget {
  const ReconnectingOverlay({super.key});

  @override
  State<ReconnectingOverlay> createState() => _ReconnectingOverlayState();
}

class _ReconnectingOverlayState extends State<ReconnectingOverlay> {
  static const _countdownInterval = Duration(seconds: 1);
  late final Timer _countdownTimer;
  int _secondsUntilReconnection = 3;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(_countdownInterval, _onTick);
  }

  @override
  void dispose() {
    _countdownTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: defaultSpacing),
            Text(
              _secondsUntilReconnection > 0
                  ? 'Reconnecting in $_secondsUntilReconnection'
                  : 'Reconnecting...',
              style: theme.textTheme.headlineMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _onTick(Timer timer) {
    setState(() {
      _secondsUntilReconnection--;
      if (_secondsUntilReconnection == 0) {
        timer.cancel();
        _reconnect();
      }
    });
  }

  void _reconnect() {
    forceReload();
  }
}
