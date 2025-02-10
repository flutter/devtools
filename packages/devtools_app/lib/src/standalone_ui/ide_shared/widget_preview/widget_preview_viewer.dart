// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../shared/primitives/query_parameters.dart';
import 'preview_server.dart';

typedef FrameCallback = void Function(Uint8List);


/// Streams frames from and user interactions to a remote Widget Preview
/// application instance over a [WebSocketChannel].
class PreviewViewer extends StatefulWidget {
  const PreviewViewer({super.key});

  @override
  State<PreviewViewer> createState() => _PreviewViewerState();
}

class _PreviewViewerState extends State<PreviewViewer> {
  late PreviewServer server;
  final focusNode = FocusNode();
  final frameDataListenable = ValueNotifier<ui.Image?>(null);

  @override
  void initState() {
    super.initState();
    final params = DevToolsQueryParams.load();
    server = PreviewServer(
      ws: WebSocketChannel.connect(
        // TODO(bkonyi): make this configurable.
        Uri.parse(params.previewEnvironmentUri!),
      ),
      onFrameData: onFrameData,
    );
    // Send the initial window size to the preview application so it can resize
    // its render surface to match.
    server.sendWindowSize();
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  /// Decodes a frame based on the most recent window size reported by the
  /// remote preview application and sets it as the current frame to be
  /// displayed by the UI.
  void onFrameData(Uint8List frameData, Size size, double pixelRatio) {
    ui.decodeImageFromPixels(
      frameData,
      (size.width * pixelRatio).toInt(),
      (size.height * pixelRatio).toInt(),
      ui.PixelFormat.rgba8888,
      (ui.Image image) {
        frameDataListenable.value = image;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: FutureBuilder(
          future: server.ready,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Text('Connecting...');
            }
            return KeyboardListener(
              autofocus: true,
              focusNode: focusNode,
              onKeyEvent: server.onKeyEvent,
              child: Listener(
                onPointerDown: server.onPointerDown,
                onPointerUp: server.onPointerUp,
                onPointerMove: server.onPointerMove,
                onPointerHover: server.onPointerHover,
                onPointerSignal: server.onPointerSignal,
                onPointerPanZoomStart: server.onPointerPanZoomStart,
                onPointerPanZoomUpdate: server.onPointerPanZoomUpdate,
                onPointerPanZoomEnd: server.onPointerPanZoomEnd,
                child: ValueListenableBuilder<ui.Image?>(
                  valueListenable: frameDataListenable,
                  builder: (context, frameData, _) {
                    if (frameData == null) {
                      return const Text('No frame available');
                    }
                    return RawImage(
                      image: frameData,
                      width: server.windowSize.width * server.pixelRatio,
                      height: server.windowSize.height * server.pixelRatio,
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}