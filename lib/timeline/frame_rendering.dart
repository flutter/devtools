// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import '../vm_service_wrapper.dart';

class FramesTracker {
  FramesTracker(this.service);

  static const int kMaxFrames = 60;
  final StreamController<Null> _changeController =
      StreamController<Null>.broadcast();

  VmServiceWrapper service;
  StreamSubscription<Event> eventStreamSubscription;
  List<FrameInfo> samples = <FrameInfo>[];

  bool get hasConnection => service != null;

  Stream<Null> get onChange => _changeController.stream;

  void start() {
    if (eventStreamSubscription != null) {
      stop();
    }
    eventStreamSubscription = service.onExtensionEvent.listen((Event e) {
      if (e.extensionKind == 'Flutter.Frame') {
        final ExtensionData data = e.extensionData;
        _addSample(FrameInfo.from(data.data));
      }
    });
  }

  void stop() {
    assert(eventStreamSubscription != null);
    eventStreamSubscription.cancel();
    eventStreamSubscription = null;
  }

  void pause() {
    assert(eventStreamSubscription != null);
    eventStreamSubscription.pause();
  }

  void resume() {
    assert(eventStreamSubscription != null);
    eventStreamSubscription.resume();
  }

  void _addSample(FrameInfo frame) {
    if (samples.isEmpty) {
      frame.frameGroupStart = true;
    } else {
      frame.calcFrameGroupStart(samples.last);
    }
    samples.add(frame);
    while (samples.length > kMaxFrames) {
      samples.removeAt(0);
    }
    _changeController.add(null);
  }

  FrameInfo get lastSample => samples.isEmpty ? null : samples.last;

  num calcRecentFPS() {
    int frameCount = 0;
    int usedFrames = 0;

    for (int i = samples.length - 1; i >= 0; i--) {
      final FrameInfo frame = samples[i];

      frameCount++;

      num frameTime = frame.elapsedMs;
      int requiredFrames =
          (frameTime / FrameInfo.kTargetMaxFrameTimeMs).round();
      frameTime -= requiredFrames * FrameInfo.kTargetMaxFrameTimeMs;
      if (frameTime > 0) {
        requiredFrames++;
      }
      usedFrames += requiredFrames;

      if (frame.frameGroupStart) {
        break;
      }
    }

    return 1000 * frameCount / (usedFrames * FrameInfo.kTargetMaxFrameTimeMs);
  }
}

class FrameInfo {
  FrameInfo(this.number, this.elapsedMs, this.startTimeMs);

  static const double kTargetMaxFrameTimeMs = 1000.0 / 60;

  static FrameInfo from(Map<dynamic, dynamic> data) {
    return FrameInfo(
        data['number'], data['elapsed'] / 1000, data['startTime'] / 1000);
  }

  final int number;
  final num elapsedMs;
  final num startTimeMs;

  bool frameGroupStart = false;

  num get endTimeMs => startTimeMs + elapsedMs;

  void calcFrameGroupStart(FrameInfo previousFrame) {
    if (startTimeMs > (previousFrame.endTimeMs + kTargetMaxFrameTimeMs)) {
      frameGroupStart = true;
    }
  }

  @override
  String toString() => 'frame $number ${elapsedMs.toStringAsFixed(1)}ms';
}
