// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide TimelineEvent;

import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/globals.dart';
import '../../../../../shared/primitives/trace_event.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/theme.dart';
import '../../../../../shared/ui/vm_flag_widgets.dart';
import '../../../../profiler/cpu_profile_controller.dart';
import '../../../../profiler/cpu_profile_model.dart';
import '../../../../profiler/cpu_profiler.dart';
import '../../../../profiler/panes/controls/profiler_controls.dart';
import '../../../performance_model.dart';
import '../../../performance_screen.dart';
import 'legacy_events_controller.dart';

class EventDetails extends StatelessWidget {
  const EventDetails(this.selectedEvent, this.legacyController);

  static const instructions =
      'Select an event from the Timeline to view details';
  static const noEventSelected = '[No event selected]';

  final TimelineEvent? selectedEvent;

  final LegacyTimelineEventsController legacyController;

  @override
  Widget build(BuildContext context) {
    // TODO(kenz): when in offlineMode and selectedEvent doesn't match the event
    // from the offline data, show message notifying that CPU profile data is
    // unavailable for snapshots and provide link to return to offline profile
    // (see html_event_details.dart).
    final theme = Theme.of(context);
    return DualValueListenableBuilder<bool, Flag>(
      firstListenable: offlineController.offlineMode,
      secondListenable:
          legacyController.cpuProfilerController.profilerFlagNotifier!,
      builder: (context, offline, profilerFlag, _) {
        final profilerEnabled = profilerFlag.valueAsString == 'true';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AreaPaneHeader(
              tall: true,
              title: Text(_generateHeaderText()),
              actions: [
                if (selectedEvent != null &&
                    selectedEvent!.isUiEvent &&
                    !offline &&
                    profilerEnabled)
                  CpuSamplingRateDropdown(
                    screenId: PerformanceScreen.id,
                    profilePeriodFlagNotifier: legacyController
                        .cpuProfilerController.profilePeriodFlag!,
                  ),
              ],
              roundedTopBorder: false,
            ),
            Expanded(
              child: selectedEvent != null
                  ? _buildDetails(offline, profilerEnabled)
                  : _buildInstructions(theme),
            ),
          ],
        );
      },
    );
  }

  String _generateHeaderText() {
    if (selectedEvent == null) {
      return noEventSelected;
    }
    final selected = selectedEvent!;
    return '${selected.isUiEvent ? 'CPU Profile: ' : ''}'
        '${selected.name} (${msText(selected.time.duration)})';
  }

  Widget _buildDetails(bool offlineMode, bool profilerEnabled) {
    final selected = selectedEvent!;
    if (selected.isUiEvent) {
      // In [offlineController.offlineMode], we do not need to worry about
      // whether the profiler is enabled.
      if (offlineMode) {
        return _buildCpuProfiler(legacyController.cpuProfilerController);
      }
      return profilerEnabled
          ? _buildCpuProfiler(legacyController.cpuProfilerController)
          : CpuProfilerDisabled(legacyController.cpuProfilerController);
    }
    return EventSummary(selected);
  }

  Widget _buildCpuProfiler(CpuProfilerController cpuProfilerController) {
    return ValueListenableBuilder<CpuProfileData?>(
      valueListenable: cpuProfilerController.dataNotifier,
      builder: (context, cpuProfileData, child) {
        if (cpuProfileData == null) {
          return child!;
        }
        return CpuProfiler(
          data: cpuProfileData,
          controller: cpuProfilerController,
          summaryView: EventSummary(selectedEvent!),
        );
      },
      child: _buildProcessingInfo(cpuProfilerController),
    );
  }

  Widget _buildProcessingInfo(CpuProfilerController cpuProfilerController) {
    return ValueListenableBuilder<double>(
      valueListenable: cpuProfilerController.transformer.progressNotifier,
      builder: (context, progress, _) {
        return ProcessingInfo(
          progressValue: progress,
          processedObject: 'CPU samples',
        );
      },
    );
  }

  Widget _buildInstructions(ThemeData theme) {
    return Center(
      child: Text(
        instructions,
        style: theme.subtleTextStyle,
      ),
    );
  }
}

class EventSummary extends StatelessWidget {
  EventSummary(this.event)
      : _connectedEvents = [
          if (event.isAsyncEvent)
            ...event.children
                .cast<AsyncTimelineEvent>()
                .where((e) => e.isAsyncInstantEvent),
        ],
        _eventArgs = Map.from(event.traceEvents.first.event.args!)
          ..addAll({for (var trace in event.traceEvents) ...trace.event.args!});

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
          child: EventMetaData(
            title: 'Time',
            inlineValue: msText(event.time.duration),
            child: SelectableText(
              '[${event.time.start!.inMicroseconds} μs —  '
              '${event.time.end!.inMicroseconds} μs]',
              style: Theme.of(context).subtleFixedFontStyle,
            ),
          ),
        ),
        // Wrap with horizontal padding so that these items align with the
        // expanding data items. Adding horizontal padding to the entire list
        // affects the hover boundary for the clickable expanding tiles.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
          child: Row(
            children: [
              Flexible(
                fit: FlexFit.tight,
                child: EventMetaData(
                  title: 'Category',
                  inlineValue: '${firstTraceEvent.category}',
                ),
              ),
              if (event.isAsyncEvent)
                Flexible(
                  fit: FlexFit.tight,
                  child: _asyncIdTile(),
                ),
              Flexible(
                fit: FlexFit.tight,
                child: EventMetaData(
                  title: 'Thread id',
                  inlineValue: '${firstTraceEvent.threadId}',
                ),
              ),
              Flexible(
                fit: FlexFit.tight,
                child: EventMetaData(
                  title: 'Process id',
                  inlineValue: '${firstTraceEvent.processId}',
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
      'startTime': msText(e.time.start! - event.time.start!),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: denseSpacing),
      child: Column(
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
      ),
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
