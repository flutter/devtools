// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../flutter/common_widgets.dart';
import '../../profiler/flutter/cpu_profiler.dart';
import '../../ui/fake_flutter/_real_flutter.dart';
import '../../utils.dart';
import '../timeline_model.dart';

class EventDetails extends StatelessWidget {
  const EventDetails(this.selectedEvent);

  final TimelineEvent selectedEvent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            '${selectedEvent.name} - ${msText(selectedEvent.time.duration)}',
            style: Theme.of(context).textTheme.title,
          ),
        ),
        const PaddedDivider.thin(),
        Expanded(
          child: selectedEvent.isUiEvent
              ? CpuProfilerView()
              : EventSummary(selectedEvent),
        ),
      ],
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

// TODO(kenz): remove stub data once timeline is hooked up to real data.
final stubAsyncEvent = AsyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'PipelineItem',
    'cat': 'Embedder',
    'tid': 19333,
    'pid': 94955,
    'ts': 118039650806,
    'ph': 's',
    'id': 'f1',
    'args': {
      'isolateId': 'id_001',
      'parentId': '07bf',
    },
  }))),
  0,
))
  ..addEndEvent(TraceEventWrapper(
    TraceEvent(jsonDecode(jsonEncode({
      'name': 'PipelineItem',
      'cat': 'Embedder',
      'tid': 19334,
      'pid': 94955,
      'ts': 118039679872,
      'ph': 'f',
      'bp': 'e',
      'id': 'f1',
      'args': {},
    }))),
    1,
  ))
  ..type = TimelineEventType.async
  ..children.addAll([
    instantAsync1..time.end = instantAsync1.time.start,
    instantAsync2..time.end = instantAsync2.time.start,
    instantAsync3..time.end = instantAsync3.time.start,
  ]);

final instantAsync1 = AsyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'Connection established',
    'cat': 'Dart',
    'tid': 19333,
    'pid': 94955,
    'ts': 118039660806,
    'ph': 'n',
    'id': 'f1',
    'args': {
      'isolateId': 'id_001',
    },
  }))),
  0,
));

final instantAsync2 = AsyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'Connection established',
    'cat': 'Dart',
    'tid': 19334,
    'pid': 94955,
    'ts': 118039665806,
    'ph': 'n',
    'id': 'f1',
    'args': {
      'isolateId': 'id_001',
    },
  }))),
  1,
));

final instantAsync3 = AsyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'Connection established',
    'cat': 'Dart',
    'tid': 19334,
    'pid': 94955,
    'ts': 118039670806,
    'ph': 'n',
    'id': 'f1',
    'args': {
      'isolateId': 'id_001',
    },
  }))),
  1,
));

final stubUiEvent = SyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'VSYNC',
    'cat': 'Embedder',
    'tid': 19333,
    'pid': 94955,
    'ts': 118039650802,
    'ph': 'B',
    'args': {},
  }))),
  0,
))
  ..addEndEvent(TraceEventWrapper(
    TraceEvent(jsonDecode(jsonEncode({
      'name': 'VSYNC',
      'cat': 'Embedder',
      'tid': 19333,
      'pid': 94955,
      'ts': 118039652422,
      'ph': 'E',
      'args': {},
    }))),
    1,
  ))
  ..type = TimelineEventType.ui;

final stubGpuEvent = SyncTimelineEvent(TraceEventWrapper(
  TraceEvent(jsonDecode(jsonEncode({
    'name': 'GPURasterizer::Draw',
    'cat': 'Embedder',
    'tid': 19334,
    'pid': 94955,
    'ts': 118039651469,
    'ph': 'B',
    'args': {
      'isolateId': 'id_001',
    },
  }))),
  0,
))
  ..addEndEvent(TraceEventWrapper(
    TraceEvent(jsonDecode(jsonEncode({
      'name': 'GPURasterizer::Draw',
      'cat': 'Embedder',
      'tid': 19334,
      'pid': 94955,
      'ts': 118039679873,
      'ph': 'E',
      'args': {},
    }))),
    1,
  ))
  ..type = TimelineEventType.gpu;
