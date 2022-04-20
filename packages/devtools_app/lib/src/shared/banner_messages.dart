// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../primitives/utils.dart';
import 'common_widgets.dart';
import 'globals.dart';
import 'screen.dart';
import 'theme.dart';
import 'version.dart';

const _runInProfileModeDocsUrl =
    'https://flutter.dev/docs/testing/ui-performance#run-in-profile-mode';

const _profileGranularityDocsUrl =
    'https://flutter.dev/docs/development/tools/devtools/performance#profile-granularity';

const preCompileShadersDocsUrl =
    'https://flutter.dev/docs/perf/rendering/shader#how-to-use-sksl-warmup';

class BannerMessagesController {
  final _messages = <String, ValueNotifier<List<BannerMessage>>>{};
  final _dismissedMessageKeys = <Key?>{};

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
    final messageWithKey = currentMessages.value.firstWhereOrNull(
      (m) => m.key == key,
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
      screenId,
      () => ValueNotifier<List<BannerMessage>>([]),
    );
  }

  ValueListenable<List<BannerMessage>> messagesForScreen(String screenId) {
    return _messagesForScreen(screenId);
  }
}

class BannerMessages extends StatelessWidget {
  const BannerMessages({Key? key, required this.screen}) : super(key: key);

  final Screen screen;

  // TODO(kenz): use an AnimatedList for message changes.
  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<BannerMessagesController>(context);
    final messagesForScreen = controller.messagesForScreen(screen.screenId);
    return Column(
      children: [
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
    required Key key,
    required this.textSpans,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.screenId,
    required this.headerText,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerText,
                  style: Theme.of(context)
                      .textTheme
                      .bodyText1!
                      .copyWith(color: foregroundColor),
                ),
                const SizedBox(width: defaultSpacing),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: textSpans,
                    ),
                  ),
                ),
                const SizedBox(width: defaultSpacing),
                CircularIconButton(
                  icon: Icons.close,
                  backgroundColor: backgroundColor,
                  foregroundColor: foregroundColor,
                  // TODO(kenz): animate the removal of this message.
                  onPressed: () => Provider.of<BannerMessagesController>(
                    context,
                    listen: false,
                  ).removeMessage(this, dismiss: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerError extends BannerMessage {
  const _BannerError({
    required Key key,
    required List<TextSpan> textSpans,
    required String screenId,
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
    required Key key,
    required List<TextSpan> textSpans,
    required String screenId,
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
        TextSpan(
          text: '''
You are running your app in debug mode. Debug mode performance is not indicative of release performance.
Relaunch your application with the '--profile' argument, or ''',
          style: TextStyle(
            color: _BannerError.foreground,
            fontSize: defaultFontSize,
          ),
        ),
        LinkTextSpan(
          link: const Link(
            display: 'relaunch in profile mode from VS Code or IntelliJ',
            url: _runInProfileModeDocsUrl,
          ),
          context: context,
          style: Theme.of(context).errorMessageLinkStyle,
        ),
        TextSpan(
          text: '.',
          style: TextStyle(
            color: _BannerError.foreground,
            fontSize: defaultFontSize,
          ),
        ),
      ],
      screenId: screenId,
    );
  }
}

class ProviderUnknownErrorBanner {
  const ProviderUnknownErrorBanner({required this.screenId});

  final String screenId;

  BannerMessage build(BuildContext context) {
    return _BannerError(
      key: Key('ProviderUnknownErrorBanner - $screenId'),
      screenId: screenId,
      textSpans: [
        TextSpan(
          text: '''
DevTools failed to connect with package:provider.

This could be caused by an older version of package:provider; please make sure that you are using version >=5.0.0.''',
          style: TextStyle(
            color: _BannerError.foreground,
            fontSize: defaultFontSize,
          ),
        ),
      ],
    );
  }
}

class ShaderJankMessage {
  const ShaderJankMessage(
    this.screenId, {
    required this.jankyFramesCount,
    required this.jankDuration,
  });

  final String screenId;

  final int jankyFramesCount;

  final Duration jankDuration;

  BannerMessage build(BuildContext context) {
    return _BannerError(
      key: Key('ShaderJankMessage - $screenId'),
      textSpans: [
        TextSpan(
          text: '''
Shader compilation jank detected. $jankyFramesCount ${pluralize('frame', jankyFramesCount)} janked with a total of ${msText(jankDuration)} spent in shader compilation.

To pre-compile shaders, see the instructions at ''',
          style: TextStyle(
            color: _BannerError.foreground,
            fontSize: defaultFontSize,
          ),
        ),
        LinkTextSpan(
          link: const Link(
            display: preCompileShadersDocsUrl,
            url: preCompileShadersDocsUrl,
          ),
          context: context,
          style: Theme.of(context).errorMessageLinkStyle,
        ),
        TextSpan(
          text: '.',
          style: TextStyle(
            color: _BannerError.foreground,
            fontSize: defaultFontSize,
          ),
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

  BannerMessage build(BuildContext context) {
    return _BannerWarning(
      key: key,
      textSpans: [
        TextSpan(
          text: '''
You are opting in to a high CPU sampling rate. This may affect the performance of your application. Please read our ''',
          style: TextStyle(
            color: _BannerWarning.foreground,
            fontSize: defaultFontSize,
          ),
        ),
        LinkTextSpan(
          link: const Link(
            display: 'documentation',
            url: _profileGranularityDocsUrl,
          ),
          context: context,
          style: Theme.of(context).warningMessageLinkStyle,
        ),
        TextSpan(
          text: ' to understand the trade-offs associated with this setting.',
          style: TextStyle(
            color: _BannerWarning.foreground,
            fontSize: defaultFontSize,
          ),
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
        TextSpan(
          text: '''
You are running your app in debug mode. Absolute memory usage may be higher in a debug build than in a release build.
For the most accurate absolute memory stats, relaunch your application with the '--profile' argument, or ''',
          style: TextStyle(
            color: _BannerWarning.foreground,
            fontSize: defaultFontSize,
          ),
        ),
        LinkTextSpan(
          link: const Link(
            display: 'relaunch in profile mode from VS Code or IntelliJ',
            url: _runInProfileModeDocsUrl,
          ),
          context: context,
          style: Theme.of(context).warningMessageLinkStyle,
        ),
        TextSpan(
          text: '.',
          style: TextStyle(
            color: _BannerWarning.foreground,
            fontSize: defaultFontSize,
          ),
        ),
      ],
      screenId: screenId,
    );
  }
}

class UnsupportedFlutterVersionWarning {
  const UnsupportedFlutterVersionWarning({
    required this.screenId,
    required this.currentFlutterVersion,
    required this.supportedFlutterVersion,
  });

  final String screenId;

  final FlutterVersion currentFlutterVersion;

  final SemanticVersion supportedFlutterVersion;

  BannerMessage build(BuildContext context) {
    return _BannerWarning(
      key: Key('UnsupportedFlutterVersionWarning - $screenId'),
      textSpans: [
        TextSpan(
          text: 'This version of DevTools expects the connected app to be run'
              ' on Flutter >= $supportedFlutterVersion, but the connected app'
              ' is running on Flutter $currentFlutterVersion. Some'
              ' functionality may not work. If this causes issues, try'
              ' upgrading your Flutter version.',
          style: TextStyle(
            color: _BannerWarning.foreground,
            fontSize: defaultFontSize,
          ),
        ),
      ],
      screenId: screenId,
    );
  }
}

void maybePushUnsupportedFlutterVersionWarning(
  BuildContext context,
  String screenId, {
  required SemanticVersion supportedFlutterVersion,
}) {
  final isFlutterApp = serviceManager.connectedApp?.isFlutterAppNow;
  if (offlineController.offlineMode.value ||
      isFlutterApp == null ||
      !isFlutterApp) {
    return;
  }
  final currentVersion = serviceManager.connectedApp!.flutterVersionNow!;
  if (currentVersion < supportedFlutterVersion) {
    Provider.of<BannerMessagesController>(context).addMessage(
      UnsupportedFlutterVersionWarning(
        screenId: screenId,
        currentFlutterVersion: currentVersion,
        supportedFlutterVersion: supportedFlutterVersion,
      ).build(context),
    );
  }
}

void maybePushDebugModePerformanceMessage(
  BuildContext context,
  String screenId,
) {
  if (offlineController.offlineMode.value) return;
  if (serviceManager.connectedApp?.isDebugFlutterAppNow ?? false) {
    Provider.of<BannerMessagesController>(context).addMessage(
      DebugModePerformanceMessage(screenId).build(context) as BannerMessage,
    );
  }
}

void maybePushDebugModeMemoryMessage(
  BuildContext context,
  String screenId,
) {
  if (offlineController.offlineMode.value) return;
  if (serviceManager.connectedApp?.isDebugFlutterAppNow ?? false) {
    Provider.of<BannerMessagesController>(context)
        .addMessage(DebugModeMemoryMessage(screenId).build(context));
  }
}

extension BannerMessageThemeExtension on ThemeData {
  TextStyle get warningMessageLinkStyle => TextStyle(
        decoration: TextDecoration.underline,
        color: _BannerWarning.linkColor,
        fontSize: defaultFontSize,
      );

  TextStyle get errorMessageLinkStyle => TextStyle(
        decoration: TextDecoration.underline,
        color: _BannerError.linkColor,
        fontSize: defaultFontSize,
      );
}
