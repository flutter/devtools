import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dart_code_api/dart_code_api.dart';

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
        colorScheme: const ColorScheme.dark(
          background: Color.fromARGB(255, 37, 37, 38),
          primary: Color.fromARGB(255, 0, 122, 204),
          onPrimary: Colors.white,
          inversePrimary: Color.fromARGB(255, 0, 122, 204),
          surface: Color.fromARGB(255, 0, 122, 204),
          onSurface: Colors.white,
        ),
        useMaterial3: true,
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

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String? _text;
  final DartCodeApi api;
  final _subscriptions = <StreamSubscription>[];
  final Set<String> _debugSessions = {};
  final Map<String, String?> _connectedDebugSessionVmServices = {};

  _MyHomePageState() : api = DartCodeApi() {
    _subscriptions.add(api.debug.onSessionStarting.listen((e) {
      setState(() => _debugSessions.add(e.id));
    }));
    _subscriptions.add(api.debug.onSessionStarted.listen((e) {
      setState(() => _connectedDebugSessionVmServices[e.id] = e.vmService);
    }));
    _subscriptions.add(api.debug.onSessionEnded.listen((e) {
      setState(() {
        _connectedDebugSessionVmServices.remove(e.id);
        _debugSessions.remove(e.id);
      });
    }));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    api.dispose();
    super.dispose();
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text('$_counter',
                style: Theme.of(context).textTheme.headlineMedium),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FilledButton(
                onPressed: () => api.executeCommand("flutter.createProject"),
                child: const Text('New Flutter Project'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FilledButton(
                onPressed: _selectDevice,
                child: const Text('Select Device'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: FilledButton(
                onPressed: _getHover,
                child: const Text('Get Hover'),
              ),
            ),
            if (_text != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('$_text'),
              ),
            if (_connectedDebugSessionVmServices.isNotEmpty)
              Container(
                color: Colors.green,
                child: Text(
                    'Debug session started: ${_connectedDebugSessionVmServices.values.first}'),
              )
            else if (_debugSessions.isNotEmpty)
              Container(
                color: Colors.amber,
                child: Text('Debug session starting: ${_debugSessions.first}'),
              )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _selectDevice() async {
    final device = await api.executeCommand("flutter.selectDevice");
    setState(() {
      final deviceName = (device as Map)['name'];
      _text = 'Selected device: $deviceName';
    });
  }

  Future<void> _getHover() async {
    // TODO(dantup): Use a better example that doesn't have a hard-coded path.
    // TODO(dantup): Publish LSP types to avoid raw requests?
    // {"jsonrpc":"2.0","id":1188,"method":"textDocument/hover","params":,"clientRequestTime":1682592707667}
    if (api.language == null) {
      return;
    }
    final hoverResponse = await api.language!.rawRequest(
      'textDocument/hover',
      {
        "textDocument": {
          "uri":
              "file:///Users/danny/Dev/Google/flutter/bin/cache/pkg/sky_engine/lib/core/string.dart"
        },
        "position": {"line": 107, "character": 24}
      },
    );
    setState(() {
      final contents = (hoverResponse as Map)['contents'] as Map;
      final hoverText = (contents['value'] as String).substring(0, 100);
      _text = 'Got hover: $hoverText';
    });
  }
}
