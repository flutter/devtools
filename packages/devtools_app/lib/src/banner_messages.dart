// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'common_widgets.dart';
import 'globals.dart';
import 'screen.dart';
import 'theme.dart';
import 'utils.dart';

const _runInProfileModeDocsUrl =
    'https://flutter.dev/docs/testing/ui-performance#run-in-profile-mode';

const _profileGranularityDocsUrl =
    'https://flutter.dev/docs/development/tools/devtools/performance#profile-granularity';

class BannerMessagesController {
  final _messages = <String, ValueNotifier<List<BannerMessage>>>{};
  final _dismissedMessageKeys = <Key>{};

  void addMessage(BannerMessage message) {
    // We push the banner message in a post frame callback because otherwise,
    // we'd be trying to call setState while the parent widget `BannerMessages`
    // is in the middle of `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMessageDismissed(message) || isMessageVisible(message)) return;
      final messages = _messagesForScreen(message.screenId);
      messages.value.add(message);
      // TODO(kenz): we should make a ListValueNotifier class that handles
      // notifying listeners so we don't have to make an illegal call to a
      // protected method.
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      messages.notifyListeners();
    });
  }

  void removeMessage(BannerMessage message, {bool dismiss = false}) {
    // We push the banner message in a post frame callback because otherwise,
    // we'd be trying to call setState while the parent widget `BannerMessages`
    // is in the middle of `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (dismiss) {
        assert(!_dismissedMessageKeys.contains(message.key));
        _dismissedMessageKeys.add(message.key);
      }
      final messages = _messagesForScreen(message.screenId);
      messages.value.remove(message);
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      messages.notifyListeners();
    });
  }

  void removeMessageByKey(Key key, String screenId) {
    final currentMessages = _messagesForScreen(screenId);
    final messageWithKey = currentMessages.value.firstWhere(
      (m) => m.key == key,
      orElse: () => null,
    );
    if (messageWithKey != null) {
      removeMessage(messageWithKey);
    }
  }

  @visibleForTesting
  bool isMessageDismissed(BannerMessage message) {
    return _dismissedMessageKeys.contains(message.key);
  }

  @visibleForTesting
  bool isMessageVisible(BannerMessage message) {
    return _messagesForScreen(message.screenId)
        .value
        .where((m) => m.key == message.key)
        .isNotEmpty;
  }

  ValueNotifier<List<BannerMessage>> _messagesForScreen(String screenId) {
    return _messages.putIfAbsent(
        screenId, () => ValueNotifier<List<BannerMessage>>([]));
  }

  ValueListenable<List<BannerMessage>> messagesForScreen(String screenId) {
    return _messagesForScreen(screenId);
  }
}

class BannerMessages extends StatelessWidget {
  const BannerMessages({Key key, @required this.screen}) : super(key: key);

  final Screen screen;

  // TODO(kenz): use an AnimatedList for message changes.
  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<BannerMessagesController>(context);
    final messagesForScreen = controller?.messagesForScreen(screen.screenId);
    return Column(
      children: [
        if (messagesForScreen != null)
          ValueListenableBuilder<List<BannerMessage>>(
            valueListenable: messagesForScreen,
            builder: (context, messages, _) {
              return Column(
                children: messages,
              );
            },
          ),
        Expanded(
          child: screen.build(context),
        )
      ],
    );
  }
}

class BannerMessage extends StatelessWidget {
  const BannerMessage({
    @required Key key,
    @required this.textSpans,
    @required this.backgroundColor,
    @required this.foregroundColor,
    @required this.screenId,
    @required this.headerText,
  }) : super(key: key);

  final List<TextSpan> textSpans;
  final Color backgroundColor;
  final Color foregroundColor;
  final String screenId;
  final String headerText;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      margin: const EdgeInsets.only(bottom: denseRowSpacing),
      child: Padding(
        padding: const EdgeInsets.all(defaultSpacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  headerText,
                  style: Theme.of(context)
                      .textTheme
                      .headline6
                      .copyWith(color: foregroundColor),
                ),
                CircularIconButton(
                  icon: Icons.close,
                  backgroundColor: backgroundColor,
                  foregroundColor: foregroundColor,
                  // TODO(kenz): animate the removal of this message.
                  onPressed: () => Provider.of<BannerMessagesController>(
                          context,
                          listen: false)
                      .removeMessage(this, dismiss: true),
                ),
              ],
            ),
            const SizedBox(height: defaultSpacing),
            RichText(
              text: TextSpan(
                children: textSpans,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerError extends BannerMessage {
  const _BannerError({
    @required Key key,
    @required List<TextSpan> textSpans,
    @required String screenId,
  }) : super(
          key: key,
          textSpans: textSpans,
          backgroundColor: devtoolsError,
          foregroundColor: foreground,
          screenId: screenId,
          headerText: 'ERROR',
        );

  static const foreground = Colors.white;
  static const linkColor = Color(0xFF54C1EF);
}

// TODO(kenz): add "Do not show this again" option to warnings.
class _BannerWarning extends BannerMessage {
  const _BannerWarning({
    @required Key key,
    @required List<TextSpan> textSpans,
    @required String screenId,
  }) : super(
          key: key,
          textSpans: textSpans,
          backgroundColor: devtoolsWarning,
          foregroundColor: foreground,
          screenId: screenId,
          headerText: 'WARNING',
        );

  static const foreground = Colors.black87;
  static const linkColor = Color(0xFF54C1EF);
}

class DebugModePerformanceMessage {
  const DebugModePerformanceMessage(this.screenId);

  final String screenId;

  Widget build(BuildContext context) {
    return _BannerError(
      key: Key('DebugModePerformanceMessage - $screenId'),
      textSpans: [
        const TextSpan(
          text: '''
You are running your app in debug mode. Debug mode performance is not indicative of release performance.

Relaunch your application with the '--profile' argument, or ''',
          style: TextStyle(color: _BannerError.foreground),
        ),
        TextSpan(
          text: 'relaunch in profile mode from VS Code or IntelliJ',
          style: const TextStyle(
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
      screenId: screenId,
    );
  }
}

class HighProfileGranularityMessage {
  HighProfileGranularityMessage(this.screenId)
      : key = Key('HighProfileGranularityMessage - $screenId');

  final Key key;

  final String screenId;

  Widget build(BuildContext context) {
    return _BannerWarning(
      key: key,
      textSpans: [
        const TextSpan(
          text: '''
You are opting in to a high CPU sampling rate. This may affect the performance of your application. Please read our ''',
          style: TextStyle(color: _BannerWarning.foreground),
        ),
        TextSpan(
          text: 'documentation',
          style: const TextStyle(
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
      screenId: screenId,
    );
  }
}

class DebugModeMemoryMessage {
  const DebugModeMemoryMessage(this.screenId);

  final String screenId;

  BannerMessage build(BuildContext context) {
    return _BannerWarning(
      key: Key('DebugModeMemoryMessage - $screenId'),
      textSpans: [
        const TextSpan(
          text: '''
You are running your app in debug mode. Absolute memory usage may be higher in a debug build than in a release build.

For the most accurate absolute memory stats, relaunch your application with the '--profile' argument, or ''',
          style: TextStyle(color: _BannerWarning.foreground),
        ),
        TextSpan(
          text: 'relaunch in profile mode from VS Code or IntelliJ',
          style: const TextStyle(
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
      screenId: screenId,
    );
  }
}

void maybePushDebugModePerformanceMessage(
  BuildContext context,
  String screenId,
) {
  if (offlineMode) return;
  if (serviceManager.connectedApp?.isDebugFlutterAppNow ?? false) {
    Provider.of<BannerMessagesController>(context)
        .addMessage(DebugModePerformanceMessage(screenId).build(context));
  }
}

void maybePushDebugModeMemoryMessage(
  BuildContext context,
  String screenId,
) {
  if (offlineMode) return;
  if (serviceManager.connectedApp?.isDebugFlutterAppNow ?? false) {
    Provider.of<BannerMessagesController>(context)
        .addMessage(DebugModeMemoryMessage(screenId).build(context));
  }
}
