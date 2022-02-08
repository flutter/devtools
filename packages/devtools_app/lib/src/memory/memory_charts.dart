// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../charts/chart_trace.dart';
import '../primitives/utils.dart';
import 'memory_android_chart.dart' as android;
import 'memory_controller.dart';
import 'memory_events_pane.dart' as events;
import 'memory_vm_chart.dart' as vm;

/// Event types handled for hover card.
const devToolsEvent = 'DevTools.Event';
const imageSizesForFrameEvent = 'Flutter.ImageSizesForFrame';
const displaySizeInBytesData = 'displaySizeInBytes';
const decodedSizeInBytesData = 'decodedSizeInBytes';

const String eventName = 'name';
const String eventData = 'data';
const String customEvent = 'custom';
const String customEventName = 'name';
const String customEventData = 'data';

const String indexPayloadJson = 'index';
const String timestampPayloadJson = 'timestamp';
const String prettyTimestampPayloadJson = 'prettyTimestamp';
const String eventPayloadJson = 'event';
const String vmPayloadJson = 'vm';
const String androidPayloadJson = 'android';

/// VM Data
const String rssJsonName = 'rss';
const String capacityJsonName = 'capacity';
const String usedJsonName = 'used';
const String externalJsonName = 'external';
const String rasterPictureJsonName = 'rasterLayer';
const String rasterLayerJsonName = 'rasterPicture';

/// Android data
const String adbTotalJsonName = 'total';
const String adbOtherJsonName = 'other';
const String adbCodeJsonName = 'code';
const String adbNativeHeapJsonName = 'nativeHeap';
const String adbJavaHeapJsonName = 'javaHeap';
const String adbStackJsonName = 'stack';
const String adbGraphicsJsonName = 'graphics';

/// Events data
const String snapshotJsonName = 'snapshot';
const String autoSnapshotJsonName = 'autoSnapshot';
const String monitorStartJsonName = 'monitorStart';
const String monitorResetJsonName = 'monitorReset';
const String extensionEventsJsonName = 'extensionEvents';
const String manualGCJsonName = 'manualGC';
const String gcJsonName = 'gc';

/// Dart VM trace names
const allocatedDisplay = 'Allocated';
const usedDisplay = 'Dart/Flutter';
const externalDisplay = 'Dart/Flutter Native';
const rssDisplay = 'RSS';
const layerDisplay = 'Raster Layer';
const pictureDisplay = 'Raster Picture';

/// Android Memory Trace names
const androidTotalDisplay = 'Total';
const androidOtherDisplay = 'Other';
const androidCodeDisplay = 'Code';
const androidNativeDisplay = 'Native';
const androidJavaDisplay = 'Java';
const androidStackDisplay = 'Stack';
const androidGraphicsDisplay = 'Graphics';

/// Display name is either '1 Event' or 'n Events'
const eventDisplayName = ' Event';
const eventsDisplayName = ' Events';

/// Manages how legend and hover data and trace color and
/// dash lines are drawn.
const renderLine = 'color';
const renderDashed = 'dashed';
const renderImage = 'image';

Map<String, Object> traceRender({
  String image,
  Color color,
  bool dashed = false,
}) {
  final result = <String, Object>{};

  if (image != null) {
    result[renderImage] = image;
  } else {
    result[renderLine] = color;
    result[renderDashed] = dashed;
  }

  return result;
}

/// Retrieve all data values of a given index (timestamp) of the collected data.
class ChartsValues {
  ChartsValues(this.controller, this.index, this.timestamp) {
    _getDataFromIndex();
  }

  final MemoryController controller;

  final int index;

  final int timestamp;

  final _event = <String, Object>{};

  final _extensionEvents = <Map<String, Object>>[];

  Map<String, Object> get vmData => _vm;

  final _vm = <String, Object>{};

  Map<String, Object> get androidData => _android;

  final _android = <String, Object>{};

  Map<String, Object> toJson() {
    return {
      indexPayloadJson: index,
      timestampPayloadJson: timestamp,
      prettyTimestampPayloadJson: prettyTimestamp(timestamp),
      eventPayloadJson: _event,
      vmPayloadJson: _vm,
      androidPayloadJson: _android,
    };
  }

  int get eventCount =>
      _event.entries.length -
      (extensionEventsLength > 0 ? 1 : 0) +
      (hasGc ? 1 : 0);

  bool get hasSnapshot => _event.containsKey(snapshotJsonName);

  bool get hasAutoSnapshot => _event.containsKey(autoSnapshotJsonName);

  bool get hasMonitorStart => _event.containsKey(monitorStartJsonName);

  bool get hasMonitorReset => _event.containsKey(monitorResetJsonName);

  bool get hasExtensionEvents => _event.containsKey(extensionEventsJsonName);

  bool get hasManualGc => _event.containsKey(manualGCJsonName);

  bool get hasGc => _vm[gcJsonName];

  int get extensionEventsLength =>
      hasExtensionEvents ? extensionEvents.length : 0;

  List<Map<String, Object>> get extensionEvents {
    if (_extensionEvents.isEmpty) {
      _extensionEvents.addAll(_event[extensionEventsJsonName]);
    }
    return _extensionEvents;
  }

  void _getDataFromIndex() {
    _event.clear();
    _vm.clear();
    _android.clear();

    _getEventData(_event);
    _getVMData(_vm);
    _getAndroidData(_android);
  }

  void _getEventData(Map<String, Object> results) {
    // Use the detailed extension events data stored in the memoryTimeline.
    final eventInfo = controller.memoryTimeline.data[index].memoryEventInfo;

    if (eventInfo.isEmpty) return;

    if (eventInfo.isEventGC) results[manualGCJsonName] = true;
    if (eventInfo.isEventSnapshot) results[snapshotJsonName] = true;
    if (eventInfo.isEventSnapshotAuto) results[autoSnapshotJsonName] = true;
    if (eventInfo.isEventAllocationAccumulator) {
      if (eventInfo.allocationAccumulator.isStart) {
        results[monitorStartJsonName] = true;
      }
      if (eventInfo.allocationAccumulator.isReset) {
        results[monitorResetJsonName] = true;
      }
    }

    if (eventInfo.hasExtensionEvents) {
      final events = <Map<String, Object>>[];
      for (ExtensionEvent event in eventInfo.extensionEvents.theEvents) {
        if (event.customEventName != null) {
          events.add(
            {
              eventName: event.eventKind,
              customEvent: {
                customEventName: event.customEventName,
                customEventData: event.data,
              },
            },
          );
        } else {
          events.add({eventName: event.eventKind, eventData: event.data});
        }
      }
      if (events.isNotEmpty) {
        results[extensionEventsJsonName] = events;
      }
    }
  }

  void _getVMData(Map<String, Object> results) {
    final HeapSample heapSample = controller.memoryTimeline.data[index];

    results[rssJsonName] = heapSample.rss;
    results[capacityJsonName] = heapSample.capacity;
    results[usedJsonName] = heapSample.used;
    results[externalJsonName] = heapSample.external;
    results[gcJsonName] = heapSample.isGC;
    results[rasterPictureJsonName] = heapSample.rasterCache.pictureBytes;
    results[rasterLayerJsonName] = heapSample.rasterCache.layerBytes;
  }

  void _getAndroidData(Map<String, Object> results) {
    final AdbMemoryInfo androidData =
        controller.memoryTimeline.data[index].adbMemoryInfo;

    results[adbTotalJsonName] = androidData.total;
    results[adbOtherJsonName] = androidData.other;
    results[adbCodeJsonName] = androidData.code;
    results[adbNativeHeapJsonName] = androidData.nativeHeap;
    results[adbJavaHeapJsonName] = androidData.javaHeap;
    results[adbStackJsonName] = androidData.stack;
    results[adbGraphicsJsonName] = androidData.graphics;
  }

  Map<String, String> eventsToDisplay(bool isLight) {
    final eventsDisplayed = <String, String>{};

    if (hasSnapshot) {
      eventsDisplayed['Snapshot'] = events.snapshotManualLegend;
    } else if (hasAutoSnapshot) {
      eventsDisplayed['Auto Snapshot'] = events.snapshotAutoLegend;
    } else if (hasMonitorStart) {
      eventsDisplayed['Monitor Start'] = events.monitorLegend;
    } else if (hasMonitorReset) {
      eventsDisplayed['Monitor Reset'] =
          isLight ? events.resetLightLegend : events.resetDarkLegend;
    }

    if (hasGc) {
      eventsDisplayed['GC'] = events.gcVMLegend;
    }

    if (hasManualGc) {
      eventsDisplayed['User GC'] = events.gcManualLegend;
    }

    return eventsDisplayed;
  }

  Map<String, String> get extensionEventsToDisplay {
    final eventsDisplayed = <String, String>{};

    if (hasExtensionEvents) {
      final eventLength = extensionEventsLength;
      if (eventLength > 0) {
        final displayKey = '$eventLength'
            '${eventLength == 1 ? eventDisplayName : eventsDisplayName}';
        eventsDisplayed[displayKey] =
            eventLength == 1 ? events.eventLegend : events.eventsLegend;
      }
    }

    return eventsDisplayed;
  }

  Map<String, Map<String, Object>> displayVmDataToDisplay(List<Trace> traces) {
    final vmDataDisplayed = <String, Map<String, Object>>{};

    final rssValueDisplay = formatNumeric(vmData[rssJsonName]);
    vmDataDisplayed['$rssDisplay $rssValueDisplay'] = traceRender(
      color: traces[vm.TraceName.rSS.index].characteristics.color,
      dashed: true,
    );

    final capacityValueDisplay = formatNumeric(vmData[capacityJsonName]);
    vmDataDisplayed['$allocatedDisplay $capacityValueDisplay'] = traceRender(
      color: traces[vm.TraceName.capacity.index].characteristics.color,
      dashed: true,
    );

    final usedValueDisplay = formatNumeric(vmData[usedJsonName]);
    vmDataDisplayed['$usedDisplay $usedValueDisplay'] = traceRender(
      color: traces[vm.TraceName.used.index].characteristics.color,
    );

    final externalValueDisplay = formatNumeric(vmData[externalJsonName]);
    vmDataDisplayed['$externalDisplay $externalValueDisplay'] = traceRender(
      color: traces[vm.TraceName.external.index].characteristics.color,
    );

    final layerValueDisplay = formatNumeric(vmData[rasterLayerJsonName]);
    vmDataDisplayed['$layerDisplay $layerValueDisplay'] = traceRender(
      color: traces[vm.TraceName.rasterLayer.index].characteristics.color,
      dashed: true,
    );

    final pictureValueDisplay = formatNumeric(vmData[rasterPictureJsonName]);
    vmDataDisplayed['$pictureDisplay $pictureValueDisplay'] = traceRender(
      color: traces[vm.TraceName.rasterPicture.index].characteristics.color,
      dashed: true,
    );

    return vmDataDisplayed;
  }

  Map<String, Map<String, Object>> androidDataToDisplay(List<Trace> traces) {
    final androidDataDisplayed = <String, Map<String, Object>>{};

    if (controller.isAndroidChartVisible) {
      final data = androidData;

      // Total trace
      final totalValueDisplay = formatNumeric(data[adbTotalJsonName]);
      androidDataDisplayed['$androidTotalDisplay $totalValueDisplay'] =
          traceRender(
        color: traces[android.TraceName.total.index].characteristics.color,
        dashed: true,
      );

      // Other trace
      final otherValueDisplay = formatNumeric(data[adbOtherJsonName]);
      androidDataDisplayed['$androidOtherDisplay $otherValueDisplay'] =
          traceRender(
        color: traces[android.TraceName.other.index].characteristics.color,
      );

      // Native heap trace
      final nativeValueDisplay = formatNumeric(data[adbNativeHeapJsonName]);
      androidDataDisplayed['$androidNativeDisplay $nativeValueDisplay'] =
          traceRender(
        color: traces[android.TraceName.nativeHeap.index].characteristics.color,
      );

      // Graphics trace
      final graphicsValueDisplay = formatNumeric(data[adbGraphicsJsonName]);
      androidDataDisplayed['$androidGraphicsDisplay $graphicsValueDisplay'] =
          traceRender(
        color: traces[android.TraceName.graphics.index].characteristics.color,
      );

      // Code trace
      final codeValueDisplay = formatNumeric(data[adbCodeJsonName]);
      androidDataDisplayed['$androidCodeDisplay $codeValueDisplay'] =
          traceRender(
        color: traces[android.TraceName.code.index].characteristics.color,
      );

      // Java heap trace
      final javaValueDisplay = formatNumeric(data[adbJavaHeapJsonName]);
      androidDataDisplayed['$androidJavaDisplay $javaValueDisplay'] =
          traceRender(
        color: traces[android.TraceName.javaHeap.index].characteristics.color,
      );

      // Stack trace
      final stackValueDisplay = formatNumeric(data[adbStackJsonName]);
      androidDataDisplayed['$androidStackDisplay $stackValueDisplay'] =
          traceRender(
        color: traces[android.TraceName.stack.index].characteristics.color,
      );
    }

    return androidDataDisplayed;
  }

  String formatNumeric(num number) => controller.unitDisplayed.value
      ? prettyPrintBytes(
          number,
          kbFractionDigits: 1,
          mbFractionDigits: 2,
          includeUnit: true,
          roundingPoint: 0.7,
        )
      : nf.format(number);
}
