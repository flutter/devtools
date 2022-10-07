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

  late MyIncrementer _incrementer = MyIncrementer(() => setState(() {
        _counter++;
      }));

  void _updateAndInvokeIncrementer(BuildContext context) {
    final incrementer = _incrementer;

    _incrementer = MyIncrementer(() {
      if (identityHashCode(context) > 0) {
        incrementer.increment();
      }
    });

    _incrementer.increment();
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
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _updateAndInvokeIncrementer(context),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
