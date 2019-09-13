// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'message_manager.dart';
import 'ui/elements.dart';

final trackWidgetCreationWarning = Message(
  MessageType.warning,
  id: 'trackWidgetCreationWarningId',
  children: <CoreElement>[
    div()
      ..add(span(text: 'The '))
      ..add(a(
          text: 'widget creation tracking feature',
          href: _trackWidgetCreationDocsUrl,
          target: '_blank;'))
      ..add(span(text: ' is not enabled. '))
      ..add(span(text: '''This feature allows the Flutter inspector to present 
the widget tree in a manner similar to how the UI was defined in your source
code. Without it, the tree of nodes in the widget tree are much deeper, and it
can be more difficult to understand how the runtime widget hierarchy corresponds
to your application\’s UI.''')),
    div(text: '''To fix this, relaunch your application by running 
'flutter run --track-widget-creation' (or run your application from VS Code or
IntelliJ).'''),
  ],
);

const _trackWidgetCreationDocsUrl =
    'https://flutter.dev/docs/development/tools/devtools/inspector#track-widget-creation';

final debugWarning = Message(
  MessageType.warning,
  id: 'debugWarningId',
  children: <CoreElement>[
    div(
        text: 'You are running your app in debug mode. Debug mode frame '
            'rendering times are not indicative of release performance.'),
    div()
      ..add(span(
          text: '''Relaunch your application with the '--profile' argument, or 
'''))
      ..add(a(
          text: 'relaunch in profile mode from VS Code or IntelliJ',
          href: _runInProfileModeDocsUrl,
          target: '_blank;'))
      ..add(span(text: '.')),
  ],
);

const String _runInProfileModeDocsUrl =
    'https://flutter.dev/docs/testing/ui-performance#run-in-profile-mode';

final profileGranularityWarning = Message(
  MessageType.warning,
  id: 'highSamplingRateWarning',
  children: [
    div(
        text: 'You are opting in to a high CPU sampling rate. This may affect '
            'the performance of your application.'),
    div()
      ..add(span(text: 'Please read our '))
      ..add(a(
          text: 'documentation',
          href: _profileGranularityDocsUrl,
          target: '_blank;'))
      ..add(span(
          text: ' to understand the trade-offs associated with this setting.'))
  ],
);

const String _profileGranularityDocsUrl =
    'https://flutter.dev/docs/development/tools/devtools/performance#profile-granularity';
