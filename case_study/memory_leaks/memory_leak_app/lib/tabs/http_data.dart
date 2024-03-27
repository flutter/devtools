// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../common.dart';
import '../logging.dart';
import '../restful_servers.dart';
import 'settings.dart';

/// Create a stateful widget
class MyGetHttpData extends StatefulWidget {
  @override
  State<MyGetHttpData> createState() => MyGetHttpDataState();
}

// Create the state for our stateful widget
class MyGetHttpDataState extends State<MyGetHttpData> {
  MyGetHttpDataState() {
    api = currentRestfulAPI = computeUri();
  }

  final Logging logs = Logging.logging;

  late RestfulAPI api;
  List? data;

  RestfulAPI computeUri() {
    switch (restfulApi) {
      case '${OpenWeatherMapAPI.friendlyName}':
        return OpenWeatherMapAPI();
      case '${CitiBikesNYC.friendlyName}':
        return CitiBikesNYC();
      case '${StarWars.starWarsFilms}':
      case '${StarWars.starWarsPeople}':
      case '${StarWars.starWarsPlanets}':
      case '${StarWars.starWarsSpecies}':
      case '${StarWars.starWarsStarships}':
      case '${StarWars.starWarsVehicles}':
        return StarWars(restfulApi);
      default:
        return StarWars();
    }
  }

  // Function to get the JSON data
  Future<String> getJSONData() async {
    // Encode the url
    final uri = Uri.encodeFull(api.uri());
    logs.add(uri);

    final startTime = DateTime.now();

    final response = await http.get(
      Uri.parse(uri),
      // Only accept JSON response
      headers: {'Accept': 'application/json'},
    );

    logs.add(
      'Packet received on ${response.headers['date']} '
      'content-size ${response.contentLength} bytes '
      'elapsed time ${DateTime.now().difference(startTime)}',
    );

    // To modify the state of the app, use this method
    setState(() {
      // Get the JSON data
      final dataConvertedToJSON = json.decode(response.body);
      // Extract the required part and assign it to the global variable named data
      data = api.findData(dataConvertedToJSON);
    });

    return 'Successful';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Title
        title: const Text(appName),
        actions: const <Widget>[],
        // Set the background color of the App Bar
        backgroundColor: Colors.blue,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Theme(
            // ignore: deprecated_member_use
            data: Theme.of(context),
            child: Container(
              height: 48.0,
              alignment: Alignment.center,
              child: Text(
                currentRestfulAPI.activeFriendlyName,
                style: const TextStyle(
                  fontSize: 24.0,
                  color: Colors.lightBlueAccent,
                ),
              ),
            ),
          ),
        ),
      ),
      // Create a Listview and load the data when available
      body: ListView.builder(
        itemCount: data == null ? 0 : data!.length,
        itemBuilder: (BuildContext context, int index) {
          return Center(
            child: Column(
              // Stretch the cards in horizontal axis
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Container(
                    padding: const EdgeInsets.all(15.0),
                    child: Text(
                      // Read the name field value and set it in the Text widget
                      api.display(data, index),

                      // set some style to text
                      style: const TextStyle(
                        fontSize: 20.0,
                        color: Colors.lightBlueAccent,
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Call the getJSONData() method when the app initializes
    unawaited(getJSONData());
  }
}
