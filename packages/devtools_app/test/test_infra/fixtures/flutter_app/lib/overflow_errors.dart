// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

void main() => runApp(const OverflowingApp());

class OverflowingApp extends StatefulWidget {
  const OverflowingApp({
    Key? key,
    this.initialRoute,
    this.isTestMode = false,
  }) : super(key: key);

  final bool isTestMode;
  final String? initialRoute;

  @override
  State<OverflowingApp> createState() => _OverflowingAppState();
}

class _OverflowingAppState extends State<OverflowingApp> {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Overflowing App',
        home: Column(
          children: [
            for (var i = 0; i < 5; i++)
              const Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed'
                        ' do eiusmod tempor incididunt ut labore et dolore magna '
                        'aliqua. Ut enim ad minim veniam, quis nostrud '
                        'exercitation ullamco laboris nisi ut aliquip ex ea '
                        'commodo consequat.',
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      );
}
