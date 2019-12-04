// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
import '../../flutter/controllers.dart';
import '../../profiler/cpu_profile_model.dart';
import '../../profiler/flutter/cpu_profiler.dart';
import '../../ui/fake_flutter/_real_flutter.dart';
import '../../utils.dart';
import '../timeline_controller.dart';
import '../timeline_model.dart';

class EventDetails extends StatelessWidget {
  const EventDetails(this.selectedEvent);

  static const instructions =
      'Select an event from the Timeline to view details';
  static const noEventSelected = '[No event selected]';

  final TimelineEvent selectedEvent;

  @override
  Widget build(BuildContext context) {
    final controller = Controllers.of(context).timeline;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            selectedEvent != null
                ? '${selectedEvent.name} - ${msText(selectedEvent.time.duration)}'
                : noEventSelected,
            style: textTheme.title,
          ),
        ),
        const PaddedDivider.thin(),
        Expanded(
          child: selectedEvent != null
              ? _buildDetails(controller)
              : _buildInstructions(textTheme),
        ),
      ],
    );
  }

  Widget _buildDetails(TimelineController controller) {
    return selectedEvent.isUiEvent
        ? ValueListenableBuilder(
            valueListenable: controller.cpuProfilerController.dataNotifier,
            builder: (context, cpuProfileData, _) {
              return _buildCpuProfiler(cpuProfileData, controller);
            },
          )
        : EventSummary(selectedEvent);
  }

  Widget _buildCpuProfiler(CpuProfileData data, TimelineController controller) {
    return ValueListenableBuilder(
      valueListenable:
          controller.cpuProfilerController.selectedCpuStackFrameNotifier,
      builder: (context, selectedStackFrame, _) {
        return CpuProfiler(
          data: data,
          selectedStackFrame: selectedStackFrame,
          onStackFrameSelected: (sf) =>
              controller.cpuProfilerController.selectCpuStackFrame(sf),
        );
      },
    );
  }

  Widget _buildInstructions(TextTheme textTheme) {
    return Center(
      child: Text(
        instructions,
        style: textTheme.subhead,
      ),
    );
  }
}

class EventSummary extends StatelessWidget {
  EventSummary(this.event)
      : _connectedEvents = [
          if (event.isAsyncEvent)
            ...event.children.where((e) =>
                e.traceEvents.first.event.phase == TraceEvent.asyncInstantPhase)
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
        if (_connectedEvents.isNotEmpty) _buildConnectedEvents(),
        if (_eventArgs.isNotEmpty) _buildArguments(),
      ],
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
      // TODO(kenz): make monospace font work for flutter desktop.
      style: const TextStyle(fontFamily: 'monospace'),
    );
  }
}
