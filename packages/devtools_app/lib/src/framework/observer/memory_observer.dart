// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../devtools_app.dart';
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/primitives/byte_utils.dart';
import '_memory_desktop.dart' if (dart.library.js_interop) '_memory_web.dart';

/// Observes the memory usage of the DevTools app (web only) and shows a memory
/// pressure warning to users when DevTools is nearing the memory limit.
///
/// The warning has an option for users to automatically reduce memory. If the
/// user selects this option, we will make a best effort attempt to clear data
/// from features that have not been recently used, or stale data in general.
class MemoryObserver extends DisposableController {
  MemoryObserver({
    @visibleForTesting Future<int?> Function()? debugMeasureUsageInBytes,
    @visibleForTesting Duration pollingDuration = _pollForMemoryDuration,
  }) : _debugMeasureUsageInBytes = debugMeasureUsageInBytes,
       _pollingDuration = pollingDuration;

  final Future<int?> Function()? _debugMeasureUsageInBytes;

  final Duration _pollingDuration;

  static const _pollForMemoryDuration = Duration(seconds: 45);

  static const _memoryPressureLimitGb = 3.0;

  DebounceTimer? _timer;

  @override
  void init() {
    super.init();
    _timer = DebounceTimer.periodic(_pollingDuration, _pollForMemoryUsage);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<void> _pollForMemoryUsage({
    DebounceCancelledCallback? cancelledCallback,
  }) async {
    final memoryUsageInBytes =
        _debugMeasureUsageInBytes != null
            ? await _debugMeasureUsageInBytes()
            : await measureMemoryUsageInBytes();
    if (memoryUsageInBytes == null) return;

    final memoryInGb = convertBytes(memoryUsageInBytes, to: ByteUnit.gb);
    if (memoryInGb > _memoryPressureLimitGb) {
      final gaScreen = DevToolsRouterDelegate.currentPage ?? gac.devToolsMain;
      ga.impression(gaScreen, gac.memoryPressure);
      bannerMessages.addMessage(
        _MemoryPressureBannerMessage(screenId: gaScreen),
        callInPostFrameCallback: false,
      );
    }
  }
}

// TODO(https://github.com/flutter/devtools/issues/7002): modify the banner
// messages code to ensure this message is screen agnostic and will show on all
// screens.
class _MemoryPressureBannerMessage extends BannerWarning {
  _MemoryPressureBannerMessage({required super.screenId})
    : super(
        key: Key('MemoryPressureBannerMessage - $screenId'),
        buildTextSpans: (_) {
          final limitAsBytes = convertBytes(
            MemoryObserver._memoryPressureLimitGb,
            from: ByteUnit.gb,
            to: ByteUnit.byte,
          );
          return [
            TextSpan(
              text:
                  'DevTools memory usage has exceeded '
                  '${printBytes(limitAsBytes, unit: ByteUnit.gb, includeUnit: true)}. '
                  'Consider releasing memory by clearing data you are no '
                  'longer analyzing, or by clicking "Reduce memory" below, '
                  'which will make a best-effort attempt to clear stale data. '
                  'If you do not take action, DevTools may eventually crash '
                  'due to an out of memory error (OOM).',
            ),
          ];
        },
        buildActions:
            (_) => [
              DevToolsButton(
                label: 'Reduce memory',
                onPressed: () {
                  ga.select(gac.devToolsMain, gac.memoryPressureReduce);
                  // TODO(https://github.com/flutter/devtools/issues/7002): add
                  // support to screen controllers to reduce memory.
                },
              ),
            ],
      );
}
