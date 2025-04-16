// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/framework/routing.dart';
import '../../shared/globals.dart';
import '../../shared/managers/banner_messages.dart' as banner_messages;
import '../../shared/primitives/byte_utils.dart';
import '../../shared/utils/utils.dart';
import '_memory_desktop.dart' if (dart.library.js_interop) '_memory_web.dart';

/// The result of a request to [MemoryObserver.reduceMemory].
///
/// `fromBytes` - total memory usage before the reduction request.
/// `toBytes` - total memory usage after the reduction request is completed.
/// `success` - whether the reduction in memory brought DevTools memory usage
/// below the threshold [MemoryObserver._memoryPressureLimitGb].
typedef ReduceMemoryResult =
    ({bool success, int? fromBytes, int? toBytes, String? error});

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

  PeriodicDebouncer? _timer;

  /// Tracks the most recent memory usage measurement.
  ///
  /// This value is updated each time [MemoryObserver._memoryExceedsThreshold]
  /// is called.
  static int? _lastMemoryUsageInBytes;

  @override
  void init() {
    super.init();
    _timer = PeriodicDebouncer.run(_pollingDuration, _pollForMemoryUsage);
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
    if (await _memoryExceedsThreshold(
      debugMeasureUsageInBytes: _debugMeasureUsageInBytes,
    )) {
      final gaScreen = DevToolsRouterDelegate.currentPage ?? gac.devToolsMain;
      ga.impression(gaScreen, gac.memoryPressure);
      bannerMessages.addMessage(
        _MemoryPressureBannerMessage(),
        callInPostFrameCallback: false,
      );
    }
  }

  static Future<bool> _memoryExceedsThreshold({
    @visibleForTesting Future<int?> Function()? debugMeasureUsageInBytes,
  }) async {
    final memoryUsageInBytes =
        debugMeasureUsageInBytes != null
            ? await debugMeasureUsageInBytes()
            : await measureMemoryUsageInBytes();
    _lastMemoryUsageInBytes = memoryUsageInBytes;
    if (memoryUsageInBytes == null) return false;

    final memoryInGb = convertBytes(memoryUsageInBytes, to: ByteUnit.gb);
    return memoryInGb > _memoryPressureLimitGb;
  }

  /// Attempts to reduce the memory footprint of DevTools by releasing memory
  /// from unused DevTools screens and, if necessary, releasing partial memory
  /// from the current screen in use.
  ///
  /// Returns a [ReduceMemoryResult] containing metadata and a success result.
  static Future<ReduceMemoryResult> reduceMemory({
    @visibleForTesting Future<int?> Function()? debugMeasureUsageInBytes,
  }) async {
    final fromBytes = _lastMemoryUsageInBytes;
    await screenControllers.forEachInitializedAsync((screenController) async {
      if (DevToolsRouterDelegate.currentPage != screenController.screenId) {
        // If we need to release more memory, we can consider disposing the
        // screen controllers too. This would revert the controller back to it's
        // lazy initialized state, waiting to be re-initialized upon first use.
        await screenController.releaseMemory();
      }
    });

    // TODO(kenz): clear other potential sources of memory bloat such as the
    // console history or caches like the resolved URI manager.

    if (await _memoryExceedsThreshold(
      debugMeasureUsageInBytes: debugMeasureUsageInBytes,
    )) {
      await screenControllers.forEachInitializedAsync((screenController) async {
        if (DevToolsRouterDelegate.currentPage == screenController.screenId) {
          // If memory usage still exceeds the threshold, perform a partial
          // release of memory on the current screen. This is more disruptive
          // to the user, so only do this if releasing memory from every other
          // screen first did not work.
          await screenController.releaseMemory(partial: true);
        }
      });
    }

    final success =
        !(await _memoryExceedsThreshold(
          debugMeasureUsageInBytes: debugMeasureUsageInBytes,
        ));
    final toBytes = _lastMemoryUsageInBytes;
    return (
      success: success,
      fromBytes: fromBytes!,
      toBytes: toBytes!,
      error: null,
    );
  }
}

class _MemoryPressureBannerMessage extends banner_messages.BannerWarning {
  _MemoryPressureBannerMessage()
    : super(
        screenId: banner_messages.universalScreenId,
        key: _messageKey,
        dismissOnConnectionChanges: false,
        buildTextSpans: (context) {
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
                  'which will make a ',
              children: [
                TextSpan(
                  text: 'best-effort attempt',
                  style: Theme.of(context).boldTextStyle,
                ),
                const TextSpan(
                  text:
                      ' to clear stale data. If you do not take action, '
                      'DevTools may eventually crash due to an out of memory '
                      'error (OOM).\n\n'
                      'WARNING: clicking "Reduce memory" will clear data from '
                      'other DevTools screens and may partially clear data '
                      'from the screen you are currently using. Consider '
                      'saving data from other DevTools screens, where '
                      'supported, if you do not want to lose data.',
                ),
              ],
            ),
          ];
        },
        buildActions:
            (_) => [
              // Wrapping with an `Expanded` is okay because this list is set as
              // the `children` parameter of a `Row` widget in `BannerMessage`.
              const Expanded(child: _ReduceMemoryButton()),
            ],
      );

  static const _messageKey = Key('MemoryPressureBannerMessage');
}

class _ReduceMemoryButton extends StatefulWidget {
  const _ReduceMemoryButton();

  @override
  State<_ReduceMemoryButton> createState() => _ReduceMemoryButtonState();
}

class _ReduceMemoryButtonState extends State<_ReduceMemoryButton> {
  bool inProgress = false;

  final result = ValueNotifier<ReduceMemoryResult?>(null);

  @override
  void dispose() {
    result.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DevToolsButton(
          label: 'Reduce memory',
          onPressed: _onPressed,
          color: colorScheme.onTertiaryContainer,
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
            child:
                inProgress
                    ? SizedBox(
                      height: actionsIconSize,
                      width: actionsIconSize,
                      child: const CircularProgressIndicator(),
                    )
                    : ValueListenableBuilder(
                      valueListenable: result,
                      builder: (context, result, _) {
                        return _SuccessOrFailureMessage(result: result);
                      },
                    ),
          ),
        ),
      ],
    );
  }

  Future<void> _onPressed() async {
    ga.select(gac.devToolsMain, gac.memoryPressureReduce);
    setState(() {
      inProgress = true;
      result.value = null;
    });
    ReduceMemoryResult? reduceMemoryResult;
    try {
      reduceMemoryResult = await MemoryObserver.reduceMemory();
    } catch (e) {
      reduceMemoryResult = (
        success: false,
        fromBytes: null,
        toBytes: null,
        error: e.toString(),
      );
    } finally {
      setState(() {
        inProgress = false;
        result.value = reduceMemoryResult;
      });
    }
  }
}

class _SuccessOrFailureMessage extends StatefulWidget {
  const _SuccessOrFailureMessage({required this.result});

  final ReduceMemoryResult? result;

  @override
  State<_SuccessOrFailureMessage> createState() =>
      _SuccessOrFailureMessageState();
}

class _SuccessOrFailureMessageState extends State<_SuccessOrFailureMessage> {
  static const _startingDismissCountDown = 5;

  int dismissCountDown = _startingDismissCountDown;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _SuccessOrFailureMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _init();
    }
  }

  void _init() {
    final result = widget.result;
    if (result != null && result.success) {
      dismissCountDown = _startingDismissCountDown;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (dismissCountDown <= 1) {
          _timer?.cancel();
          _timer = null;
          bannerMessages.removeMessageByKey(
            _MemoryPressureBannerMessage._messageKey,
            banner_messages.universalScreenId,
          );
        }
        setState(() {
          dismissCountDown--;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onTertiaryContainer;

    final result = widget.result;
    if (result == null) return const SizedBox.shrink();

    String message;
    if (result.error != null) {
      message =
          'Attempt to reduce memory was unsuccessful. Error: ${result.error}';
    } else {
      assert(result.fromBytes != null && result.toBytes != null);
      final fromBytesAsString = printBytes(
        result.fromBytes!,
        fractionDigits: 2,
        unit: ByteUnit.gb,
        includeUnit: true,
      );
      final toBytesAsString = printBytes(
        result.toBytes!,
        fractionDigits: 2,
        unit: ByteUnit.gb,
        includeUnit: true,
      );

      if (result.success) {
        message =
            'Successfully reduced memory from $fromBytesAsString to '
            '$toBytesAsString. This warning will automatically dismiss in '
            '$dismissCountDown seconds.';
      } else {
        final limitAsBytes = convertBytes(
          MemoryObserver._memoryPressureLimitGb,
          from: ByteUnit.gb,
          to: ByteUnit.byte,
        );
        final limitBytesAsString = printBytes(
          limitAsBytes,
          unit: ByteUnit.gb,
          includeUnit: true,
        );
        message =
            'Attempt to reduce memory was unsuccessful. Memory was reduced from '
            '$fromBytesAsString to $toBytesAsString, but the total memory still '
            'exceeds the $limitBytesAsString threshold.';
      }
    }

    return RichText(
      text: TextSpan(
        children: [
          WidgetSpan(
            child: Padding(
              padding: const EdgeInsets.only(right: denseSpacing),
              child: Icon(
                result.success ? Icons.check : Icons.close,
                size: actionsIconSize,
                color: color,
              ),
            ),
          ),
          TextSpan(
            text: message,
            style: theme.regularTextStyleWithColor(color),
          ),
        ],
      ),
    );
  }
}
