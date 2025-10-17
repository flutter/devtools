// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../screens/performance/performance_utils.dart';
import '../../service/connected_app/connected_app.dart';
import '../analytics/constants.dart' as gac;
import '../framework/screen.dart';
import '../globals.dart';
import '../http/http_service.dart' as http_service;
import '../primitives/query_parameters.dart';
import '../primitives/utils.dart';
import '../ui/common_widgets.dart';

const _runInProfileModeDocsUrl = 'https://flutter.dev/to/use-profile-mode';

const _cpuSamplingRateDocsUrl =
    'https://docs.flutter.dev/tools/devtools/cpu-profiler#cpu-sampling-rate';

/// Screen id to use for banner messages that are intended to be universal for
/// every DevTools screen.
///
/// Messages with this screen id will be added to the list of messages for
/// every screen from the [BannerMessages] widget.
const universalScreenId = 'universal';

class BannerMessagesController extends DisposableController
    with AutoDisposeControllerMixin {
  BannerMessagesController() {
    previouslyConnected =
        serviceConnection.serviceManager.connectedState.value.connected;
    addAutoDisposeListener(serviceConnection.serviceManager.connectedState, () {
      final connected =
          serviceConnection.serviceManager.connectedState.value.connected;
      if (previouslyConnected != connected) {
        for (final messageList in _messages.values) {
          for (final message in messageList.value) {
            if (message.dismissOnConnectionChanges) {
              bannerMessages.removeMessage(message);
            }
          }
        }
      }
      previouslyConnected = connected;
    });
  }

  /// Tracks the previous app connection state for the purpose of dismissing
  /// messages upon connection changes.
  ///
  /// See [BannerMessage.dismissOnConnectionChanges].
  bool previouslyConnected = false;

  final _messages = <String, ListValueNotifier<BannerMessage>>{};
  final _dismissedMessageKeys = <Key?>{};

  /// Adds a banner message to top of DevTools.
  ///
  /// If the message is already visible, or if this message has already been
  /// dismissed once and [ignoreIfAlreadyDismissed] is true, this method call
  /// will be a no-op.
  ///
  /// [callInPostFrameCallback] determines whether the message will be added in
  /// a post frame callback. This should be true (default) whenever this method
  /// is called from a Flutter lifecycle method (initState,
  /// didChangeDependencies, etc.). Set this value to false when the banner
  /// message is being added from outside of the Flutter widget lifecycle.
  void addMessage(
    BannerMessage message, {
    bool callInPostFrameCallback = true,
    bool ignoreIfAlreadyDismissed = true,
  }) {
    void add() {
      if ((ignoreIfAlreadyDismissed && isMessageDismissed(message)) ||
          isMessageVisible(message)) {
        return;
      }
      final messages = _messagesForScreen(message.screenId);
      messages.add(message);
    }

    if (callInPostFrameCallback) {
      // We push the banner message in a post frame callback because otherwise,
      // we'd be trying to call setState while the parent widget `BannerMessages`
      // is in the middle of `build`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        add();
      });
    } else {
      add();
    }
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

  void removeMessageByKey(Key key, String screenId, {bool dismiss = false}) {
    final currentMessages = _messagesForScreen(screenId);
    final messageWithKey = currentMessages.value.firstWhereOrNull(
      (m) => m.key == key,
    );
    if (messageWithKey != null) {
      removeMessage(messageWithKey, dismiss: dismiss);
    }
  }

  @visibleForTesting
  bool isMessageDismissed(BannerMessage message) {
    return _dismissedMessageKeys.contains(message.key);
  }

  @visibleForTesting
  bool isMessageVisible(BannerMessage message) {
    return _messagesForScreen(
      message.screenId,
    ).value.where((m) => m.key == message.key).isNotEmpty;
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
  const BannerMessages({super.key, required this.screen});

  final Screen screen;

  // TODO(kenz): use an AnimatedList for message changes.
  @override
  Widget build(BuildContext context) {
    final universalMessages = bannerMessages.messagesForScreen(
      universalScreenId,
    );
    final messagesForScreen = bannerMessages.messagesForScreen(screen.screenId);
    return Column(
      children: [
        MultiValueListenableBuilder(
          listenables: [universalMessages, messagesForScreen],
          builder: (context, values, _) {
            final universalMessages = values[0] as List<BannerMessage>;
            final messages = values[1] as List<BannerMessage>;
            return Column(children: [...universalMessages, ...messages]);
          },
        ),
        Expanded(child: screen.build(context)),
      ],
    );
  }
}

enum BannerMessageType {
  warning,
  error,
  info;

  static BannerMessageType? parse(String? value) {
    for (final type in BannerMessageType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}

class BannerMessage extends StatelessWidget {
  const BannerMessage({
    required super.key,
    required this.buildTextSpans,
    required this.screenId,
    required this.messageType,
    this.dismissOnConnectionChanges = true,
    this.buildActions,
  });

  final List<InlineSpan> Function(BuildContext) buildTextSpans;
  final List<Widget> Function(BuildContext)? buildActions;
  final String screenId;
  final BannerMessageType messageType;

  /// Whether this message should be dismissed on app connection changes.
  final bool dismissOnConnectionChanges;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = _backgroundColor(colorScheme);
    final foregroundColor = _foregroundColor(colorScheme);
    const iconPadding = 12.0;

    return Card(
      color: backgroundColor,
      margin: const EdgeInsets.only(bottom: intermediateSpacing),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: densePadding,
          horizontal: denseSpacing,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (messageType != BannerMessageType.info)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: iconPadding,
                    ),
                    child: Icon(
                      messageType == BannerMessageType.error
                          ? Icons.error_outline
                          : Icons.warning_amber_outlined,
                      size: actionsIconSize,
                      color: foregroundColor,
                    ),
                  ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: theme.regularTextStyle.copyWith(
                        color: foregroundColor,
                      ),
                      children: buildTextSpans(context),
                    ),
                  ),
                ),
                const SizedBox(width: defaultSpacing),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: actionsIconSize,
                    color: foregroundColor,
                  ),
                  onPressed: () =>
                      bannerMessages.removeMessage(this, dismiss: true),
                ),
              ],
            ),
            if (buildActions != null) ...[
              const SizedBox(height: denseSpacing),
              Padding(
                padding: EdgeInsets.only(
                  left:
                      // Info messages do not have a leading icon to match
                      // padding for.
                      messageType != BannerMessageType.info ? iconPadding : 0.0,
                ),
                child: Row(children: buildActions!(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _backgroundColor(ColorScheme colorScheme) {
    if (messageType == BannerMessageType.info) {
      return colorScheme.secondaryContainer;
    }

    return (messageType == BannerMessageType.error
        ? colorScheme.errorContainer
        : colorScheme.warningContainer);
  }

  Color _foregroundColor(ColorScheme colorScheme) {
    if (messageType == BannerMessageType.info) {
      return colorScheme.onSecondaryContainer;
    }

    return (messageType == BannerMessageType.error
        ? colorScheme.onErrorContainer
        : colorScheme.onWarningContainer);
  }
}

class _BannerError extends BannerMessage {
  const _BannerError({
    required super.key,
    required super.buildTextSpans,
    required super.screenId,
  }) : super(messageType: BannerMessageType.error);
}

// TODO(kenz): add "Do not show this again" option to warnings.
class BannerWarning extends BannerMessage {
  const BannerWarning({
    required super.key,
    required super.buildTextSpans,
    required super.screenId,
    super.dismissOnConnectionChanges = true,
    super.buildActions,
  }) : super(messageType: BannerMessageType.warning);
}

class BannerInfo extends BannerMessage {
  const BannerInfo({
    required super.key,
    required super.buildTextSpans,
    required super.screenId,
    super.dismissOnConnectionChanges = true,
    super.buildActions,
  }) : super(messageType: BannerMessageType.info);
}

class DebugModePerformanceMessage extends BannerWarning {
  DebugModePerformanceMessage({required super.screenId})
    : super(
        key: Key('DebugModePerformanceMessage - $screenId'),
        buildTextSpans: (context) => [
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
            style: Theme.of(context).warningMessageLinkStyle,
          ),
          const TextSpan(text: '.'),
        ],
      );
}

class ShaderJankMessage extends _BannerError {
  ShaderJankMessage({
    required super.screenId,
    required int jankyFramesCount,
    required Duration jankDuration,
  }) : super(
         key: Key('ShaderJankMessage - $screenId'),
         buildTextSpans: (context) {
           final theme = Theme.of(context);
           final jankDurationText = durationText(
             jankDuration,
             unit: DurationDisplayUnit.milliseconds,
           );
           return [
             TextSpan(
               text:
                   'Shader compilation jank detected. $jankyFramesCount '
                   '${pluralize('frame', jankyFramesCount)} janked with a total of '
                   '$jankDurationText spent in shader compilation. To pre-compile '
                   'shaders, see the instructions at ',
             ),
             GaLinkTextSpan(
               link: GaLink(
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
                 text:
                     '\n\nNote: this is a legacy solution with many pitfalls. '
                     'Try ',
               ),
               GaLinkTextSpan(
                 link: GaLink(
                   display: 'Impeller',
                   url: impellerDocsUrl,
                   gaScreenName: screenId,
                   gaSelectedItemDescription:
                       gac.PerformanceDocs.impellerDocsLink.name,
                 ),
                 context: context,
                 style: theme.errorMessageLinkStyle,
               ),
               const TextSpan(text: ' instead!'),
             ],
           ];
         },
       );
}

class HighCpuSamplingRateMessage extends BannerWarning {
  HighCpuSamplingRateMessage({required super.screenId})
    : super(
        key: generateKey(screenId),
        buildTextSpans: (context) => [
          const TextSpan(
            text: '''
You are opting in to a high CPU sampling rate. This may affect the performance of your application. Please read our ''',
          ),
          GaLinkTextSpan(
            link: GaLink(
              display: 'documentation',
              url: _cpuSamplingRateDocsUrl,
              gaScreenName: screenId,
              gaSelectedItemDescription:
                  gac.CpuProfilerDocs.profileGranularityDocs.name,
            ),
            context: context,
            style: Theme.of(context).warningMessageLinkStyle,
          ),
          const TextSpan(
            text: ' to understand the trade-offs associated with this setting.',
          ),
        ],
      );

  static Key generateKey(String screenId) =>
      Key('HighCpuSamplingRateMessage - $screenId');
}

class HttpLoggingEnabledMessage extends BannerWarning {
  HttpLoggingEnabledMessage({required super.screenId})
    : super(
        key: _generateKey(screenId),
        buildTextSpans: (context) => [
          const TextSpan(
            text: '''
HTTP traffic is being logged for debugging purposes. This may result in increased memory usage for your app. If this is not intentional, consider ''',
          ),
          TextSpan(
            text: 'disabling http logging',
            style: Theme.of(context).warningMessageLinkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                await http_service.toggleHttpRequestLogging(false).then((_) {
                  if (!http_service.httpLoggingEnabled) {
                    notificationService.push('Http logging disabled.');
                    bannerMessages.removeMessageByKey(
                      _generateKey(screenId),
                      screenId,
                    );
                  }
                });
              },
          ),
          const TextSpan(
            text: ' before profiling the memory of your application.',
          ),
        ],
      );

  static Key _generateKey(String screenId) =>
      Key('HttpLoggingEnabledMessage - $screenId');
}

class DebugModeMemoryMessage extends BannerWarning {
  DebugModeMemoryMessage({required super.screenId})
    : super(
        key: Key('DebugModeMemoryMessage - $screenId'),
        buildTextSpans: (context) => [
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
          const TextSpan(text: '.'),
        ],
      );
}

class DebuggerIdeRecommendationMessage extends BannerWarning {
  DebuggerIdeRecommendationMessage({required super.screenId})
    : super(
        key: Key('DebuggerIdeRecommendationMessage - $screenId'),
        buildTextSpans: (context) {
          final isFlutterApp =
              serviceConnection.serviceManager.connectedApp?.isFlutterAppNow ??
              false;
          final codeType = isFlutterApp ? 'Flutter' : 'Dart';
          final recommendedDebuggers = devToolsEnvironmentParameters
              .recommendedDebuggers(context, isFlutterApp: isFlutterApp);
          return [
            TextSpan(
              text: '''
The $codeType DevTools debugger is in maintenance mode. For the best debugging experience, we recommend debugging your $codeType code in a supported IDE''',
            ),
            if (recommendedDebuggers != null) ...[
              const TextSpan(text: ', such as '),
              ...recommendedDebuggers,
            ],
            const TextSpan(text: '.'),
          ];
        },
      );
}

class WelcomeToNewInspectorMessage extends BannerInfo {
  WelcomeToNewInspectorMessage({required super.screenId})
    : super(
        key: Key('WelcomeToNewInspectorMessage - $screenId'),
        buildTextSpans: (context) => [
          const TextSpan(
            text: '''
👋 Welcome to the new Flutter inspector! To get started, check out the ''',
          ),
          GaLinkTextSpan(
            link: GaLink(
              display: 'documentation',
              url: 'https://docs.flutter.dev/tools/devtools/inspector#new',
              gaScreenName: screenId,
              gaSelectedItemDescription: gac.inspectorV2Docs,
            ),
            context: context,
            style: Theme.of(context).linkTextStyle,
          ),
          const TextSpan(text: '.'),
        ],
      );
}

class WasmWelcomeMessage extends BannerInfo {
  WasmWelcomeMessage()
    : super(
        key: const Key('WasmWelcomeMessage'),
        screenId: universalScreenId,
        dismissOnConnectionChanges: true,
        buildTextSpans: (context) => [
          const TextSpan(
            text:
                '🚀 A faster and more performant DevTools is now available on WebAssembly! Click ',
          ),
          const TextSpan(
            text: 'Enable',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const TextSpan(text: ' to try it out now.'),
          const TextSpan(
            text: ' Please note that this will trigger a reload of DevTools.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
        buildActions: (context) => [
          DevToolsButton(
            label: 'Enable',
            onPressed: () async {
              await preferences.enableWasmInStorage();
              webReload();
            },
          ),
        ],
      );
}

void maybePushDebugModePerformanceMessage(String screenId) {
  if (offlineDataController.showingOfflineData.value) return;
  if (serviceConnection.serviceManager.connectedApp?.isDebugFlutterAppNow ??
      false) {
    bannerMessages.addMessage(DebugModePerformanceMessage(screenId: screenId));
  }
}

void maybePushDebugModeMemoryMessage(String screenId) {
  if (offlineDataController.showingOfflineData.value) return;
  if (serviceConnection.serviceManager.connectedApp?.isDebugFlutterAppNow ??
      false) {
    bannerMessages.addMessage(DebugModeMemoryMessage(screenId: screenId));
  }
}

void maybePushHttpLoggingMessage(String screenId) {
  if (http_service.httpLoggingEnabled) {
    bannerMessages.addMessage(HttpLoggingEnabledMessage(screenId: screenId));
  }
}

void pushDebuggerIdeRecommendationMessage(String screenId) {
  bannerMessages.addMessage(
    DebuggerIdeRecommendationMessage(screenId: screenId),
  );
}

void pushWelcomeToNewInspectorMessage(String screenId) {
  bannerMessages.addMessage(WelcomeToNewInspectorMessage(screenId: screenId));
}

void pushWasmWelcomeMessage() {
  bannerMessages.addMessage(WasmWelcomeMessage());
}

class CopyToClipboardNotWorkingMessage extends BannerWarning {
  CopyToClipboardNotWorkingMessage()
    : super(
        key: const Key('CopyToClipboardNotWorkingMessage'),
        screenId: universalScreenId,
        buildTextSpans: (context) => [
          const TextSpan(
            text:
                'Copy-to-clipboard may not work when DevTools is embedded in VS Code. See ',
          ),
          GaLinkTextSpan(
            link: const GaLink(
              display: 'microsoft/vscode#129178',
              url: 'https://github.com/microsoft/vscode/issues/129178',
              gaScreenName: universalScreenId,
              gaSelectedItemDescription: 'copy-to-clipboard-issue',
            ),
            context: context,
            style: Theme.of(context).warningMessageLinkStyle,
          ),
          const TextSpan(text: ' for details.'),
        ],
      );
}

void maybePushCopyToClipboardNotWorkingMessage() {
  final queryParams = DevToolsQueryParams.load();
  if (queryParams.embedMode.embedded && queryParams.ide == 'VSCode') {
    bannerMessages.addMessage(CopyToClipboardNotWorkingMessage());
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

GaLinkTextSpan _runInProfileModeTextSpan(
  BuildContext context, {
  required String screenId,
  required TextStyle style,
}) {
  return GaLinkTextSpan(
    link: GaLink(
      display: 'profile mode',
      url: _runInProfileModeDocsUrl,
      gaScreenName: screenId,
      gaSelectedItemDescription: gac.profileModeDocs,
    ),
    context: context,
    style: style,
  );
}
