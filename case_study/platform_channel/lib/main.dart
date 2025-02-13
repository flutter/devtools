// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
import 'dart:async';

import 'package:flutter/material.dart';

import 'channel_demo.dart';

void main() => runApp(const MyApp());

const platformChannelTitle = 'Platform Channel Demo';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: _HomePage(),
    );
  }
}

class _HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(platformChannelTitle),
      ),
      body: Center(
        child: TextButton(
          style: TextButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () {
            unawaited(
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChannelDemo()),
              ),
            );
          },
          child: const Text(
            platformChannelTitle,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
