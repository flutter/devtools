// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import '../logging.dart';
import '../restful_servers.dart';
import 'http_data.dart';

class Settings extends StatefulWidget {
  Settings() : restfulRoot = currentRestfulAPI;

  final Logging logs = Logging.logging;

  static late final SettingsState state;

  final RestfulAPI restfulRoot;

  @override
  State<Settings> createState() {
    state = SettingsState();
    return state;
  }

  SettingsState get currentState => state;
}

/// Which Restful Server is selected.
String restfulApi = StarWars.starWarsPeople;

late RestfulAPI currentRestfulAPI;

class SettingsState extends State<Settings> {
  Map<String, IconData> values = {
    '${CitiBikesNYC.friendlyName}': Icons.directions_bike,
    '${StarWars.starWarsFilms}': Icons.videocam,
    '${StarWars.starWarsPeople}': Icons.people_outline,
    '${StarWars.starWarsPlanets}': Icons.bubble_chart,
    '${StarWars.starWarsSpecies}': Icons.android,
    '${StarWars.starWarsStarships}': Icons.tram,
    '${StarWars.starWarsVehicles}': Icons.time_to_leave,
    '${OpenWeatherMapAPI.friendlyName}': Icons.cloud,
  };

  final Logging logs = Logging.logging;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('Restful Servers')),
      body: ListView(
        children: values.keys.map((String key) {
          return ListTile(
            leading: Icon(values[key]), // starships
            title: Text(key),
            trailing: const Icon(Icons.arrow_right),
            onTap: () {
              logs.add('$key Selected');
              setState(() {
                restfulApi = key;
              });
              // Display the data received.
              unawaited(
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyGetHttpData()),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
