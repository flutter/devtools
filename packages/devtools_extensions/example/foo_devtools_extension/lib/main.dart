import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const FooPackageDevToolsExtension());
}

class FooPackageDevToolsExtension extends StatelessWidget {
  const FooPackageDevToolsExtension({super.key});

  @override
  Widget build(BuildContext context) {
    return const DevToolsExtension(
      child: FooExtensionHomePage(),
    );
  }
}

class FooExtensionHomePage extends StatefulWidget {
  const FooExtensionHomePage({super.key});

  @override
  State<FooExtensionHomePage> createState() => _FooExtensionHomePageState();
}

class _FooExtensionHomePageState extends State<FooExtensionHomePage> {
  int _counter = 0;

  String? _message;

  @override
  void initState() {
    super.initState();
    // Example of the devtools extension registering a custom handler.
    extensionManager.registerEventHandler(
      DevToolsExtensionEventType.unknown,
      (event) {
        setState(() {
          _message = event.data?['message'] as String?;
        });
      },
    );
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
    extensionManager.postMessageToDevTools(
      DevToolsExtensionEvent(
        DevToolsExtensionEventType.unknown,
        data: {'increment_count': _counter},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Foo DevTools Extension'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('You have pushed the button $_counter times:'),
            const SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _incrementCounter,
              child: const Text('Increment and post count to DevTools'),
            ),
            const SizedBox(height: 48.0),
            Text('Received message from DevTools: $_message'),
          ],
        ),
      ),
    );
  }
}
