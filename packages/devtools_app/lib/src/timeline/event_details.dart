// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart' hide TimelineEvent;

import '../common_widgets.dart';
import '../globals.dart';
import '../profiler/cpu_profile_controller.dart';
import '../profiler/cpu_profile_model.dart';
import '../profiler/cpu_profiler.dart';
import '../trace_event.dart';
import '../utils.dart';
import 'timeline_controller.dart';
import 'timeline_model.dart';

class EventDetails extends StatelessWidget {
  const EventDetails(this.selectedEvent);

  static const instructions =
      'Select an event from the Timeline to view details';
  static const noEventSelected = '[No event selected]';

  final TimelineEvent selectedEvent;

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): when in offlineMode and selectedEvent doesn't match the event
    // from the offline data, show message notifying that CPU profile data is
    // unavailable for snapshots and provide link to return to offline profile
    // (see html_event_details.dart).
    final controller = Provider.of<TimelineController>(context);
    final textTheme = Theme.of(context).textTheme;
    return OutlineDecoration(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          areaPaneHeader(
            context,
            needsTopBorder: false,
            title: selectedEvent != null
                ? '${selectedEvent.name} - ${msText(selectedEvent.time.duration)}'
                : noEventSelected,
          ),
          Expanded(
            child: selectedEvent != null
                ? _buildDetails(controller)
                : _buildInstructions(textTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(TimelineController controller) {
    if (selectedEvent.isUiEvent) {
      // In [offlineMode], we do not need to worry about whether the profiler is
      // enabled.
      if (offlineMode) {
        return _buildCpuProfiler(controller.cpuProfilerController);
      }
      return ValueListenableBuilder<Flag>(
        valueListenable: controller.cpuProfilerController.profilerFlagNotifier,
        builder: (context, profilerFlag, _) {
          return profilerFlag.valueAsString == 'true'
              ? _buildCpuProfiler(controller.cpuProfilerController)
              : CpuProfilerDisabled(controller.cpuProfilerController);
        },
      );
    }
    return EventSummary(selectedEvent);
  }

  Widget _buildCpuProfiler(CpuProfilerController cpuProfilerController) {
    return ValueListenableBuilder<CpuProfileData>(
      valueListenable: cpuProfilerController.dataNotifier,
      builder: (context, cpuProfileData, _) {
        if (cpuProfileData == null) {
          return _buildProcessingInfo(cpuProfilerController);
        }
        return CpuProfiler(
          data: cpuProfileData,
          controller: cpuProfilerController,
        );
      },
    );
  }

  Widget _buildProcessingInfo(CpuProfilerController cpuProfilerController) {
    return ValueListenableBuilder(
      valueListenable: cpuProfilerController.transformer.progressNotifier,
      builder: (context, progress, _) {
        return processingInfo(
          progressValue: progress,
          processedObject: 'CPU samples',
        );
      },
    );
  }

  Widget _buildInstructions(TextTheme textTheme) {
    return Center(
      child: Text(
        instructions,
        style: textTheme.subtitle1,
      ),
    );
  }
}

class EventSummary extends StatelessWidget {
  EventSummary(this.event)
      : _connectedEvents = [
          if (event.isAsyncEvent)
            ...event.children.where((e) => e.isAsyncInstantEvent)
        ],
        _eventArgs = Map.from(event.traceEvents.first.event.args)
          ..addAll({for (var trace in event.traceEvents) ...trace.event.args});

  static const encoder = JsonEncoder.withIndent('  ');

  final TimelineEvent event;

  final List<AsyncTimelineEvent> _connectedEvents;

  final Map<String, dynamic> _eventArgs;

  TraceEvent get firstTraceEvent => event.traceEvents.first.event;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: const Text('Time'),
          subtitle: Text('${event.time.start.inMicroseconds} μs —  '
              '${event.time.end.inMicroseconds} μs'),
        ),
        ListTile(
          title: const Text('Thread id'),
          subtitle: Text('${firstTraceEvent.threadId}'),
        ),
        ListTile(
          title: const Text('Process id'),
          subtitle: Text('${firstTraceEvent.processId}'),
        ),
        ListTile(
          title: const Text('Category'),
          subtitle: Text(firstTraceEvent.category),
        ),
        if (event.isAsyncEvent) _asyncIdTile(),
        if (_connectedEvents.isNotEmpty) _buildConnectedEvents(),
        if (_eventArgs.isNotEmpty) _buildArguments(),
      ],
    );
  }

  Widget _asyncIdTile() {
    String asyncId;
    if (event is OfflineTimelineEvent) {
      asyncId = event.traceEvents.first.event.id;
    } else {
      asyncId = (event as AsyncTimelineEvent).asyncId;
    }
    return ListTile(
      title: const Text('Async id'),
      subtitle: Text(asyncId),
    );
  }

  Widget _buildConnectedEvents() {
    return ExpansionTile(
      title: const Text('Connected events'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var e in _connectedEvents) _buildConnectedEvent(e),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectedEvent(TimelineEvent e) {
    final eventArgs = {
      'startTime': msText(e.time.start - event.time.start),
      'args': e.traceEvents.first.event.args,
    };
    return ListTile(
      title: Text(e.name),
      subtitle: _formattedArgs(eventArgs),
    );
  }

  Widget _buildArguments() {
    return ExpansionTile(
      title: const Text('Arguments'),
      children: [
        ListTile(
          subtitle: _formattedArgs(_eventArgs),
        ),
      ],
    );
  }

  Widget _formattedArgs(Map<String, dynamic> args) {
    final formattedArgs = encoder.convert(args);
    return Text(
      formattedArgs.replaceAll('"', ''),
      style: const TextStyle(fontFamily: 'RobotoMono'),
    );
  }
}
