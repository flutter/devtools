// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:recase/recase.dart';

import '../http_request_data.dart';

class HttpRequestHeadersTab extends StatelessWidget {
  const HttpRequestHeadersTab(this.data);

  ExpansionTile _buildTile(String title, List<Widget> children) =>
      ExpansionTile(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        children: children,
        initiallyExpanded: true,
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        _buildTile(
          'General',
          <Widget>[
            for (final entry in data.general.entries)
              _buildRow(
                ReCase(entry.key).titleCase,
                entry.value.toString(),
              ),
          ],
        ),
        _buildTile(
          'Response Headers',
          <Widget>[
            if (data.responseHeaders != null)
              for (final entry in data.responseHeaders.entries)
                _buildRow(
                  entry.key,
                  entry.value.toString(),
                ),
          ],
        ),
        _buildTile(
          'Request Headers',
          <Widget>[
            if (data.requestHeaders != null)
              for (final entry in data.requestHeaders.entries)
                _buildRow(
                  entry.key,
                  entry.value.toString(),
                )
          ],
        )
      ],
    );
  }

  Widget _buildRow(String key, dynamic value) {
    return Container(
      padding: const EdgeInsets.only(
        left: 30,
        bottom: 15,
      ),
      child: Column(children: [
        Row(
          children: <Widget>[
            Text(
              '$key: ',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(value),
          ],
        ),
      ]),
    );
  }

  final HttpRequestData data;
}
