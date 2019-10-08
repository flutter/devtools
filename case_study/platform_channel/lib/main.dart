import 'package:flutter/material.dart';

import 'channel_demo.dart';

void main() => runApp(MyApp());

const platformChannelTitle = 'Platform Channel Demo';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(platformChannelTitle),
      ),
      body: Center(
        child: FlatButton(
          color: Colors.green,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChannelDemo()),
            );
          },
          child: const Text(
            platformChannelTitle,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
