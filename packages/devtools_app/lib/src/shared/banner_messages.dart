// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/performance/performance_utils.dart';
import 'analytics/constants.dart' as gac;
import 'common_widgets.dart';
import 'globals.dart';
import 'primitives/utils.dart';
import 'screen.dart';
import 'theme.dart';
import 'version.dart';

const _runInProfileModeDocsUrl =
    'https://flutter.dev/docs/testing/ui-performance#run-in-profile-mode';

const _cpuSamplingRateDocsUrl =
    'https://flutter.dev/docs/development/tools/devtools/performance#profile-granularity';

class BannerMessagesController {
  final _messages = <String, ListValueNotifier<BannerMessage>>{};
  final _dismissedMessageKeys = <Key?>{};

  void addMessage(BannerMessage message) {
    // We push the banner message in a post frame callback because otherwise,
    // we'd be trying to call setState while the parent widget `BannerMessages`
    // is in the middle of `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isMessageDismissed(message) || isMessageVisible(message)) return;
      final messages = _messagesForScreen(message.screenId);
      messages.add(message);
    });
  }

  void removeMessage(BannerMessage message, {bool dismiss = false}) {
    if (dismiss) {
      _dismissedMessageKeys.add(message.key);
    }
    // We push the banner message in a post frame callback because otherwise,
    // we'd be trying to call setState while the parent widget `BannerMessages`
    // is in the middle of `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messages = _messagesForScreen(message.screenId);
      messages.remove(message);
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

  ListValueNotifier<BannerMessage> _messagesForScreen(String screenId) {
    return _messages.putIfAbsent(
      screenId,
      () => ListValueNotifier<BannerMessage>([]),
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

enum BannerMessageType {
  warning,
  error,
}

@visibleForTesting
class BannerMessage extends StatelessWidget {
  const BannerMessage({
    required super.key,
    required this.textSpans,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.screenId,
    required this.messageType,
  });

  final List<InlineSpan> textSpans;
  final Color backgroundColor;
  final Color foregroundColor;
  final String screenId;
  final BannerMessageType messageType;

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
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        _iconSpanForMessage(),
                        ...textSpans,
                      ],
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

  WidgetSpan _iconSpanForMessage() {
    Widget child;
    switch (messageType) {
      case BannerMessageType.warning:
        child = const _BannerWarningIcon();
        break;
      case BannerMessageType.error:
      default:
        child = const _BannerErrorIcon();
        break;
    }
    return WidgetSpan(
      child: Padding(
        padding: const EdgeInsets.only(right: denseSpacing),
        child: child,
      ),
    );
  }
}

class _BannerWarningIcon extends StatelessWidget {
  const _BannerWarningIcon();

  static const _backdropTopOffset = 6.0;
  static const _backdropWidth = 4.0;
  static const _backdropHeight = 10.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // This positioned container is to make the exclamation point in the
        // warning icon appear black.
        Positioned(
          top: _backdropTopOffset,
          left: denseSpacing,
          child: Container(
            width: _backdropWidth,
            height: _backdropHeight,
            decoration: const BoxDecoration(color: Colors.black),
          ),
        ),
        Icon(
          Icons.warning,
          color: Colors.amber,
          size: actionsIconSize,
        ),
      ],
    );
  }
}

class _BannerErrorIcon extends StatelessWidget {
  const _BannerErrorIcon();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.error_outline,
      color: _BannerError.foreground,
      size: actionsIconSize,
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
          messageType: BannerMessageType.error,
        );

  static const foreground = Colors.white;
  static const linkColor = Color(0xFF54C1EF);
}

// TODO(kenz): add "Do not show this again" option to warnings.
class _BannerWarning extends BannerMessage {
  const _BannerWarning({
    required super.key,
    required super.textSpans,
    required super.screenId,
  }) : super(
          backgroundColor: devtoolsWarning,
          foregroundColor: foreground,
          messageType: BannerMessageType.warning,
        );

  static const foreground = Colors.black87;
  static const linkColor = Color(0xFF54C1EF);
}

class DebugModePerformanceMessage {
  const DebugModePerformanceMessage(this.screenId);

  final String screenId;

  BannerMessage build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.warningMessageTextStyle;
    return _BannerWarning(
      key: Key('DebugModePerformanceMessage - $screenId'),
      textSpans: [
        TextSpan(
          text:
              'You are running your app in debug mode. Debug mode performance '
              'is not indicative of release performance, but you may use debug '
              'mode to gain visibility into the work the system performs (e.g. '
              'building widgets, calculating layouts, rasterizing scenes,'
              ' etc.). For precise measurement of performance, relaunch your '
              'application in ',
          style: textStyle,
        ),
        _runInProfileModeTextSpan(
          context,
          screenId: screenId,
          style: theme.errorMessageLinkStyle,
        ),
        TextSpan(
          text: '.',
          style: textStyle,
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
    final theme = Theme.of(context);
    final textStyle = theme.errorMessageTextStyle;
    return _BannerError(
      key: Key('ShaderJankMessage - $screenId'),
      textSpans: [
        TextSpan(
          text: '''
Shader compilation jank detected. $jankyFramesCount ${pluralize('frame', jankyFramesCount)} janked with a total of ${msText(jankDuration)} spent in shader compilation.

To pre-compile shaders, see the instructions at ''',
          style: textStyle,
        ),
        LinkTextSpan(
          link: Link(
            display: preCompileShadersDocsUrl,
            url: preCompileShadersDocsUrl,
            gaScreenName: screenId,
            gaSelectedItemDescription: gac.shaderCompilationDocs,
          ),
          context: context,
          style: theme.errorMessageLinkStyle,
        ),
        TextSpan(
          text: '.',
          style: textStyle,
        ),
      ],
      screenId: screenId,
    );
  }
}

class HighCpuSamplingRateMessage {
  HighCpuSamplingRateMessage(this.screenId)
      : key = Key('HighCpuSamplingRateMessage - $screenId');

  final Key key;

  final String screenId;

  BannerMessage build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.warningMessageTextStyle;
    return _BannerWarning(
      key: key,
      textSpans: [
        TextSpan(
          text: '''
You are opting in to a high CPU sampling rate. This may affect the performance of your application. Please read our ''',
          style: textStyle,
        ),
        LinkTextSpan(
          link: Link(
            display: 'documentation',
            url: _cpuSamplingRateDocsUrl,
            gaScreenName: screenId,
            gaSelectedItemDescription: gac.cpuSamplingRateDocs,
          ),
          context: context,
          style: theme.warningMessageLinkStyle,
        ),
        TextSpan(
          text: ' to understand the trade-offs associated with this setting.',
          style: textStyle,
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
    final theme = Theme.of(context);
    final textStyle = theme.warningMessageTextStyle;
    return _BannerWarning(
      key: Key('DebugModeMemoryMessage - $screenId'),
      textSpans: [
        TextSpan(
          text: '''
You are running your app in debug mode. Absolute memory usage may be higher in a debug build than in a release build.
For the most accurate absolute memory stats, relaunch your application in ''',
          style: textStyle,
        ),
        _runInProfileModeTextSpan(
          context,
          screenId: screenId,
          style: Theme.of(context).warningMessageLinkStyle,
        ),
        TextSpan(
          text: '.',
          style: textStyle,
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
      DebugModePerformanceMessage(screenId).build(context),
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
  TextStyle get warningMessageTextStyle => TextStyle(
        color: _BannerWarning.foreground,
        fontSize: defaultFontSize,
      );

  TextStyle get warningMessageLinkStyle => TextStyle(
        decoration: TextDecoration.underline,
        color: _BannerWarning.linkColor,
        fontSize: defaultFontSize,
      );

  TextStyle get errorMessageTextStyle => TextStyle(
        color: _BannerError.foreground,
        fontSize: defaultFontSize,
      );

  TextStyle get errorMessageLinkStyle => TextStyle(
        decoration: TextDecoration.underline,
        color: _BannerError.linkColor,
        fontSize: defaultFontSize,
      );
}

LinkTextSpan _runInProfileModeTextSpan(
  BuildContext context, {
  required String screenId,
  required TextStyle style,
}) {
  return LinkTextSpan(
    link: Link(
      display: 'profile mode',
      url: _runInProfileModeDocsUrl,
      gaScreenName: screenId,
      gaSelectedItemDescription: gac.profileModeDocs,
    ),
    context: context,
    style: style,
  );
}
