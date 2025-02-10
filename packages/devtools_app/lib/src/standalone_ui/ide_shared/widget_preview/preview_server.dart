// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_rpc_2/json_rpc_2.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'constants.dart';

typedef FrameCallback = void Function(Uint8List);

/// A custom [Peer] which supports receiving binary data over a JSON-RPC
/// connection.
///
/// [String] data is treated as JSON and [Uint8List] data is assumed to be
/// a frame event. Frame events are forwarded to the registered [FrameCallback]
/// to be decoded and rendered.
class FrameStreamingPeer extends Peer {
  FrameStreamingPeer(WebSocketChannel ws)
      : super(
          ws.transform<String>(
            StreamChannelTransformer(
              StreamTransformer<Object?, String>.fromHandlers(
                handleData: (Object? data, EventSink<String> sink) =>
                    _transformStream(data, sink),
              ),
              StreamSinkTransformer<String, Object?>.fromHandlers(
                handleData: (String data, EventSink<Object?> sink) {
                  sink.add(data);
                },
              ),
            ),
          ),
        );

  static void _transformStream(Object? data, EventSink<String> sink) {
    if (data is String) {
      sink.add(data);
    } else if (data is Uint8List) {
      _callback?.call(data);
    }
  }

  static FrameCallback? _callback;

  void registerFrameCallback(FrameCallback callback) {
    if (_callback != null) {
      throw StateError('Frame callback already registered!');
    }
    _callback = callback;
  }
}

/// Detects when the size of the preview window changes and forwards the new
/// size to the remote preview application.
class ScreenSizeChangeObserver with WidgetsBindingObserver {
  ScreenSizeChangeObserver({required this.server});

  final PreviewServer server;

  @override
  void didChangeMetrics() {
    server.sendWindowSize();
  }
}

class PreviewServer {
  PreviewServer({
    required this.ws,
    required this.onFrameData,
  }) : connection = FrameStreamingPeer(ws) {
    connection
      ..registerMethod(
        'windowSize',
        (Parameters params) {
          windowSize = Size(
            params.asMap['width'] as double,
            params.asMap['height'] as double,
          );
          pixelRatio = params.asMap['pixelRatio'];
        },
      )
      ..registerFrameCallback(
        (Uint8List frameData) {
          onFrameData(frameData, windowSize, pixelRatio);
        },
      );

    // Start listening for requests from the connection and notify the remote
    // application that we've finished initializing.
    connection.listen();
    connection.sendNotification('ready');

    // Register an observer to detect changes in the preview viewer window
    // size.
    WidgetsBinding.instance.addObserver(observer);
  }

  Future<void> get ready => ws.ready;
  final WebSocketChannel ws;

  /// Completes when the underlying connection closes.
  Future<void> get done => connection.done;

  /// The JSON-RPC connection to the remote preview application.
  final FrameStreamingPeer connection;
  late final observer = ScreenSizeChangeObserver(server: this);

  /// The current window size reported by the preview application.
  Size windowSize = Size.zero;

  /// The current pixel ratio reported by the preview application.
  double pixelRatio = 0.0;

  final void Function(Uint8List, Size, double) onFrameData;

  /// Notifies the remote preview application that the preview viewer's window
  /// size has changed.
  void sendWindowSize() async {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final size = view.physicalSize;
    final pixelRatio = view.devicePixelRatio;
    await connection.sendRequest('setWindowSize', {
      'x': size.width,
      'y': size.height,
      'devicePixelRatio': pixelRatio,
    });
  }

  /// Forwards hover events to the preview application.
  void onPointerHover(PointerHoverEvent details) async {
    await connection.sendRequest(
      InteractionDelegateConstants.kOnPointerHover,
      {
        InteractionDelegateConstants.kLocalPositionX: details.localPosition.dx,
        InteractionDelegateConstants.kLocalPositionY: details.localPosition.dy,
      },
    );
  }

  /// Forwards event for the press of the primary button to the preview
  /// application.
  void onPointerDown(PointerDownEvent details) async {
    await connection.sendRequest(InteractionDelegateConstants.kOnTapDown, {
      InteractionDelegateConstants.kLocalPositionX: details.localPosition.dx,
      InteractionDelegateConstants.kLocalPositionY: details.localPosition.dy,
    });
  }


  /// Forwards event for the release of the primary button to the preview
  /// application.
  void onPointerUp(PointerUpEvent details) async {
    await await connection.sendRequest(InteractionDelegateConstants.kOnTapUp);
  }

  /// Forwards pointer move events (e.g., the current pointer location) to the
  /// preview application.
  void onPointerMove(PointerMoveEvent details) async {
    await connection.sendRequest(
      InteractionDelegateConstants.kOnPointerMove,
      {
        InteractionDelegateConstants.kLocalPositionX: details.localPosition.dx,
        InteractionDelegateConstants.kLocalPositionY: details.localPosition.dy,
        InteractionDelegateConstants.kButtons: details.buttons,
      },
    );
  }

  /// Forwards mouse wheel scroll events to the preview application.
  void onPointerSignal(PointerSignalEvent details) async {
    if (details is PointerScrollEvent) {
      await connection.sendRequest(
        InteractionDelegateConstants.kOnScroll,
        {
          InteractionDelegateConstants.kLocalPositionX: details.localPosition.dx,
          InteractionDelegateConstants.kLocalPositionY: details.localPosition.dy,
          InteractionDelegateConstants.kDeltaX: details.scrollDelta.dx,
          InteractionDelegateConstants.kDeltaY: details.scrollDelta.dy,
        },
      );
    }
  }

  /// Notifies the preview application that a pan/zoom event is possibly
  /// in-progress.
  ///
  /// This is an implementation detail of touchpad scrolling behavior.
  void onPointerPanZoomStart(PointerPanZoomStartEvent details) async {
    await connection.sendRequest(
      InteractionDelegateConstants.kOnPanZoomStart,
      {
        InteractionDelegateConstants.kLocalPositionX: details.localPosition.dx,
        InteractionDelegateConstants.kLocalPositionY: details.localPosition.dy,
      },
    );
  }

  /// Notifies the preview application of updates to an in-progress pan/zoom
  /// event.
  ///
  /// This is an implementation detail of touchpad scrolling behavior.
  void onPointerPanZoomUpdate(PointerPanZoomUpdateEvent details) async {
    await connection.sendRequest(
      InteractionDelegateConstants.kOnPanZoomUpdate,
      {
        InteractionDelegateConstants.kLocalPositionX: details.localPosition.dx,
        InteractionDelegateConstants.kLocalPositionY: details.localPosition.dy,
        InteractionDelegateConstants.kDeltaX: details.pan.dx,
        InteractionDelegateConstants.kDeltaY: details.pan.dy,
      },
    );
  }

  /// Notifies the preview application that a pan/zoom event has concluded.
  ///
  /// This is an implementation detail of touchpad scrolling behavior.
  void onPointerPanZoomEnd(PointerPanZoomEndEvent details) async {
    await connection.sendRequest(InteractionDelegateConstants.kOnPanZoomEnd);
  }

  /// Forwards key presses to the preview application.
  void onKeyEvent(
    KeyEvent event,
  ) async {
    await connection.sendRequest(
      switch (event) {
        KeyDownEvent _ => InteractionDelegateConstants.kOnKeyDownEvent,
        KeyUpEvent _ => InteractionDelegateConstants.kOnKeyUpEvent,
        KeyRepeatEvent _ => InteractionDelegateConstants.kOnKeyRepeatEvent,
        _ => throw StateError('Unexpected KeyEvent: ${event.runtimeType}'),
      },
      {
        InteractionDelegateConstants.kKeyId: event.logicalKey.keyId,
        InteractionDelegateConstants.kPhysicalKeyId:
            event.physicalKey.usbHidUsage,
        InteractionDelegateConstants.kCharacter: event.character,
      },
    );
  }
}
