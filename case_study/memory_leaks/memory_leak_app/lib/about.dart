// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'common.dart';

class About extends StatefulWidget {
  @override
  State<About> createState() => AboutState();
}

class AboutState extends State<About> {
  static const String heading = '$aboutMenu\n\n';
  static const String helpText = '''
This application makes Restful HTTP GET
requests to three different Restful servers.
Selecting a request e.g., Weather will
display the results of the received data on
another page. Navigating back to the main
page to select another Restful request.

The menu, on the main page, has options:
''';
  static const String logOption = '\n    $logMenu';
  static const String aboutOption = '\n    $aboutMenu';

  static const String logDescr = ' display all messages.';
  static const String aboutDescr = ' display this page.';

  final TextStyle defaultStyle = const TextStyle(
    fontSize: 20,
    color: Colors.blueGrey,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Title
        title: const Text(aboutMenu),
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        child: RichText(
          text: TextSpan(
            style: defaultStyle,
            children: const [
              TextSpan(
                text: heading,
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: helpText,
              ),
              TextSpan(
                text: logOption,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: logDescr,
              ),
              TextSpan(
                text: aboutOption,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: aboutDescr,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
