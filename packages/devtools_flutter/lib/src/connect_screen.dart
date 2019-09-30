import 'package:flutter/material.dart';

import 'screen.dart';

class ConnectScreen extends StatefulWidget {
  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Screen(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Connect', style: textTheme.headline),
          const Divider(),
          const Padding(padding: EdgeInsets.only(top: 10.0)),
          Text('Connect to a running app', style: textTheme.body2),
          Text('Enter a port or URL to a running Dart or Flutter application',
              style: textTheme.caption),
          const Padding(padding: EdgeInsets.only(top: 20.0)),
          _buildTextInput(),
          const Divider(),
          const Padding(padding: EdgeInsets.only(top: 10.0)),
          const Text('Additional features'),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: 240.0,
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(width: 0.5, color: Colors.grey),
              ),
              hintText: 'Port or URL',
            ),
            maxLines: 1,
            controller: controller,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 20.0),
        ),
        RaisedButton(
          child: const Text('Connect'),
          onPressed: connect,
        ),
      ],
    );
  }

  void connect() {}
}
