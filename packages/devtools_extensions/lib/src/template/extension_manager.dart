// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of 'devtools_extension.dart';

final _log = Logger('devtools_extensions/extension_manager');

class ExtensionManager {
  final _registeredEventHandlers =
      <DevToolsExtensionEventType, ExtensionEventHandler>{};

  /// Whether dark theme is enabled for DevTools.
  ///
  /// The DevTools extension will rebuild with the appropriate theme on
  /// notifications from this notifier.
  final darkThemeEnabled = ValueNotifier<bool>(useDarkThemeAsDefault);

  /// Registers an event handler for [DevToolsExtensionEvent]s of type [type].
  ///
  /// When an event of type [type] is received by the extension, [handler] will
  /// be called after any default event handling takes place for event [type].
  /// See [_handleExtensionEvent].
  void registerEventHandler(
    DevToolsExtensionEventType type,
    ExtensionEventHandler handler,
  ) {
    _registeredEventHandlers[type] = handler;
  }

  /// Unregisters an event handler for [DevToolsExtensionEvent]s of type [type]
  /// that was originally registered by calling [registerEventHandler].
  void unregisterEventHandler(DevToolsExtensionEventType type) {
    _registeredEventHandlers.remove(type);
  }

  /// The listener that is added to the extension iFrame to receive messages
  /// from DevTools.
  ///
  /// We need to store this in a variable so that the listener is properly
  /// removed in [dispose].
  EventListener? _handleMessageListener;

  // ignore: unused_element, false positive due to part files
  void _init({required bool connectToVmService}) {
    window.addEventListener(
      'message',
      _handleMessageListener = _handleMessage.toJS,
    );

    // TODO(kenz): handle the ide theme that may be part of the query params.
    final queryParams = loadQueryParams();
    final themeValue = queryParams[ExtensionEventParameters.theme];
    _setThemeForValue(themeValue);

    final vmServiceUri = queryParams['uri'];
    if (connectToVmService) {
      if (vmServiceUri == null) {
        // Request the vm service uri for the connected app. DevTools will
        // respond with a [DevToolsPluginEventType.connectedVmService] event
        // containing the currently connected app's vm service URI.
        postMessageToDevTools(
          DevToolsExtensionEvent(
            DevToolsExtensionEventType.vmServiceConnection,
          ),
        );
      } else {
        unawaited(_connectToVmService(vmServiceUri));
      }
    }
  }

  // ignore: unused_element, false positive due to part files
  void _dispose() {
    _registeredEventHandlers.clear();
    window.removeEventListener('message', _handleMessageListener);
    _handleMessageListener = null;
  }

  void _handleMessage(Event e) {
    if (e.isMessageEvent) {
      final messageData = (e as MessageEvent).data!;
      final extensionEvent = DevToolsExtensionEvent.tryParse(messageData);
      if (extensionEvent != null) {
        _handleExtensionEvent(extensionEvent, e);
      }
    }
  }

  void _handleExtensionEvent(
    DevToolsExtensionEvent extensionEvent,
    MessageEvent e,
  ) {
    // Ignore events that come from the [ExtensionManager] itself.
    if (extensionEvent.source == '$ExtensionManager') return;

    // Ignore events that are not supported for the DevTools => Extension
    // direction.
    if (!extensionEvent.type
        .supportedForDirection(ExtensionEventDirection.toExtension)) {
      return;
    }

    switch (extensionEvent.type) {
      case DevToolsExtensionEventType.ping:
        postMessageToDevTools(
          DevToolsExtensionEvent(DevToolsExtensionEventType.pong),
          targetOrigin: e.origin,
        );
        break;
      case DevToolsExtensionEventType.vmServiceConnection:
        final vmServiceUri = extensionEvent
            .data?[ExtensionEventParameters.vmServiceConnectionUri] as String?;
        unawaited(_connectToVmService(vmServiceUri));
        break;
      case DevToolsExtensionEventType.themeUpdate:
        final value =
            extensionEvent.data?[ExtensionEventParameters.theme] as String?;
        _setThemeForValue(value);
        break;
      case DevToolsExtensionEventType.forceReload:
        window.location.reload();
      default:
        _log.warning(
          'Unrecognized event received by extension: '
          '(${extensionEvent.type} - ${e.data}',
        );
    }
    _registeredEventHandlers[extensionEvent.type]?.call(extensionEvent);
  }

  /// Posts a [DevToolsExtensionEvent] to the DevTools extension host.
  ///
  /// If [targetOrigin] is null, the message will be posed to
  /// [html.window.origin].
  ///
  /// When [_useSimulatedEnvironment] is true, this message will be posted
  /// to the same [html.window] that the extension is hosted in.
  void postMessageToDevTools(
    DevToolsExtensionEvent event, {
    String? targetOrigin,
  }) {
    final postWindow = _useSimulatedEnvironment ? window : window.parent;
    postWindow?.postMessage(
      {
        ...event.toJson(),
        DevToolsExtensionEvent.sourceKey: '$ExtensionManager',
      }.jsify(),
      (targetOrigin ?? window.origin).toJS,
    );
  }

  Future<void> _connectToVmService(String? vmServiceUri) async {
    // TODO(kenz): investigate. this is weird but `vmServiceUri` != null even
    // when the `toString()` representation is 'null'.
    if (vmServiceUri == null || vmServiceUri == 'null') {
      if (serviceManager.hasConnection) {
        await serviceManager.manuallyDisconnect();
      }
      if (loadQueryParams().containsKey('uri')) {
        _updateQueryParameter('uri', null);
      }
      return;
    }

    try {
      final finishedCompleter = Completer<void>();
      final vmService = await connect<VmService>(
        uri: Uri.parse(vmServiceUri),
        finishedCompleter: finishedCompleter,
        serviceFactory: VmService.defaultFactory,
      );
      await serviceManager.vmServiceOpened(
        vmService,
        onClosed: finishedCompleter.future,
      );
      _updateQueryParameter('uri', serviceManager.service!.wsUri!);
    } catch (e) {
      final errorMessage =
          'Unable to connect extension to VM service at $vmServiceUri: $e';
      showNotification('Error: $errorMessage');
      _log.shout(errorMessage);
    }
  }

  void _setThemeForValue(String? themeValue) {
    final useDarkTheme = (themeValue == null && useDarkThemeAsDefault) ||
        themeValue == ExtensionEventParameters.themeValueDark;
    darkThemeEnabled.value = useDarkTheme;
    // Use a post frame callback so that we do not try to update this while a
    // build is in progress.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQueryParameter(
        'theme',
        useDarkTheme
            ? ExtensionEventParameters.themeValueDark
            : ExtensionEventParameters.themeValueLight,
      );
    });
  }

  /// Show a notification in DevTools.
  ///
  /// This message will appear as a notification in the lower left corner of
  /// DevTools and will be automatically dismissed after a short time period
  /// (7 seconds).
  ///
  /// [message] the content of this notification.
  ///
  /// See also [ShowNotificationExtensionEvent].
  void showNotification(String message) {
    postMessageToDevTools(
      ShowNotificationExtensionEvent(message: message),
    );
  }

  /// Show a banner message in DevTools.
  ///
  /// This message will float at the top of the DevTools on an extension's
  /// screen until the user dismisses it.
  ///
  /// [key] should be a unique identifier for this particular message. This is
  /// how DevTools will determine whether this message has already been shown.
  ///
  /// [type] should be one of 'warning' or 'error', which will determine the
  /// styling of the banner message.
  ///
  /// [message] the content of this banner message.
  ///
  /// [extensionName] must match the 'name' field in your DevTools extension's
  /// `config.yaml` file. This should also match the name of the extension's
  /// parent package.
  ///
  /// When [ignoreIfAlreadyDismissed] is true (the default case), this message
  /// can only be shown and dismissed once. Any subsequent call to show the
  /// same banner message will be ignored by DevTools. If you intend for a
  /// banner message to be shown more than once, set this value to true or
  /// consider using [showNotification] instead, which shows a notification in
  /// DevTools that automatically dismisses after a short time period.
  ///
  /// See also [ShowBannerMessageExtensionEvent].
  void showBannerMessage({
    required String key,
    required String type,
    required String message,
    required String extensionName,
    bool ignoreIfAlreadyDismissed = true,
  }) {
    postMessageToDevTools(
      ShowBannerMessageExtensionEvent(
        id: key,
        bannerMessageType: type,
        message: message,
        extensionName: extensionName,
        ignoreIfAlreadyDismissed: ignoreIfAlreadyDismissed,
      ),
    );
  }

  void _updateQueryParameter(String key, String? value) {
    final newQueryParams = Map.of(loadQueryParams());
    if (value == null) {
      newQueryParams.remove(key);
    } else {
      newQueryParams[key] = value;
    }
    final newUri = Uri.parse(window.location.toString())
        .replace(queryParameters: newQueryParams);
    window.history.replaceState(
      window.history.state,
      '',
      newUri.toString(),
    );
  }
}
