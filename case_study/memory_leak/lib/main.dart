import 'package:flutter/material.dart';

import 'tabs/http_data.dart';
import 'tabs/logger.dart';
import 'tabs/settings.dart';

void main() {
  runApp(MaterialApp(
      // Title
      title: 'Memory Leak',
      // Home
      home: MyHome()));
}

class MyHome extends StatefulWidget {
  @override
  MyHomeState createState() => MyHomeState();
}

/// Setup Tabs
class MyHomeState extends State<MyHome> with SingleTickerProviderStateMixin {
  // Create a tab controller
  TabController controller;

  Settings settings;

  @override
  void initState() {
    super.initState();

    // Initialize the Tab Controller
    controller = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    // Dispose of the Tab Controller
    controller.dispose();
    super.dispose();
  }

  TabBar getTabBar() {
    return TabBar(
      tabs: <Tab>[
        Tab(
          // set icon to the tab
          icon: Icon(Icons.wifi),
        ),
        Tab(
          icon: Icon(Icons.build),
        ),
        Tab(
          icon: Icon(Icons.bug_report),
        ),
      ],
      // setup the controller
      controller: controller,
    );
  }

  TabBarView getTabBarView(var tabs) {
    return TabBarView(
      // Add tabs as widgets
      children: tabs,
      // Set the controller
      controller: controller,
    );
  }

  /// Setup the tabs.
  @override
  Widget build(BuildContext context) {
    settings = Settings();
    return Scaffold(
        // Appbar
        appBar: AppBar(
            // Title
            title: const Text('Memory Leak'),
            // Set the background color of the App Bar
            backgroundColor: Colors.blue,
            // Set the bottom property of the Appbar to include a Tab Bar
            bottom: getTabBar()),
        // Set the TabBar view as the body of the Scaffold
        body: getTabBarView(<Widget>[MyGetHttpData(), settings, Logger()]));
  }
}
