// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:devtools_app/devtools_app.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service_protos/vm_service_protos.dart';

import '../../../test_infra/test_data/performance/sample_performance_data.dart';

void main() {
  group('$PerfettoTrace', () {
    test('setting trace with new trace object notifies listeners', () {
      final startingBinary = Uint8List(0);
      final perfettoTrace = PerfettoTrace(startingBinary);
      final newBinary = Uint8List(0);

      bool notified = false;
      perfettoTrace.addListener(() => notified = true);
      perfettoTrace.trace = newBinary;

      expect(perfettoTrace.traceBinary, newBinary);
      expect(notified, isTrue);
    });
    test('setting trace with identical object notifies listeners', () {
      final trace = Uint8List(0);
      final perfettoTrace = PerfettoTrace(trace);

      bool notified = false;
      perfettoTrace.addListener(() => notified = true);
      perfettoTrace.trace = trace;

      expect(notified, isTrue);
    });
  });

  group('$PerfettoTrackDescriptorEvent', () {
    late PerfettoTrackDescriptorEvent trackDescriptor;

    setUp(() {
      trackDescriptor = PerfettoTrackDescriptorEvent(
        TrackDescriptor.fromJson(jsonEncode(trackDescriptorEvents.first)),
      );
    });

    test('can successfully read fields', () {
      expect(trackDescriptor.name, 'io.flutter.1.raster');
      expect(trackDescriptor.id, Int64(31491));
    });
  });

  group('$PerfettoTrackEvent', () {
    late PerfettoTrackEvent trackEvent;

    test('UI track events', () {
      trackEvent = PerfettoTrackEvent.fromPacket(
        TracePacket.fromJson(jsonEncode(frame2TrackEventPackets.first)),
      );
      expect(trackEvent.name, 'Animator::BeginFrame');
      expect(trackEvent.args, {'frame_number': '2'});
      expect(trackEvent.categories, ['Embedder']);
      expect(trackEvent.trackId, Int64(22787));
      expect(trackEvent.type, PerfettoEventType.sliceBegin);
      expect(trackEvent.timelineEventType, null);
      expect(trackEvent.flutterFrameNumber, 2);
      expect(trackEvent.isUiFrameIdentifier, true);
      expect(trackEvent.isRasterFrameIdentifier, false);
      expect(trackEvent.isShaderEvent, false);

      trackEvent = PerfettoTrackEvent.fromPacket(
        TracePacket.fromJson(jsonEncode(frame2TrackEventPackets[1])),
      );
      expect(trackEvent.name, '');
      expect(trackEvent.args, isEmpty);
      expect(trackEvent.categories, ['Embedder']);
      expect(trackEvent.trackId, Int64(22787));
      expect(trackEvent.type, PerfettoEventType.sliceEnd);
      expect(trackEvent.timelineEventType, null);
      expect(trackEvent.flutterFrameNumber, null);
      expect(trackEvent.isUiFrameIdentifier, false);
      expect(trackEvent.isRasterFrameIdentifier, false);
      expect(trackEvent.isShaderEvent, false);
    });

    test('Raster track events', () {
      trackEvent = PerfettoTrackEvent.fromPacket(
        TracePacket.fromJson(jsonEncode(frame2TrackEventPackets[2])),
      );
      expect(trackEvent.name, 'Rasterizer::DoDraw');
      expect(trackEvent.args, {'frame_number': '2'});
      expect(trackEvent.categories, ['Embedder']);
      expect(trackEvent.trackId, Int64(31491));
      expect(trackEvent.type, PerfettoEventType.sliceBegin);
      expect(trackEvent.timelineEventType, null);
      expect(trackEvent.flutterFrameNumber, 2);
      expect(trackEvent.isUiFrameIdentifier, false);
      expect(trackEvent.isRasterFrameIdentifier, true);
      expect(trackEvent.isShaderEvent, false);
    });

    test('Shader compilation track event', () {
      final trackEventWithShaders = {
        '8': '713834379092000',
        '10': 1,
        '11': {
          '4': [
            {'6': 'shaders', '10': 'devtoolsTag'},
          ],
          '9': 1,
          '11': '31491',
          '22': ['Embedder'],
          '23': 'Rasterizer::DoDraw',
        },
        '58': 3,
      };
      trackEvent = PerfettoTrackEvent.fromPacket(
        TracePacket.fromJson(jsonEncode(trackEventWithShaders)),
      );
      expect(trackEvent.name, 'Rasterizer::DoDraw');
      expect(trackEvent.args, {'devtoolsTag': 'shaders'});
      expect(trackEvent.categories, ['Embedder']);
      expect(trackEvent.trackId, Int64(31491));
      expect(trackEvent.type, PerfettoEventType.sliceBegin);
      expect(trackEvent.timelineEventType, null);
      expect(trackEvent.flutterFrameNumber, null);
      expect(trackEvent.isUiFrameIdentifier, false);
      expect(trackEvent.isRasterFrameIdentifier, false);
      expect(trackEvent.isShaderEvent, true);
    });
  });
}
