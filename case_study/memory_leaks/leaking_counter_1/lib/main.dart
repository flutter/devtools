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

class MyIncrementer {
  MyIncrementer(this.increment);
  final VoidCallback increment;
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  late MyIncrementer _incrementer = MyIncrementer(
    () => setState(() {
      _counter++;
    }),
  );

  /// Increments counter if current screen contains floating action button.
  void _incrementCounter(BuildContext context) {
    final oldIncrementer = _incrementer;
    final screen = buildScreen(context);

    _incrementer = MyIncrementer(
      () {
        if (screen.floatingActionButton != null) {
          oldIncrementer.increment();
        }
      },
    );

    _incrementer.increment();
  }

  Scaffold buildScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'The counter value is:',
            ),
            MyCounter(value: _counter),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _incrementCounter(context),
        tooltip: 'Increment counter',
        foregroundColor: theme.canvasColor,
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => buildScreen(context);
}

class MyCounter extends StatelessWidget {
  const MyCounter({super.key, required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$value',
      style: Theme.of(context).textTheme.headlineMedium,
    );
  }
}
