// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../api/vs_code_api.dart';

class DebugSessionInfo extends StatelessWidget {
  const DebugSessionInfo({
    super.key,
    required this.api,
    this.debugSession,
  });

  final VsCodeDebugSession? debugSession;
  final VsCodeApi api;

  @override
  Widget build(BuildContext context) {
    // TODO(dantup): What to show if mode is unknown (null)?
    final mode = debugSession?.flutterMode;
    final isDebug = mode == 'debug';
    final isProfile = mode == 'profile';
    final isRelease = mode == 'release' || mode == 'jit_release';
    final isFlutter = debugSession?.debuggerType?.contains('Flutter') ?? false;

    return Column(
      children: [
        Text(
          debugSession?.name ?? 'Begin a debug session to use DevTools',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        if (api.capabilities.openDevToolsPage)
          Row(
            children: [
              // TODO(dantup): Make these conditions use the real screen
              //  conditions and/or verify if these conditions are correct.
              _devToolsButton(
                page: 'inspector',
                text: 'Inspector',
                enabled: isFlutter && isDebug,
              ),
              _devToolsButton(
                page: 'cpu-profiler',
                text: 'Profiler',
                enabled: isDebug || isProfile,
              ),
              _devToolsButton(
                page: 'memory',
                text: 'Memory',
                enabled: isDebug || isProfile,
              ),
              _devToolsButton(page: 'performance', text: 'Perf'),
              _devToolsButton(page: 'network', text: 'Net', enabled: isDebug),
              _devToolsButton(page: 'logging', text: 'Log'),
            ],
          ),
      ],
    );
  }

  Widget _devToolsButton({
    required String page,
    required String text,
    bool enabled = true,
  }) {
    final debugSession = this.debugSession;
    return ElevatedButton(
      onPressed: debugSession != null && enabled
          ? () => unawaited(api.openDevToolsPage(debugSession.id, page))
          : null,
      child: Text(text),
    );
  }
}
