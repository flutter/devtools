// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';

/*
import 'dart:async';
import 'package:vm_service/vm_service.dart';

import 'config_specific/logger.dart';
import 'core/message_bus.dart';
import 'globals.dart';
// TODO(jacobr): evaluate whether to obsolete this class or port it.
//import 'model/model.dart';
import 'service_registrations.dart' as registrations;

import 'ui/icons.dart';
import 'utils.dart';

 */

void main() {
  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

  runApp(DevToolsApp());
}

class DevToolsApp extends StatefulWidget {
  @override
  _DevToolsAppState createState() => _DevToolsAppState();
}

class _DevToolsAppState extends State<DevToolsApp> {
  @override
  Widget build(BuildContext context) {
    // Placeholder DevTools app creating tabs without any real content.
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            bottom: TabBar(
              tabs: [
                Tab(
                  text: 'Flutter Inspector',
                  icon: Icon(Icons.directions_car),
                ),
                Tab(
                  text: 'Timeline',
                  icon: Icon(Icons.directions_transit),
                ),
                Tab(
                  text: 'Logging',
                  icon: Icon(Icons.directions_bike),
                ),
              ],
            ),
            title: const Text('Dart DevTools'),
          ),
          body: TabBarView(
            children: [
              Icon(Icons.directions_car),
              Icon(Icons.directions_transit),
              Icon(Icons.directions_bike),
            ],
          ),
        ),
      ),
    );
  }
}
