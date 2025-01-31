// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:flutter/material.dart';

import 'common.dart';

class About extends StatefulWidget {
  // ignore: prefer_const_constructors_in_immutables, intentional example code.
  About({super.key});

  @override
  State<About> createState() => AboutState();
}

class AboutState extends State<About> {
  static const heading = '$aboutMenu\n\n';
  static const helpText = '''
This application makes Restful HTTP GET
requests to three different Restful servers.
Selecting a request e.g., Weather will
display the results of the received data on
another page. Navigating back to the main
page to select another Restful request.

The menu, on the main page, has options:
''';
  static const logOption = '\n    $logMenu';
  static const aboutOption = '\n    $aboutMenu';

  static const logDescr = ' display all messages.';
  static const aboutDescr = ' display this page.';

  final defaultStyle = const TextStyle(
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
