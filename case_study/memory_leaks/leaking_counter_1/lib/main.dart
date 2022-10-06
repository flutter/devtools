import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

typedef ButtonClickHandler = Function(BuildContext);

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  VoidCallback? _handler;

  void _incrementCounter(BuildContext context) {
    setState(() {
      _counter++;
    });
  }

  VoidCallback _buttonClickHandler(BuildContext context) {
    final theHandler = _handler;

    result() {
      if (theHandler == null) {
        _incrementCounter(context);
      } else {
        theHandler();
      }
    }

    _handler = result;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _buttonClickHandler(context),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
