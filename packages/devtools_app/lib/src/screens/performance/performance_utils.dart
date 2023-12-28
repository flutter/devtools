// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import '../../shared/primitives/trace_event.dart';
import '../../shared/primitives/utils.dart';
import 'performance_model.dart';

// TODO(jacobr): make this a top level method.
// ignore: avoid_classes_with_only_static_members
class PerformanceUtils {
  static String computeEventGroupKey(
    TimelineEvent event,
    Map<int, String> threadNamesById,
  ) {
    if (event.groupKey != null) {
      return event.groupKey!;
    } else if (event.isAsyncEvent) {
      return event.root.name!;
    } else if (event.isUiEvent) {
      return PerformanceData.uiKey;
    } else if (event.isRasterEvent) {
      return PerformanceData.rasterKey;
    } else if (threadNamesById[event.threadId] != null) {
      return threadNamesById[event.threadId]!;
    } else {
      return PerformanceData.unknownKey;
    }
  }

  static int eventGroupComparator(String a, String b) {
    if (a == b) return 0;

    // TODO(kenz): Once https://github.com/flutter/flutter/issues/83835 is
    // addressed, match on the group key that all skia.shader events will have.
    // Order shader buckets first.
    final aIsShade = a.toLowerCase().contains('shade');
    final bIsShade = b.toLowerCase().contains('shade');
    if (aIsShade || bIsShade) {
      final shadeCompare = aIsShade.boolCompare(bIsShade);
      if (shadeCompare == 0) {
        // If they both have "shade" in the name, alphabetize them.
        return a.compareTo(b);
      }
      return shadeCompare;
    }

    // Order Unknown buckets last. Unknown buckets will be of the form "Unknown"
    // or "Unknown (12345)".
    final aIsUnknown = a.toLowerCase().contains(PerformanceData.unknownKey);
    final bIsUnknown = b.toLowerCase().contains(PerformanceData.unknownKey);
    if (aIsUnknown || bIsUnknown) {
      final unknownCompare = aIsUnknown.boolCompare(bIsUnknown);
      if (unknownCompare == 0) {
        // If they both have "Unknown" in the name, alphabetize them.
        return a.compareTo(b);
      }
      return unknownCompare;
    }

    // Order the Raster event bucket after the UI event bucket.
    if ((a == PerformanceData.uiKey && b == PerformanceData.rasterKey) ||
        (a == PerformanceData.rasterKey && b == PerformanceData.uiKey)) {
      return -1 * a.compareTo(b);
    }

    // Order non-UI and non-raster buckets after the UI / Raster buckets.
    if (a == PerformanceData.uiKey || a == PerformanceData.rasterKey) return -1;
    if (b == PerformanceData.uiKey || b == PerformanceData.rasterKey) return 1;

    // Alphabetize all other buckets.
    return a.compareTo(b);
  }
}

const debugTraceEventDuplicates = false;

/// Helper method to call a callback only when debugging issues related to trace
/// event duplicates (for example https://github.com/dart-lang/sdk/issues/46605).
void debugTraceEventCallback(VoidCallback callback) {
  if (debugTraceEventDuplicates) {
    callback();
  }
}

const preCompileShadersDocsUrl = 'https://docs.flutter.dev/perf/shader';

const impellerDocsUrl = 'https://docs.flutter.dev/perf/impeller';

extension TraceEventExtension on TraceEvent {
  bool get isThreadNameEvent =>
      phase == TraceEvent.metadataEventPhase &&
      name == TraceEvent.threadNameEvent;
}
