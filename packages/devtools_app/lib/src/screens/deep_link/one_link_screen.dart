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

class OneLinkPage extends StatelessWidget {
  const OneLinkPage({
    super.key,
    required this.onBack,
  });

//   @override
//   State<OneLinkPage> createState() => _OneLinkPageState();
// }

// class _OneLinkPageState extends State<OneLinkPage> {
//   String responseBody = 'empty response';

//   void setResponse(String response) {
//     setState(() {
//       responseBody = response;
//     });
//   }
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // return Column(
    //   children: [
    //     //v1/packageName/com.deeplinkexperiment.android:validateAppLinkDomain
    //     FilledButton(
    //       onPressed: () async {
    //         var url = Uri.parse(
    //             'https://autopush-deeplinkassistant-pa.sandbox.googleapis.com/android/validation/v1/domain:validate?key=AIzaSyDVE6FP3GpwxgS4q8rbS7qaf6cAbxc_elc');
    //         var headers = {'Content-Type': 'application/json'};
    //         var payload = {
    //           'package_name': 'com.deeplinkexperiment.android',
    //           'app_link_domain': 'android.deeplink.store',
    //           'supplemental_sha256_cert_fingerprints': [
    //             '5A:33:EA:64:09:97:F2:F0:24:21:0F:B6:7A:A8:18:1C:18:A9:83:03:20:21:8F:9B:0B:98:BF:43:69:C2:AF:4A'
    //           ]
    //         };

    //         var response = await http.post(
    //           url,
    //           headers: headers,
    //           body: jsonEncode(payload),
    //         );
    //         setResponse(response.body);
    //         print(response.body);
    //       },
    //       child: Text('validate'),
    //     ),
    //     Text(responseBody),
    //   ],
    // );
    return ListView(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(onPressed: onBack, icon: Icon(Icons.arrow_back)),
        ),
        buildTitle('Overview', context),
        buildDataTable(context),
        Row(
          children: [
            buildCard(context),
            SizedBox(width: 8),
            buildCard(context),
          ],
        ),
        buildTitle('Checks for your website', context),
        buildWebcheckDataTable(context),
        buildTitle('Checks for your app', context),
        buildAppcheckDataTable(context),
      ],
    );
  }

  Widget buildDataTable(BuildContext context) {
    final myRow = DataRow(cells: [
      DataCell(Text('Android, IOS')),
      DataCell(Text('Http://, https://')),
      DataCell(Text('Domain.com')),
      DataCell(Text('/path/.*')),
      DataCell(Text('0')),
    ]);

    return DataTable(
      columns: [
        DataColumn(
          label: Text('OS'),
          onSort: (_, __) {},
        ),
        DataColumn(label: Text('Scheme')),
        DataColumn(label: Text('Domain')),
        DataColumn(label: Text('Path')),
        DataColumn(label: Text('issues')),
      ],
      rows: [
        myRow,
      ],
    );
  }

  Widget buildWebcheckDataTable(BuildContext context) {
    final myRow = DataRow(cells: [
      DataCell(Text('Android')),
      DataCell(Text('Digital asset link file')),
      DataCell(Text('2 check failed')),
    ]);

    return DataTable(
      columns: [
        DataColumn(label: Text('OS')),
        DataColumn(label: Text('Checks')),
        DataColumn(label: Text('issues')),
      ],
      rows: [
        myRow,
      ],
    );
  }

  Widget buildAppcheckDataTable(BuildContext context) {
    final myRow = DataRow(cells: [
      DataCell(Text('Android')),
      DataCell(Text('Intent filter')),
      DataCell(Text('1 check failed')),
    ]);

    return DataTable(
      columns: [
        DataColumn(label: Text('OS')),
        DataColumn(label: Text('Checks')),
        DataColumn(label: Text('issues')),
      ],
      rows: [
        myRow,
      ],
    );
  }
}

Widget buildTitle(String text, BuildContext context) {
  final textTheme = Theme.of(context).textTheme;
  return Text(
    text,
    style: textTheme.bodyLarge,
  );
}

Widget buildCard(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  return Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error,
            color: Colors.red, //colorScheme.error,
          ),
          SizedBox(width: 8),
          SizedBox(
            width: 206,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('(Placeholder) 20 checks failed in total for this app'),
                Text(
                  '(Placeholder) Auto fix and manual fix are both provided',
                  style: textTheme.bodyMedium,
                ),
                TextButton(onPressed: () {}, child: Text('Fix all issues')),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
