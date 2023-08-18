// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
// ignore: avoid_web_libraries_in_flutter, as designed
import 'dart:html' as html;

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_extensions/api.dart';
import 'package:flutter/material.dart';

import '../../shared/globals.dart';
import '_controller_web.dart';
import 'controller.dart';

class EmbeddedExtension extends StatefulWidget {
  const EmbeddedExtension({super.key, required this.controller});

  final EmbeddedExtensionController controller;

  @override
  State<EmbeddedExtension> createState() => _EmbeddedExtensionState();
}

class _EmbeddedExtensionState extends State<EmbeddedExtension> {
  late final EmbeddedExtensionControllerImpl _embeddedExtensionController;
  late final _ExtensionIFrameController iFrameController;

  @override
  void initState() {
    super.initState();
    _embeddedExtensionController =
        widget.controller as EmbeddedExtensionControllerImpl;
    iFrameController = _ExtensionIFrameController(_embeddedExtensionController)
      ..init();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: HtmlElementView(
        viewType: _embeddedExtensionController.viewId,
      ),
    );
  }
}

class _ExtensionIFrameController extends DisposableController
    with AutoDisposeControllerMixin {
  _ExtensionIFrameController(this.embeddedExtensionController);

  final EmbeddedExtensionControllerImpl embeddedExtensionController;

  /// Completes when the extension iFrame has received the first event on the
  /// 'onLoad' stream.
  late final Completer<void> _iFrameReady;

  /// Completes when the extension's postMessage handler is ready.
  ///
  /// We know this handler is ready when we receive a
  /// [DevToolsExtensionEventType.pong] event from the
  /// extension, which it will send in response to a
  /// [DevToolsExtensionEventType.ping] event sent from DevTools.
  late final Completer<void> _extensionHandlerReady;

  /// Timer that will poll until [_extensionHandlerReady] is complete or until
  /// [_pollUntilReadyTimeout] has passed.
  Timer? _pollForExtensionHandlerReady;

  static const _pollUntilReadyTimeout = Duration(seconds: 10);

  void init() {
    _iFrameReady = Completer<void>();

    unawaited(
      embeddedExtensionController.extensionIFrame.onLoad.first.then((_) {
        _iFrameReady.complete();
      }),
    );

    html.window.addEventListener('message', _handleMessage);

    autoDisposeStreamSubscription(
      embeddedExtensionController.extensionPostEventStream.stream
          .listen((event) async {
        final ready = await _pingExtensionUntilReady();
        if (ready) {
          _postMessage(event);
        } else {
          // TODO(kenz): we may want to give the user a way to retry the failed
          // request or show a more permanent error UI where we guide them to
          // file an issue against the extension package.
          notificationService.pushError(
            'Something went wrong.'
            ' ${embeddedExtensionController.extensionConfig.name} extension is '
            'not ready.',
          );
        }
      }),
    );
  }

  void _postMessage(DevToolsExtensionEvent event) async {
    await _iFrameReady.future;
    final message = event.toJson();
    assert(
      embeddedExtensionController.extensionIFrame.contentWindow != null,
      'Something went wrong. The iFrame\'s contentWindow is null after the'
      ' _iFrameReady future completed.',
    );
    embeddedExtensionController.extensionIFrame.contentWindow!.postMessage(
      message,
      embeddedExtensionController.extensionUrl,
    );
  }

  void _handleMessage(html.Event e) {
    if (e is html.MessageEvent) {
      final extensionEvent = DevToolsExtensionEvent.tryParse(e.data);
      if (extensionEvent != null) {
        switch (extensionEvent.type) {
          case DevToolsExtensionEventType.ping:
          // Ignore. DevTools should not receive/handle ping events.
          case DevToolsExtensionEventType.pong:
            if (!_extensionHandlerReady.isCompleted) {
              _extensionHandlerReady.complete();
            }
            break;
          case DevToolsExtensionEventType.vmServiceConnection:
            final service = serviceManager.service;
            if (service == null) break;
            _postMessage(
              DevToolsExtensionEvent(
                DevToolsExtensionEventType.vmServiceConnection,
                data: {'uri': service.connectedUri.toString()},
              ),
            );
            break;
          default:
            notificationService.push(
              'Unknown event received from extension: ${e.data}',
            );
        }
      }
    }
  }

  /// Sends [DevToolsExtensionEventType.ping] events to the extension until we
  /// receive the expected [DevToolsExtensionEventType.pong] response, or until
  /// [_pollUntilReadyTimeout] has passed.
  ///
  /// Returns whether the extension eventually became ready.
  Future<bool> _pingExtensionUntilReady() async {
    var ready = true;
    if (!_extensionHandlerReady.isCompleted) {
      _pollForExtensionHandlerReady =
          Timer.periodic(const Duration(milliseconds: 200), (_) {
        // Once the extension UI is ready, the extension will receive this
        // [DevToolsExtensionEventType.ping] message and return a
        // [DevToolsExtensionEventType.pong] message, handled in [_handleMessage].
        _postMessage(DevToolsExtensionEvent.ping);
      });

      await _extensionHandlerReady.future.timeout(
        _pollUntilReadyTimeout,
        onTimeout: () {
          ready = false;
          _pollForExtensionHandlerReady?.cancel();
        },
      );
      _pollForExtensionHandlerReady?.cancel();
    }
    return ready;
  }

  @override
  void dispose() {
    html.window.removeEventListener('message', _handleMessage);
    _pollForExtensionHandlerReady?.cancel();
    super.dispose();
  }
}
