// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A connection screen shown when running outside of VS Code to accept a
/// WebSocket URL to connect to an instance of VS Code.
class WebSocketConnectionScreen extends StatefulWidget {
  const WebSocketConnectionScreen({required this.onConnected, super.key});

  final Function(WebSocketChannel) onConnected;

  @override
  State<WebSocketConnectionScreen> createState() =>
      _WebSocketConnectionScreenState();
}

class _WebSocketConnectionScreenState extends State<WebSocketConnectionScreen> {
  final _controller = TextEditingController();
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const Text('Connect to VS Code'),
          const Text('Enter WebSocket URL from VS Code'),
          TextField(controller: _controller),
          TextButton(
            onPressed: () async {
              try {
                final socket =
                    WebSocketChannel.connect(Uri.parse(_controller.text));
                await socket.ready;
                widget.onConnected(socket);
              } catch (e) {
                setState(() {
                  _errorText = '$e';
                });
              }
            },
            child: const Text('Connect'),
          ),
          if (_errorText != null) Text(_errorText!),
        ],
      ),
    );
  }
}
