import 'package:flutter/material.dart';

import '../logging.dart';
import '../restful_servers.dart';

class Settings extends StatefulWidget {
  Settings() : restfulRoot = currentRestfulAPI;

  final Logging logs = Logging.logging;

  static SettingsState state;

  final RestfulAPI restfulRoot;

  @override
  SettingsState createState() {
    state = SettingsState();
    return state;
  }

  SettingsState get currentState => state;
}

/// Which Restful Server is selected.
String restfulApi = 'StarWars People';

RestfulAPI currentRestfulAPI;

class SettingsState extends State<Settings> {
  Map<String, bool> values = {
    'NYC Bike Sharing': false,
    'StarWars Films': false,
    'StarWars People': false,
    'StarWars Planets': false,
    'StarWars Species': false,
    'StarWars Starships': false,
    'StarWars Vehicles': false,
    'Weather': false,
  };

  final Logging logs = Logging.logging;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restful Servers')),
      body: ListView(
        children: values.keys.map((String key) {
          return RadioListTile<String>(
            title: Text(key),
            value: key,
            groupValue: restfulApi,
            onChanged: (String value) {
              setState(() {
                restfulApi = value;
                logs.add('Settings is now $restfulApi');
              });
            },
          );
        }).toList(),
      ),
    );
  }
}
