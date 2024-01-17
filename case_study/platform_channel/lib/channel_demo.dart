import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChannelDemo extends StatefulWidget {
  @override
  State<ChannelDemo> createState() => _ChannelDemoState();
}

class _ChannelDemoState extends State<ChannelDemo> {
  static const sendMessage = 'Send message by clicking the "Mail" button below';

  late BasicMessageChannel<String> _channel;

  late String _response;

  void _sendMessage() {
    unawaited(_channel.send('Message from Dart'));
  }

  void _reset() {
    setState(() {
      _response = sendMessage;
    });
  }

  @override
  void initState() {
    super.initState();
    _response = sendMessage;
    _channel = const BasicMessageChannel<String>('shuttle', StringCodec());
    _channel.setMessageHandler((String? response) async {
      if (response != null) {
        setState(() => _response = response);
      }
      return '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Center(child: Text(_response)),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FloatingActionButton(
                    heroTag: 'reset',
                    onPressed: _reset,
                    child: const Icon(Icons.refresh),
                  ),
                  FloatingActionButton(
                    heroTag: 'send_message',
                    onPressed: _sendMessage,
                    child: const Icon(Icons.mail),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
