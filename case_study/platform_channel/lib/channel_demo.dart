import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class ChannelDemo extends StatefulWidget {
  @override
  _ChannelDemoState createState() => _ChannelDemoState();
}

class _ChannelDemoState extends State<ChannelDemo> {
  static const sendMessage = 'Send message by clicking the "Mail" button below';

  BasicMessageChannel<String> _channel;

  String _response;

  void _sendMessage() {
    _channel.send('Message from Dart');
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
    _channel.setMessageHandler((String response) {
      setState(() => _response = response);
      return null;
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
                    child: const Icon(Icons.refresh),
                    onPressed: _reset,
                  ),
                  FloatingActionButton(
                    heroTag: 'send_message',
                    child: const Icon(Icons.mail),
                    onPressed: _sendMessage,
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
