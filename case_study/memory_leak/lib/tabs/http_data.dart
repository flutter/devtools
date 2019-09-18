import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../logging.dart';
import '../restful_servers.dart';
import 'settings.dart';

/// Create a stateful widget
class MyGetHttpData extends StatefulWidget {
  @override
  MyGetHttpDataState createState() => MyGetHttpDataState();
}

// Create the state for our stateful widget
class MyGetHttpDataState extends State<MyGetHttpData> {
  MyGetHttpDataState() {
    api = computeUri();
    currentRestfulAPI?.next = api;
    currentRestfulAPI = api;
  }

  final Logging logs = Logging.logging;

  RestfulAPI api;
  List data;

  RestfulAPI computeUri() {
    switch (restfulApi) {
      case 'Weather':
        return OpenWeatherMapAPI();
      case 'NYC Bike Sharing':
        return CitiBikesNYC();
      case 'StarWars Films':
        return StarWars(0);
      case 'StarWars People':
        return StarWars(1);
      case 'StarWars Planets':
        return StarWars(2);
      case 'StarWars Species':
        return StarWars(3);
      case 'StarWars Starships':
        return StarWars(4);
      case 'StarWars Vehicles':
        return StarWars(5);
      default:
        return StarWars();
    }
  }

  // Function to get the JSON data
  Future<String> getJSONData() async {
    logs.add(api.uri());

    final startTime = DateTime.now();

    final response = await http.get(
        // Encode the url
        Uri.encodeFull(api.uri()),
        // Only accept JSON response
        headers: {'Accept': 'application/json'});

    logs.add('Packet received on ${response.headers['date']} '
        'content-size ${response.contentLength} bytes '
        'elapsed time ${DateTime.now().difference(startTime)}');

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
        title: const Text('Retrieve JSON Data via HTTP GET'),
      ),
      // Create a Listview and load the data when available
      body: ListView.builder(
          itemCount: data == null ? 0 : data.length,
          itemBuilder: (BuildContext context, int index) {
            return Container(
              child: Center(
                  child: Column(
                // Stretch the cards in horizontal axis
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Card(
                    child: Container(
                      child: Text(
                        // Read the name field value and set it in the Text widget
                        api?.display(data, index),

                        // set some style to text
                        style: TextStyle(
                            fontSize: 20.0, color: Colors.lightBlueAccent),
                      ),
                      // added padding
                      padding: const EdgeInsets.all(15.0),
                    ),
                  )
                ],
              )),
            );
          }),
    );
  }

  @override
  void initState() {
    super.initState();

    // Call the getJSONData() method when the app initializes
    getJSONData();
  }
}
