// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:recase/recase.dart';

import '../http_request_data.dart';

/// This widget displays general HTTP request / response information that is
/// contained in the headers, in addition to the standard connection information.
class HttpRequestHeadersView extends StatelessWidget {
  const HttpRequestHeadersView(this.data);

  final HttpRequestData data;

  ExpansionTile _buildTile(String title, List<Widget> children) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      children: children,
      initiallyExpanded: true,
    );
  }

  Widget _buildRow(String key, dynamic value, constraints) {
    return Container(
      width: constraints.minWidth,
      padding: const EdgeInsets.only(
        left: 30,
        bottom: 15,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$key: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
              child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            maxLines: 5,
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          children: [
            _buildTile(
              'General',
              [
                for (final entry in data.general.entries)
                  _buildRow(
                    ReCase(entry.key).titleCase,
                    entry.value.toString(),
                    constraints,
                  ),
              ],
            ),
            _buildTile(
              'Response Headers',
              [
                if (data.responseHeaders != null)
                  for (final entry in data.responseHeaders.entries)
                    _buildRow(
                      entry.key,
                      entry.value.toString(),
                      constraints,
                    ),
              ],
            ),
            _buildTile(
              'Request Headers',
              [
                if (data.requestHeaders != null)
                  for (final entry in data.requestHeaders.entries)
                    _buildRow(
                      entry.key,
                      entry.value.toString(),
                      constraints,
                    ),
              ],
            )
          ],
        );
      },
    );
  }
}
