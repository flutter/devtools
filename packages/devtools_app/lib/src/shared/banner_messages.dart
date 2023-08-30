// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../screens/performance/performance_utils.dart';
import 'analytics/constants.dart' as gac;
import 'common_widgets.dart';
import 'connected_app.dart';
import 'globals.dart';
import 'http/http_service.dart' as http_service;
import 'primitives/utils.dart';
import 'screen.dart';

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
    final messagesForScreen = bannerMessages.messagesForScreen(screen.screenId);
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
        ),
      ],
    );
  }
}

// TODO(kenz): add an 'info' type.
enum BannerMessageType {
  warning,
  error;

  static BannerMessageType? parse(String? value) {
    for (final type in BannerMessageType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

@visibleForTesting
class BannerMessage extends StatelessWidget {
  const BannerMessage({
    required super.key,
    required this.textSpans,
    required this.screenId,
    required this.messageType,
  });

  final List<InlineSpan> textSpans;
  final String screenId;
  final BannerMessageType messageType;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: messageType == BannerMessageType.error
          ? colorScheme.errorContainer
          : colorScheme.warningContainer,
      margin: const EdgeInsets.only(bottom: intermediateSpacing),
      child: Padding(
        padding: const EdgeInsets.all(defaultSpacing),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Icon(
                    messageType == BannerMessageType.error
                        ? Icons.error_outline
                        : Icons.warning_amber_outlined,
                    color: messageType == BannerMessageType.error
                        ? colorScheme.onErrorContainer
                        : colorScheme.onWarningContainer,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: messageType == BannerMessageType.error
                            ? colorScheme.onErrorContainer
                            : colorScheme.onWarningContainer,
                      ),
                      children: textSpans,
                    ),
                  ),
                ),
                const SizedBox(width: defaultSpacing),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: messageType == BannerMessageType.error
                        ? colorScheme.onErrorContainer
                        : colorScheme.onWarningContainer,
                  ),
                  onPressed: () =>
                      bannerMessages.removeMessage(this, dismiss: true),
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
          screenId: screenId,
          messageType: BannerMessageType.error,
        );
}

// TODO(kenz): add "Do not show this again" option to warnings.
class BannerWarning extends BannerMessage {
  const BannerWarning({
    required super.key,
    required super.textSpans,
    required super.screenId,
  }) : super(messageType: BannerMessageType.warning);
}

class DebugModePerformanceMessage {
  const DebugModePerformanceMessage(this.screenId);

  final String screenId;

  BannerMessage build(BuildContext context) {
    final theme = Theme.of(context);
    return BannerWarning(
      key: Key('DebugModePerformanceMessage - $screenId'),
      textSpans: [
        const TextSpan(
          text:
              'You are running your app in debug mode. Debug mode performance '
              'is not indicative of release performance, but you may use debug '
              'mode to gain visibility into the work the system performs (e.g. '
              'building widgets, calculating layouts, rasterizing scenes,'
              ' etc.). For precise measurement of performance, relaunch your '
              'application in ',
        ),
        _runInProfileModeTextSpan(
          context,
          screenId: screenId,
          style: theme.warningMessageLinkStyle,
        ),
        const TextSpan(
          text: '.',
        ),
      ],
      screenId: screenId,
    );
  }
}

// TODO(jacobr): cleanup this class that looks like a Widget but can't quite be
// a widget due to some questionable design choices involving BannerMessage.
class ProviderUnknownErrorBanner {
  const ProviderUnknownErrorBanner({required this.screenId});

  final String screenId;

  BannerMessage build() {
    return _BannerError(
      key: Key('ProviderUnknownErrorBanner - $screenId'),
      screenId: screenId,
      textSpans: [
        TextSpan(
          text: '''
DevTools failed to connect with package:provider.

This could be caused by an older version of package:provider; please make sure that you are using version >=5.0.0.''',
          style: TextStyle(fontSize: defaultFontSize),
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
    final jankDurationText = durationText(
      jankDuration,
      unit: DurationDisplayUnit.milliseconds,
    );
    return _BannerError(
      key: Key('ShaderJankMessage - $screenId'),
      textSpans: [
        TextSpan(
          text: 'Shader compilation jank detected. $jankyFramesCount '
              '${pluralize('frame', jankyFramesCount)} janked with a total of '
              '$jankDurationText spent in shader compilation. To pre-compile '
              'shaders, see the instructions at ',
        ),
        LinkTextSpan(
          link: Link(
            display: preCompileShadersDocsUrl,
            url: preCompileShadersDocsUrl,
            gaScreenName: screenId,
            gaSelectedItemDescription:
                gac.PerformanceDocs.shaderCompilationDocs.name,
          ),
          context: context,
          style: theme.errorMessageLinkStyle,
        ),
        const TextSpan(text: '.'),
        if (serviceConnection.serviceManager.connectedApp!.isIosApp) ...[
          const TextSpan(
            text: '\n\nNote: this is a legacy solution with many pitfalls. '
                'Try ',
          ),
          LinkTextSpan(
            link: Link(
              display: 'Impeller',
              url: impellerWikiUrl,
              gaScreenName: screenId,
              gaSelectedItemDescription:
                  gac.PerformanceDocs.impellerWikiLink.name,
            ),
            context: context,
            style: theme.errorMessageLinkStyle,
          ),
          const TextSpan(
            text: ' instead!',
          ),
        ],
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
    return BannerWarning(
      key: key,
      textSpans: [
        const TextSpan(
          text: '''
You are opting in to a high CPU sampling rate. This may affect the performance of your application. Please read our ''',
        ),
        LinkTextSpan(
          link: Link(
            display: 'documentation',
            url: _cpuSamplingRateDocsUrl,
            gaScreenName: screenId,
            gaSelectedItemDescription:
                gac.CpuProfilerDocs.profileGranularityDocs.name,
          ),
          context: context,
          style: theme.warningMessageLinkStyle,
        ),
        const TextSpan(
          text: ' to understand the trade-offs associated with this setting.',
        ),
      ],
      screenId: screenId,
    );
  }
}

class HttpLoggingEnabledMessage {
  HttpLoggingEnabledMessage(this.screenId)
      : key = Key('HttpLoggingEnabledMessage - $screenId');

  final Key key;

  final String screenId;

  BannerMessage build(BuildContext context) {
    final theme = Theme.of(context);
    late final BannerWarning message;
    message = BannerWarning(
      key: key,
      textSpans: [
        const TextSpan(
          text: '''
HTTP traffic is being logged for debugging purposes. This may result in increased memory usage for your app. If this is not intentional, consider ''',
        ),
        TextSpan(
          text: 'disabling http logging',
          style: theme.warningMessageLinkStyle,
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              await http_service.toggleHttpRequestLogging(false).then((_) {
                if (!http_service.httpLoggingEnabled) {
                  notificationService.push('Http logging disabled.');
                  bannerMessages.removeMessage(message);
                }
              });
            },
        ),
        const TextSpan(
          text: ' before profiling the memory of your application.',
        ),
      ],
      screenId: screenId,
    );
    return message;
  }
}

class DebugModeMemoryMessage {
  const DebugModeMemoryMessage(this.screenId);

  final String screenId;

  BannerMessage build(BuildContext context) {
    return BannerWarning(
      key: Key('DebugModeMemoryMessage - $screenId'),
      textSpans: [
        const TextSpan(
          text: '''
You are running your app in debug mode. Absolute memory usage may be higher in a debug build than in a release build.
For the most accurate absolute memory stats, relaunch your application in ''',
        ),
        _runInProfileModeTextSpan(
          context,
          screenId: screenId,
          style: Theme.of(context).warningMessageLinkStyle,
        ),
        const TextSpan(
          text: '.',
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

  BannerMessage build() {
    return BannerWarning(
      key: Key('UnsupportedFlutterVersionWarning - $screenId'),
      textSpans: [
        TextSpan(
          text: 'This version of DevTools expects the connected app to be run'
              ' on Flutter >= $supportedFlutterVersion, but the connected app'
              ' is running on Flutter $currentFlutterVersion. Some'
              ' functionality may not work. If this causes issues, try'
              ' upgrading your Flutter version.',
          style: TextStyle(fontSize: defaultFontSize),
        ),
      ],
      screenId: screenId,
    );
  }
}

void maybePushUnsupportedFlutterVersionWarning(
  String screenId, {
  required SemanticVersion supportedFlutterVersion,
}) {
  final isFlutterApp =
      serviceConnection.serviceManager.connectedApp?.isFlutterAppNow;
  if (offlineController.offlineMode.value ||
      isFlutterApp == null ||
      !isFlutterApp) {
    return;
  }
  final currentVersion =
      serviceConnection.serviceManager.connectedApp!.flutterVersionNow!;
  if (currentVersion < supportedFlutterVersion) {
    bannerMessages.addMessage(
      UnsupportedFlutterVersionWarning(
        screenId: screenId,
        currentFlutterVersion: currentVersion,
        supportedFlutterVersion: supportedFlutterVersion,
      ).build(),
    );
  }
}

void maybePushDebugModePerformanceMessage(
  BuildContext context,
  String screenId,
) {
  if (offlineController.offlineMode.value) return;
  if (serviceConnection.serviceManager.connectedApp?.isDebugFlutterAppNow ??
      false) {
    bannerMessages.addMessage(
      DebugModePerformanceMessage(screenId).build(context),
    );
  }
}

void maybePushDebugModeMemoryMessage(
  BuildContext context,
  String screenId,
) {
  if (offlineController.offlineMode.value) return;
  if (serviceConnection.serviceManager.connectedApp?.isDebugFlutterAppNow ??
      false) {
    bannerMessages.addMessage(DebugModeMemoryMessage(screenId).build(context));
  }
}

void maybePushHttpLoggingMessage(
  BuildContext context,
  String screenId,
) {
  if (http_service.httpLoggingEnabled) {
    bannerMessages.addMessage(
      HttpLoggingEnabledMessage(screenId).build(context),
    );
  }
}

extension BannerMessageThemeExtension on ThemeData {
  TextStyle get warningMessageLinkStyle => regularTextStyle.copyWith(
        decoration: TextDecoration.underline,
        color: colorScheme.onWarningContainerLink,
      );

  TextStyle get errorMessageLinkStyle => regularTextStyle.copyWith(
        decoration: TextDecoration.underline,
        color: colorScheme.onErrorContainerLink,
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
