// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/utils.dart';
import 'package:vm_service/vm_service.dart';

import '../../../../../service/service_extensions.dart' as extensions;
import '../../../../../shared/globals.dart';
import '../../flutter_frames/flutter_frame_model.dart';
import 'enhance_tracing_model.dart';

final enhanceTracingExtensions = [
  extensions.profileWidgetBuilds,
  extensions.profileUserWidgetBuilds,
  extensions.profileRenderObjectLayouts,
  extensions.profileRenderObjectPaints,
];

class EnhanceTracingController extends DisposableController
    with AutoDisposeControllerMixin {
  final showMenuStreamController = StreamController<void>.broadcast();

  late EnhanceTracingState tracingState;

  final _extensionStates = {
    for (var ext in enhanceTracingExtensions) ext: false,
  };

  /// The id of the first 'Flutter.Frame' event that occurs after the DevTools
  /// performance page is opened.
  ///
  /// For frames with this id and greater, we can assign
  /// [FlutterFrame.enhanceTracingState]. For frames with an earlier id, we
  /// do not know the value of [FlutterFrame.enhanceTracingState], and we will
  /// use other heuristics.
  int? _firstLiveFrameId;

  /// Stream subscription on the 'Extension' stream that listens for the first
  /// 'Flutter.Frame' event.
  ///
  /// This stream should be initialized and cancelled in
  /// [_listenForFirstLiveFrame], unless we never receive any 'Flutter.Frame'
  /// events, in which case the subscription will be canceled in [dispose].
  StreamSubscription<Event>? _firstFrameEventSubscription;

  /// Listens on the 'Extension' stream (without history) for 'Flutter.Frame'
  /// events.
  ///
  /// This method assigns [_firstLiveFrameId] when the first 'Flutter.Frame'
  /// event is received, and then cancels the stream subscription.
  void _listenForFirstLiveFrame() {
    _firstFrameEventSubscription =
        serviceConnection.serviceManager.service!.onExtensionEvent.listen(
      (event) {
        if (event.extensionKind == 'Flutter.Frame' &&
            _firstLiveFrameId == null) {
          _firstLiveFrameId = FlutterFrame.parse(event.extensionData!.data).id;
          // See https://github.com/dart-lang/linter/issues/3801
          // ignore: discarded_futures
          unawaited(_firstFrameEventSubscription!.cancel());
          _firstFrameEventSubscription = null;
        }
      },
    );
  }

  void init() {
    for (int i = 0; i < enhanceTracingExtensions.length; i++) {
      final extension = enhanceTracingExtensions[i];
      final state = serviceConnection.serviceManager.serviceExtensionManager
          .getServiceExtensionState(extension.extension);
      _extensionStates[extension] = state.value.enabled;
      // Listen for extension state changes so that we can update the value of
      // [_extensionStates] and [tracingState].
      addAutoDisposeListener(state, () {
        final value = state.value.enabled;
        _extensionStates[extension] = value;
        _updateTracingState();
      });
    }
    _updateTracingState();

    // Listen for the first 'Flutter.Frame' event we receive from this point
    // on so that we know the start id for frames that we can assign the
    // current [FlutterFrame.enhanceTracingState].
    _listenForFirstLiveFrame();
  }

  void _updateTracingState() {
    final builds = _extensionStates[extensions.profileWidgetBuilds]! ||
        _extensionStates[extensions.profileUserWidgetBuilds]!;
    final layouts = _extensionStates[extensions.profileRenderObjectLayouts]!;
    final paints = _extensionStates[extensions.profileRenderObjectPaints]!;
    tracingState = EnhanceTracingState(
      builds: builds,
      layouts: layouts,
      paints: paints,
    );
  }

  void assignStateForFrame(FlutterFrame frame) {
    // We can only assign [FlutterFrame.enhanceTracingState] for frames
    // with ids after [_firstLiveFrameId].
    if (_firstLiveFrameId != null && frame.id >= _firstLiveFrameId!) {
      frame.enhanceTracingState = tracingState;
    }
  }

  void showEnhancedTracingMenu() {
    showMenuStreamController.add(null);
  }

  @override
  void dispose() {
    unawaited(showMenuStreamController.close());
    // See https://github.com/dart-lang/linter/issues/3801
    // ignore: discarded_futures
    unawaited(_firstFrameEventSubscription?.cancel());
    super.dispose();
  }
}
