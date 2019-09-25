import 'package:flutter/material.dart';

class Page extends StatelessWidget {
  const Page({Key key, @required this.child})
      : assert(child != null),
        super(key: key);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.fullscreen),
            const Text('Dart DevTools'),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: child,
        ),
      ),
    );
  }
}
