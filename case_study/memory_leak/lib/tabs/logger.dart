import 'package:flutter/material.dart';

import '../logging.dart';

class Logger extends StatelessWidget {
  final Logging _logging = Logging.logging;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logger',
      theme: ThemeData(
          primaryColor: Colors.blue, accentColor: Colors.lightBlue),
      home: LogEntries(_logging),
    );
  }
}

class LogEntries extends StatefulWidget {
  const LogEntries(this._logging);

  final Logging _logging;

  @override
  State createState() => LoggingState(_logging);
}

class LoggingState extends State<LogEntries> {
  LoggingState(this._logging);

  Logging _logging;
  final _saved = List<String>();
  final _biggerFont = const TextStyle(fontSize: 18.0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinite List'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(icon: Icon(Icons.list)/*, onPressed: _pushSaved*/),
        ],
      ),
      body: _buildSuggestions(),
    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          final tiles = _saved.map(
                (itemValue) {
              return ListTile(
                title: Text(
                  itemValue,
                  style: _biggerFont,
                ),
              );
            },
          );
          final divided = ListTile
              .divideTiles(
            context: context,
            tiles: tiles,
          )
              .toList();

          return Scaffold(
            appBar: AppBar(
              title: const Text('Saved lists'),
            ),
            body: ListView(children: divided),
          );
        },
      ),
    );
  }

  Widget _buildRow(String logEntry) {
    return ListTile(
      title: Text(
        'LOG: $logEntry',
        style: _biggerFont,
      ),
      trailing: Icon(
//        alreadySaved ? Icons.favorite : Icons.favorite_border,
//        color: alreadySaved ? Colors.red : null,
        Icons.favorite_border,
        color: null,
      ),
      onTap: () {
        setState(() {
            _saved.add('LOG: $logEntry');
        });
      },
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        // The itemBuilder callback is called once per suggested word pairing,
        // and places each suggestion into a ListTile row.
        // For even rows, the function adds a ListTile row for the word pairing.
        // For odd rows, the function adds a Divider widget to visually
        // separate the entries. Note that the divider may be difficult
        // to see on smaller devices.
        itemBuilder: (context, i) {
          // Add a one-pixel-high divider widget before each row in theListView.
          if (i.isOdd) return const Divider();

          // The syntax "i ~/ 2" divides i by 2 and returns an integer result.
          // For example: 1, 2, 3, 4, 5 becomes 0, 1, 1, 2, 2.
          // This calculates the actual number of word pairings in the ListView,
          // minus the divider widgets.
          final index = i ~/ 2;
          if (index < _logging.logs.length)
            return _buildRow(_logging.logs[index]);
/*
          // Emits Idle... lots of them every 100ms.
          // TOOD(terry): UI needs to appear sluggish clue to look for leaks, etc.
          else
            return _buildRow('Idle...');
*/
        });
  }
}