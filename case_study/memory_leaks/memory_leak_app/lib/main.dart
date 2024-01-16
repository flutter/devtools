// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';

import 'about.dart';
import 'common.dart';
import 'logging.dart';
import 'tabs/logger.dart';
import 'tabs/settings.dart';

void main() {
  Logging.logging.add('Starting...');

  runApp(
    MaterialApp(
      // Title
      title: appName,
      // Home
      home: MyHome(),
    ),
  );
}

class MyHome extends StatefulWidget {
  @override
  State<MyHome> createState() => MyHomeState();
}

/// Setup Tabs
class MyHomeState extends State<MyHome> with SingleTickerProviderStateMixin {
  // Create a tab controller
  late final TabController controller;

  @override
  void initState() {
    super.initState();

    // Initialize the Tab Controller
    controller = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    // Dispose of the Tab Controller
    controller.dispose();
    super.dispose();
  }

  /// Setup the tabs.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Appbar
      appBar: AppBar(
        // Title
        title: const Text(appName),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: showMenuSelection,
            itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
              const PopupMenuItem<String>(
                value: logMenu,
                child: Text(logMenu),
              ),
              const PopupMenuItem<String>(
                value: aboutMenu,
                child: Text(aboutMenu),
              ),
            ],
          ),
        ],

        // Set the background color of the App Bar
        backgroundColor: Colors.blue,
        // Set the bottom property of the Appbar to include a Tab Bar
      ),
      body: Settings(),
    );
  }

  void showMenuSelection(String value) {
    switch (value) {
      case logMenu:
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Logger()),
          ),
        );
        break;
      case aboutMenu:
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => About()),
          ),
        );
        break;
      default:
        print('ERROR: Unhandled Menu.');
    }
  }
}
