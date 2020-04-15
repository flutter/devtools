// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../globals.dart';
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

class BannerMessagesController {
  final _messages = <DevToolsScreenType, ValueNotifier<List<BannerMessage>>>{};
  final _dismissedMessageKeys = <Key>{};

  void addMessage(BannerMessage message) {
    if (isMessageDismissed(message) || isMessageVisible(message)) return;
    final messages = _messagesForScreen(message.screenType);
    messages.value.add(message);
    // TODO(kenz): we should make a ListValueNotifier class that handles
    // notifying listeners so we don't have to make an illegal call to a
    // protected method.
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    messages.notifyListeners();
  }

  void removeMessage(BannerMessage message, {bool dismiss = false}) {
    if (dismiss) {
      assert(!_dismissedMessageKeys.contains(message.key));
      _dismissedMessageKeys.add(message.key);
    }
    final messages = _messagesForScreen(message.screenType);
    messages.value.remove(message);
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    messages.notifyListeners();
  }

  void removeMessageByKey(Key key, DevToolsScreenType screenType) {
    final currentMessages = _messagesForScreen(screenType);
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
    return _messagesForScreen(message.screenType)
        .value
        .where((m) => m.key == message.key)
        .isNotEmpty;
  }

  ValueNotifier<List<BannerMessage>> _messagesForScreen(
    DevToolsScreenType screenType,
  ) {
    return _messages.putIfAbsent(
        screenType, () => ValueNotifier<List<BannerMessage>>([]));
  }

  ValueListenable<List<BannerMessage>> messagesForScreen(
    DevToolsScreenType screenType,
  ) {
    return _messagesForScreen(screenType);
  }
}

class BannerMessages extends StatelessWidget {
  const BannerMessages({Key key, @required this.screen}) : super(key: key);

  final Screen screen;

  @override
  Widget build(BuildContext context) {
    return _BannerMessagesProvider(screen: screen);
  }

  static BannerMessagesState of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_InheritedBannerMessages>();
    return provider?.data;
  }
}

class _BannerMessagesProvider extends StatefulWidget {
  const _BannerMessagesProvider({Key key, this.screen}) : super(key: key);

  final Screen screen;

  @override
  BannerMessagesState createState() => BannerMessagesState();
}

class _InheritedBannerMessages extends InheritedWidget {
  const _InheritedBannerMessages({this.data, Widget child})
      : super(child: child);

  final BannerMessagesState data;

  @override
  bool updateShouldNotify(_InheritedBannerMessages oldWidget) {
    return oldWidget.data != data;
  }
}

class BannerMessagesState extends State<_BannerMessagesProvider>
    with AutoDisposeMixin {
  BannerMessagesController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = Controllers.of(context)?.bannerMessages;
    if (newController == controller) return;
    controller = newController;
  }

  void push(BannerMessage message) {
    // We push the banner message in a post frame callback because otherwise,
    // we'd be trying to call setState while the parent widget `BannerMessages`
    // is in the middle of `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.addMessage(message);
    });
  }

  void remove(BannerMessage message, {bool dismiss = false}) {
    // We push the banner message in a post frame callback because otherwise,
    // we'd be trying to call setState while the parent widget `BannerMessages`
    // is in the middle of `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      controller.removeMessage(message, dismiss: dismiss);
    });
  }

  void removeMessageByKey(Key key, DevToolsScreenType screenType) {
    // We push the banner message in a post frame callback because otherwise,
    // we'd be trying to call setState while the parent widget `BannerMessages`
    // is in the middle of `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.removeMessageByKey(key, screenType);
    });
  }

  // TODO(kenz): use an AnimatedList for message changes.
  @override
  Widget build(BuildContext context) {
    final messagesForScreen = controller?.messagesForScreen(widget.screen.type);
    return _InheritedBannerMessages(
      data: this,
      child: Column(
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
            child: widget.screen.build(context),
          )
        ],
      ),
    );
  }
}

class BannerMessage extends StatelessWidget {
  const BannerMessage({
    @required Key key,
    @required this.textSpans,
    @required this.backgroundColor,
    @required this.foregroundColor,
    @required this.screenType,
  }) : super(key: key);

  final List<TextSpan> textSpans;
  final Color backgroundColor;
  final Color foregroundColor;
  final DevToolsScreenType screenType;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor,
      margin: const EdgeInsets.only(bottom: denseRowSpacing),
      child: Padding(
        padding: const EdgeInsets.all(defaultSpacing),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: textSpans,
                ),
              ),
            ),
            const SizedBox(width: denseSpacing),
            CircularIconButton(
              icon: Icons.close,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              // TODO(kenz): animate the removal of this message.
              onPressed: () =>
                  BannerMessages.of(context).remove(this, dismiss: true),
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
    @required DevToolsScreenType screenType,
  }) : super(
          key: key,
          textSpans: textSpans,
          backgroundColor: devtoolsError,
          foregroundColor: foreground,
          screenType: screenType,
        );

  static const foreground = Colors.white;
  static const linkColor = Color(0xFF54C1EF);
}

// TODO(kenz): add "Do not show this again" option to warnings.
class _BannerWarning extends BannerMessage {
  const _BannerWarning({
    @required Key key,
    @required List<TextSpan> textSpans,
    @required DevToolsScreenType screenType,
  }) : super(
          key: key,
          textSpans: textSpans,
          backgroundColor: devtoolsWarning,
          foregroundColor: foreground,
          screenType: screenType,
        );

  static const foreground = Colors.black87;
  static const linkColor = Color(0xFF54C1EF);
}

class DebugModePerformanceMessage {
  const DebugModePerformanceMessage(this.screenType);

  final DevToolsScreenType screenType;

  Widget build(BuildContext context) {
    return _BannerError(
      key: Key('DebugModePerformanceMessage - $screenType'),
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
      screenType: screenType,
    );
  }
}

class HighProfileGranularityMessage {
  HighProfileGranularityMessage(this.screenType)
      : key = Key('HighProfileGranularityMessage - $screenType');

  final Key key;

  final DevToolsScreenType screenType;

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
      screenType: screenType,
    );
  }
}

class DebugModeMemoryMessage {
  const DebugModeMemoryMessage(this.screenType);

  final DevToolsScreenType screenType;

  BannerMessage build(BuildContext context) {
    return _BannerWarning(
      key: Key('DebugModeMemoryMessage - $screenType'),
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
      screenType: screenType,
    );
  }
}

void maybePushDebugModePerformanceMessage(
  BuildContext context,
  DevToolsScreenType screenType,
) {
  if (serviceManager.connectedApp.isDebugFlutterAppNow) {
    BannerMessages.of(context)
        .push(DebugModePerformanceMessage(screenType).build(context));
  }
}

void maybePushDebugModeMemoryMessage(
  BuildContext context,
  DevToolsScreenType screenType,
) {
  if (serviceManager.connectedApp.isDebugFlutterAppNow) {
    BannerMessages.of(context)
        .push(DebugModeMemoryMessage(screenType).build(context));
  }
}
