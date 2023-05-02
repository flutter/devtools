// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/globals.dart';
import '../../shared/primitives/auto_dispose.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/ui/icons.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class DeepLinkScreen extends Screen {
  DeepLinkScreen()
      : super.conditional(
          id: id,
          worksOffline: true,
          title: ScreenMetaData.deepLink.title,
          icon: Octicons.link,
        );

  static final id = ScreenMetaData.deepLink.id;

  @override
  String get docPageId => id;

  @override
  Widget build(BuildContext context) {
    return MyHomePage();

  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String responseBody = 'empty response';

  void setResponse(String response) {
    setState(() {
      responseBody=response;
    });
  }

  @override
  Widget build(BuildContext context) {
      return Column(
      children: [//v1/packageName/com.deeplinkexperiment.android:validateAppLinkDomain
        FilledButton(
          onPressed: () async {
            var url = Uri.parse( 
                'https://autopush-deeplinkassistant-pa.sandbox.googleapis.com/android/validation/v1/domain:validate?key=AIzaSyDVE6FP3GpwxgS4q8rbS7qaf6cAbxc_elc');
            var headers = {'Content-Type': 'application/json'};
            var payload = {
              'package_name': 'com.deeplinkexperiment.android',
              'app_link_domain': 'android.deeplink.store',
              'supplemental_sha256_cert_fingerprints': [
                '5A:33:EA:64:09:97:F2:F0:24:21:0F:B6:7A:A8:18:1C:18:A9:83:03:20:21:8F:9B:0B:98:BF:43:69:C2:AF:4A'
              ]
            };

            var response = await http.post(
              url,
              headers: headers,
              body: jsonEncode(payload),
            );
              setResponse(response.body);
            print(response.body);
          },
          child: Text('validate'),
        ),
        Text(responseBody),
      ],
    );
  }
}
