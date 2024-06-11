// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/charts/chart_trace.dart';
import '../../../../../shared/primitives/byte_utils.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../shared/primitives/memory_timeline.dart';
//import '../../../framework/connected/memory_controller.dart';

/// Name of each trace being charted, index order is the trace index
/// too (order of trace creation top-down order).
enum AndroidTraceName {
  stack,
  javaHeap,
  code,
  graphics,
  nativeHeap,
  other,
  system,
  total,
}

const _base = 'assets/img/legend/';
const snapshotManualLegend = '${_base}snapshot_manual_glyph.png';
const snapshotAutoLegend = '${_base}snapshot_auto_glyph.png';
const monitorLegend = '${_base}monitor_glyph.png';
const resetDarkLegend = '${_base}reset_glyph_dark.png';
const resetLightLegend = '${_base}reset_glyph_light.png';
const gcManualLegend = '${_base}gc_manual_glyph.png';
const gcVMLegend = '${_base}gc_vm_glyph.png';
String eventLegendAsset(int eventCount) =>
    '$_base${pluralize('event', eventCount)}_glyph.png';

/// Event types handled for hover card.
const devToolsEvent = 'DevTools.Event';
const imageSizesForFrameEvent = 'Flutter.ImageSizesForFrame';
const displaySizeInBytesData = 'displaySizeInBytes';
const decodedSizeInBytesData = 'decodedSizeInBytes';

const eventName = 'name';
const eventData = 'data';
const customEvent = 'custom';
const customEventName = 'name';
const customEventData = 'data';

const indexPayloadJson = 'index';
const timestampPayloadJson = 'timestamp';
const prettyTimestampPayloadJson = 'prettyTimestamp';
const eventPayloadJson = 'event';
const vmPayloadJson = 'vm';
const androidPayloadJson = 'android';

/// VM Data
const rssJsonName = 'rss';
const capacityJsonName = 'capacity';
const usedJsonName = 'used';
const externalJsonName = 'external';
const rasterPictureJsonName = 'rasterLayer';
const rasterLayerJsonName = 'rasterPicture';

/// Android data
const adbTotalJsonName = 'total';
const adbOtherJsonName = 'other';
const adbCodeJsonName = 'code';
const adbNativeHeapJsonName = 'nativeHeap';
const adbJavaHeapJsonName = 'javaHeap';
const adbStackJsonName = 'stack';
const adbGraphicsJsonName = 'graphics';

/// Events data
const snapshotJsonName = 'snapshot';
const autoSnapshotJsonName = 'autoSnapshot';
const monitorStartJsonName = 'monitorStart';
const monitorResetJsonName = 'monitorReset';
const extensionEventsJsonName = 'extensionEvents';
const manualGCJsonName = 'manualGC';
const gcJsonName = 'gc';

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

/// Manages how legend and hover data and trace color and
/// dash lines are drawn.
const renderLine = 'color';
const renderDashed = 'dashed';
const renderImage = 'image';

/// Name of each trace being charted, index order is the trace index
/// too (order of trace creation top-down order).
enum VmTraceName {
  external,
  used,
  capacity,
  rSS,
  rasterLayer,
  rasterPicture,
}

Map<String, Object?> traceRender({
  String? image,
  Color? color,
  bool dashed = false,
}) {
  final result = <String, Object?>{};

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
  ChartsValues(
    this.memoryTimeline, {
    required this.index,
    required this.timestamp,
    required this.isAndroidChartVisible,
  }) {
    _getDataFromIndex();
  }

  final MemoryTimeline memoryTimeline;

  final ValueNotifier<bool> isAndroidChartVisible;

  final int index;

  final int timestamp;

  final _event = <String, bool>{};

  final _extensionEvents = <Map<String, bool>>[];

  Map<String, Object> get vmData => _vm;

  final _vm = <String, Object>{};

  Map<String, Object> get androidData => _android;

  final _android = <String, Object>{};

  Map<String, Object?> toJson() {
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

  bool get hasGc => _vm[gcJsonName] as bool;

  int get extensionEventsLength =>
      hasExtensionEvents ? extensionEvents.length : 0;

  List<Map<String, bool>> get extensionEvents {
    if (_extensionEvents.isEmpty) {
      final events = _event[extensionEventsJsonName] as List<Map<String, bool>>;
      _extensionEvents.addAll(events);
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
    final eventInfo = memoryTimeline.data[index].memoryEventInfo;

    if (eventInfo.isEmpty) return;

    if (eventInfo.isEventGC) results[manualGCJsonName] = true;
    if (eventInfo.isEventSnapshot) results[snapshotJsonName] = true;
    if (eventInfo.isEventSnapshotAuto) results[autoSnapshotJsonName] = true;
    if (eventInfo.isEventAllocationAccumulator) {
      if (eventInfo.allocationAccumulator!.isStart) {
        results[monitorStartJsonName] = true;
      }
      if (eventInfo.allocationAccumulator!.isReset) {
        results[monitorResetJsonName] = true;
      }
    }

    if (eventInfo.hasExtensionEvents) {
      final events = <Map<String, Object>>[];
      for (final event
          in eventInfo.extensionEvents?.events ?? <ExtensionEvent>[]) {
        if (event.customEventName != null) {
          events.add(
            {
              eventName: event.eventKind!,
              customEvent: {
                customEventName: event.customEventName,
                customEventData: event.data,
              },
            },
          );
        } else {
          events.add({
            eventName: event.eventKind!,
            eventData: event.data ?? {},
          });
        }
      }
      if (events.isNotEmpty) {
        results[extensionEventsJsonName] = events;
      }
    }
  }

  void _getVMData(Map<String, Object> results) {
    final heapSample = memoryTimeline.data[index];

    results[rssJsonName] = heapSample.rss;
    results[capacityJsonName] = heapSample.capacity;
    results[usedJsonName] = heapSample.used;
    results[externalJsonName] = heapSample.external;
    results[gcJsonName] = heapSample.isGC;
    results[rasterPictureJsonName] = heapSample.rasterCache.pictureBytes;
    results[rasterLayerJsonName] = heapSample.rasterCache.layerBytes;
  }

  void _getAndroidData(Map<String, Object> results) {
    final androidData = memoryTimeline.data[index].adbMemoryInfo;

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
      eventsDisplayed['Snapshot'] = snapshotManualLegend;
    } else if (hasAutoSnapshot) {
      eventsDisplayed['Auto Snapshot'] = snapshotAutoLegend;
    } else if (hasMonitorStart) {
      eventsDisplayed['Monitor Start'] = monitorLegend;
    } else if (hasMonitorReset) {
      eventsDisplayed['Monitor Reset'] =
          isLight ? resetLightLegend : resetDarkLegend;
    }

    if (hasGc) {
      eventsDisplayed['GC'] = gcVMLegend;
    }

    if (hasManualGc) {
      eventsDisplayed['User GC'] = gcManualLegend;
    }

    return eventsDisplayed;
  }

  Map<String, Map<String, Object?>> displayVmDataToDisplay(List<Trace> traces) {
    final vmDataDisplayed = <String, Map<String, Object?>>{};

    final rssValueDisplay = formatNumeric(vmData[rssJsonName] as num?);
    vmDataDisplayed['$rssDisplay $rssValueDisplay'] = traceRender(
      color: traces[VmTraceName.rSS.index].characteristics.color,
      dashed: true,
    );

    final capacityValueDisplay =
        formatNumeric(vmData[capacityJsonName] as num?);
    vmDataDisplayed['$allocatedDisplay $capacityValueDisplay'] = traceRender(
      color: traces[VmTraceName.capacity.index].characteristics.color,
      dashed: true,
    );

    final usedValueDisplay = formatNumeric(vmData[usedJsonName] as num?);
    vmDataDisplayed['$usedDisplay $usedValueDisplay'] = traceRender(
      color: traces[VmTraceName.used.index].characteristics.color,
    );

    final externalValueDisplay =
        formatNumeric(vmData[externalJsonName] as num?);
    vmDataDisplayed['$externalDisplay $externalValueDisplay'] = traceRender(
      color: traces[VmTraceName.external.index].characteristics.color,
    );

    final layerValueDisplay =
        formatNumeric(vmData[rasterLayerJsonName] as num?);
    vmDataDisplayed['$layerDisplay $layerValueDisplay'] = traceRender(
      color: traces[VmTraceName.rasterLayer.index].characteristics.color,
      dashed: true,
    );

    final pictureValueDisplay =
        formatNumeric(vmData[rasterPictureJsonName] as num?);
    vmDataDisplayed['$pictureDisplay $pictureValueDisplay'] = traceRender(
      color: traces[VmTraceName.rasterPicture.index].characteristics.color,
      dashed: true,
    );

    return vmDataDisplayed;
  }

  Map<String, Map<String, Object?>> androidDataToDisplay(List<Trace> traces) {
    final androidDataDisplayed = <String, Map<String, Object?>>{};

    if (isAndroidChartVisible.value) {
      final data = androidData;

      // Total trace
      final totalValueDisplay = formatNumeric(data[adbTotalJsonName] as num?);
      androidDataDisplayed['$androidTotalDisplay $totalValueDisplay'] =
          traceRender(
        color: traces[AndroidTraceName.total.index].characteristics.color,
        dashed: true,
      );

      // Other trace
      final otherValueDisplay = formatNumeric(data[adbOtherJsonName] as num?);
      androidDataDisplayed['$androidOtherDisplay $otherValueDisplay'] =
          traceRender(
        color: traces[AndroidTraceName.other.index].characteristics.color,
      );

      // Native heap trace
      final nativeValueDisplay =
          formatNumeric(data[adbNativeHeapJsonName] as num?);
      androidDataDisplayed['$androidNativeDisplay $nativeValueDisplay'] =
          traceRender(
        color: traces[AndroidTraceName.nativeHeap.index].characteristics.color,
      );

      // Graphics trace
      final graphicsValueDisplay =
          formatNumeric(data[adbGraphicsJsonName] as num?);
      androidDataDisplayed['$androidGraphicsDisplay $graphicsValueDisplay'] =
          traceRender(
        color: traces[AndroidTraceName.graphics.index].characteristics.color,
      );

      // Code trace
      final codeValueDisplay = formatNumeric(data[adbCodeJsonName] as num?);
      androidDataDisplayed['$androidCodeDisplay $codeValueDisplay'] =
          traceRender(
        color: traces[AndroidTraceName.code.index].characteristics.color,
      );

      // Java heap trace
      final javaValueDisplay = formatNumeric(data[adbJavaHeapJsonName] as num?);
      androidDataDisplayed['$androidJavaDisplay $javaValueDisplay'] =
          traceRender(
        color: traces[AndroidTraceName.javaHeap.index].characteristics.color,
      );

      // Stack trace
      final stackValueDisplay = formatNumeric(data[adbStackJsonName] as num?);
      androidDataDisplayed['$androidStackDisplay $stackValueDisplay'] =
          traceRender(
        color: traces[AndroidTraceName.stack.index].characteristics.color,
      );
    }

    return androidDataDisplayed;
  }

  String? formatNumeric(num? number) => prettyPrintBytes(
        number,
        mbFractionDigits: 2,
        includeUnit: true,
        roundingPoint: 0.7,
      );
}
