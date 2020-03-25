// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../auto_dispose.dart';
import 'auto_dispose_mixin.dart';
import 'common_widgets.dart';
import 'controllers.dart';
import 'screen.dart';
import 'theme.dart';
import 'utils.dart';

const _runInProfileModeDocsUrl =
    'https://flutter.dev/docs/testing/ui-performance#run-in-profile-mode';

const _profileGranularityDocsUrl =
    'https://flutter.dev/docs/development/tools/devtools/performance#profile-granularity';

class BannerMessagesController implements DisposableController {
  final _dismissedMessageIds = <String>{};

  final _refreshMessagesController = StreamController<Null>.broadcast();

  Stream<Null> get onRefreshMessages => _refreshMessagesController.stream;

  @override
  void dispose() {
    _refreshMessagesController.close();
  }

  void refreshMessages() {
    _refreshMessagesController.add(null);
  }

  void dismissMessage(String messageId) {
    assert(!isMessageDismissed(messageId));
    _dismissedMessageIds.add(messageId);
    refreshMessages();
  }

  bool isMessageDismissed(String messageId) {
    return _dismissedMessageIds.contains(messageId);
  }
}

class BannerMessageContainer extends StatefulWidget {
  const BannerMessageContainer({Key key, @required this.screen})
      : super(key: key);

  final Screen screen;

  @override
  _BannerMessageContainerState createState() => _BannerMessageContainerState();
}

class _BannerMessageContainerState extends State<BannerMessageContainer>
    with AutoDisposeMixin {
  BannerMessagesController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Controllers.of(context)?.bannerMessages;
    if (newController == controller) return;
    controller = newController;

    autoDispose(controller.onRefreshMessages.listen((_) => setState(() {})));
  }

  @override
  Widget build(BuildContext context) {
    final messagesForScreen = widget.screen.messages(context);
    if (messagesForScreen.isNotEmpty) {
      final messagesToShow = <Widget>[];
      for (Widget message in messagesForScreen) {
        assert(message is UniqueMessage);
        if (!controller.isMessageDismissed((message as UniqueMessage).id)) {
          messagesToShow.add(message);
        }
      }
      if (messagesToShow.isNotEmpty) {
        return Column(
          children: messagesToShow,
        );
      }
    }
    return const SizedBox();
  }
}

class BannerMessage extends StatelessWidget implements UniqueMessage {
  const BannerMessage({
    @required this.messageId,
    @required this.textSpans,
    @required this.backgroundColor,
    @required this.foregroundColor,
  });

  final String messageId;
  final List<TextSpan> textSpans;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  String get id => messageId;

  @override
  Widget build(BuildContext context) {
    final bannerMessagesController = Controllers.of(context).bannerMessages;
    return Card(
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(defaultSpacing),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Container(
                child: RichText(
                  text: TextSpan(
                    children: textSpans,
                  ),
                ),
              ),
            ),
            SizedBox(width: denseSpacing),
            CircularIconButton(
              icon: Icons.close,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              // TODO(kenz): animate the removal of this message.
              onPressed: () => bannerMessagesController.dismissMessage(id),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerError extends BannerMessage {
  const _BannerError({
    @required String id,
    @required List<TextSpan> textSpans,
    @required DevToolsScreenType screenType,
  }) : super(
          messageId: id,
          textSpans: textSpans,
          backgroundColor: devtoolsError,
          foregroundColor: foreground,
        );

  static const foreground = Colors.white;
  static const linkColor = Color(0xFF88D7FC);
}

// TODO(kenz): add "Do not show this again" option to warnings.
class _BannerWarning extends BannerMessage {
  const _BannerWarning({
    @required String id,
    @required List<TextSpan> textSpans,
    @required DevToolsScreenType screenType,
  }) : super(
          messageId: id,
          textSpans: textSpans,
          backgroundColor: devtoolsWarning,
          foregroundColor: foreground,
        );

  static const foreground = Colors.black87;
  static const linkColor = Color(0xFF055BF0);
}

class DebugModePerformanceMessage extends StatelessWidget
    implements UniqueMessage {
  const DebugModePerformanceMessage(this.screenType);

  final DevToolsScreenType screenType;

  @override
  String get id => 'DebugModePerformanceMessage - $screenType';

  @override
  Widget build(BuildContext context) {
    return _BannerError(
      id: id,
      textSpans: [
        const TextSpan(
          text:
              'You are running your app in debug mode. Debug mode performance '
              'is not indicative of release performance.\n\nRelaunch your '
              'application with the \'--profile\' argument, or ',
          style: TextStyle(color: _BannerError.foreground),
        ),
        TextSpan(
          text: 'relaunch in profile mode from VS Code or IntelliJ',
          style: TextStyle(
            decoration: TextDecoration.underline,
            color: _BannerError.linkColor,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await launchUrl(_runInProfileModeDocsUrl, context);
            },
        ),
        const TextSpan(
          text: '.',
          style: TextStyle(color: _BannerError.foreground),
        ),
      ],
      screenType: screenType,
    );
  }
}

class HighProfileGranularityMessage extends StatelessWidget
    implements UniqueMessage {
  const HighProfileGranularityMessage(this.screenType);

  final DevToolsScreenType screenType;

  @override
  String get id => 'HighProfileGranularityMessage - $screenType';

  @override
  Widget build(BuildContext context) {
    return _BannerWarning(
      id: id,
      textSpans: [
        const TextSpan(
          text:
              'You are opting in to a high CPU sampling rate. This may affect '
              'the performance of your application. Please read our ',
          style: TextStyle(color: _BannerWarning.foreground),
        ),
        TextSpan(
          text: 'documentation',
          style: TextStyle(
            decoration: TextDecoration.underline,
            color: _BannerWarning.linkColor,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await launchUrl(_profileGranularityDocsUrl, context);
            },
        ),
        const TextSpan(
          text: ' to understand the trade-offs associated with this setting.',
          style: TextStyle(color: _BannerWarning.foreground),
        ),
      ],
      screenType: screenType,
    );
  }
}

class DebugModeMemoryMessage extends StatelessWidget implements UniqueMessage {
  const DebugModeMemoryMessage(this.screenType);

  final DevToolsScreenType screenType;

  @override
  String get id => 'DebugModeMemoryMessage - $screenType';

  @override
  Widget build(BuildContext context) {
    return _BannerWarning(
      id: id,
      textSpans: [
        const TextSpan(
          text: 'You are running your app in debug mode. Absolute memory usage '
              'may be higher in a debug build than in a release build.\n\n'
              'For the most accurate absolute memory stats, relaunch your '
              'application with the \'--profile\' argument, or ',
          style: TextStyle(color: _BannerWarning.foreground),
        ),
        TextSpan(
          text: 'relaunch in profile mode from VS Code or IntelliJ',
          style: TextStyle(
            decoration: TextDecoration.underline,
            color: _BannerWarning.linkColor,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await launchUrl(_runInProfileModeDocsUrl, context);
            },
        ),
        const TextSpan(
          text: '.',
          style: TextStyle(color: _BannerWarning.foreground),
        ),
      ],
      screenType: screenType,
    );
  }
}

abstract class UniqueMessage {
  String get id;
}
