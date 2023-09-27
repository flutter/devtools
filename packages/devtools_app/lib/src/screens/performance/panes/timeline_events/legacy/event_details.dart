// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/primitives/trace_event.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../performance_model.dart';

class EventDetails extends StatelessWidget {
  const EventDetails(this.selectedEvent, {super.key});

  static const instructions =
      'Select an event from the Timeline to view details';
  static const noEventSelected = '[No event selected]';

  final TimelineEvent? selectedEvent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AreaPaneHeader(
          title: Text(_generateHeaderText()),
          roundedTopBorder: false,
        ),
        Expanded(
          child: selectedEvent != null
              ? EventSummary(selectedEvent!)
              : Center(
                  child: Text(
                    instructions,
                    style: theme.subtleTextStyle,
                  ),
                ),
        ),
      ],
    );
  }

  String _generateHeaderText() {
    if (selectedEvent == null) {
      return noEventSelected;
    }
    final selected = selectedEvent!;
    return '${selected.name} (${durationText(selected.time.duration)})';
  }
}

class EventSummary extends StatelessWidget {
  EventSummary(this.event, {super.key})
      : _connectedEvents = [
          if (event.isAsyncEvent)
            ...event.children
                .cast<AsyncTimelineEvent>()
                .where((e) => e.isAsyncInstantEvent),
        ],
        _eventArgs = Map.from(event.traceEvents.first.event.args!)
          ..addAll({for (var trace in event.traceEvents) ...trace.event.args!});

  static const _detailsSpacing = 32.0;

  final TimelineEvent event;

  final List<AsyncTimelineEvent> _connectedEvents;

  final Map<String, dynamic> _eventArgs;

  TraceEvent get firstTraceEvent => event.traceEvents.first.event;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: denseSpacing),
      children: [
        // Wrap with horizontal padding so that these items align with the
        // expanding data items. Adding horizontal padding to the entire list
        // affects the hover boundary for the clickable expanding tiles.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: EventMetaData(
                  title: 'Time',
                  inlineValue: durationText(event.time.duration),
                  child: SelectableText(
                    '[${durationText(event.time.start!, unit: DurationDisplayUnit.micros)} —  '
                    '${durationText(event.time.end!, unit: DurationDisplayUnit.micros)}]',
                    style: Theme.of(context).subtleFixedFontStyle,
                  ),
                ),
              ),
              const SizedBox(width: _detailsSpacing),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EventMetaData(
                      title: 'Thread id',
                      inlineValue: '${firstTraceEvent.threadId}',
                    ),
                    EventMetaData(
                      title: 'Process id',
                      inlineValue: '${firstTraceEvent.processId}',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _detailsSpacing),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EventMetaData(
                      title: 'Category',
                      inlineValue: '${firstTraceEvent.category}',
                    ),
                    if (event.isAsyncEvent) _asyncIdTile(),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_connectedEvents.isNotEmpty) _buildConnectedEvents(),
        if (_eventArgs.isNotEmpty) _buildArguments(),
      ],
    );
  }

  Widget _asyncIdTile() {
    late final String asyncId;
    asyncId = event is OfflineTimelineEvent
        ? event.traceEvents.first.event.id as String
        : (event as AsyncTimelineEvent).asyncId;
    return EventMetaData(
      title: 'Async id',
      inlineValue: asyncId,
    );
  }

  Widget _buildConnectedEvents() {
    return ExpandingEventMetaData(
      title: 'Connected events',
      children: [
        for (var e in _connectedEvents) _buildConnectedEvent(e),
      ],
    );
  }

  Widget _buildConnectedEvent(TimelineEvent e) {
    final eventArgs = {
      'startTime': durationText(e.time.start! - event.time.start!),
      'args': e.traceEvents.first.event.args,
    };
    return EventMetaData(
      title: e.name ?? '',
      child: FormattedJson(
        json: eventArgs,
        useSubtleStyle: true,
      ),
    );
  }

  Widget _buildArguments() {
    return ExpandingEventMetaData(
      title: 'Arguments',
      children: [
        FormattedJson(
          json: _eventArgs,
          useSubtleStyle: true,
        ),
      ],
    );
  }
}

class EventMetaData extends StatelessWidget {
  const EventMetaData({
    Key? key,
    required this.title,
    this.inlineValue,
    this.child,
  })  : assert(inlineValue != null || child != null),
        super(key: key);

  final String title;

  final String? inlineValue;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText.rich(
          TextSpan(
            text: '$title${inlineValue != null ? ':  ' : ''}',
            style: theme.textTheme.titleSmall,
            children: [
              if (inlineValue != null)
                TextSpan(
                  text: inlineValue,
                  style: theme.subtleFixedFontStyle,
                ),
            ],
          ),
        ),
        if (child != null) ...[
          const SizedBox(height: densePadding),
          child!,
        ],
      ],
    );
  }
}

class ExpandingEventMetaData extends StatelessWidget {
  const ExpandingEventMetaData({
    Key? key,
    required this.title,
    required this.children,
  }) : super(key: key);

  final String title;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      childrenPadding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
      expandedAlignment: Alignment.topLeft,
      children: children,
    );
  }
}
