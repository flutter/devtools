// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../http_request_data.dart';

class HttpRequestTimingTab extends StatelessWidget {
  const HttpRequestTimingTab(this.data);

  ExpansionTile _buildTile(String title, List<Widget> children) =>
      ExpansionTile(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        children: children,
        initiallyExpanded: true,
      );

  @override
  Widget build(BuildContext context) {
    final events = <Widget>[];
    int lastTime = data.requestTimeMicros;
    for (final instant in data.instantEvents) {
      final instantTime = data.getTimelineMicrosecondsSinceEpoch(instant);
      final timeDiffMillis = (instantTime - lastTime) / 1000;
      lastTime = instantTime;
      events.add(_buildTile(
          instant['name'], [_buildRow('Duration', '$timeDiffMillis ms')]));
    }
    events.add(
        _buildTile('Total', [_buildRow('Duration', '${data.durationMs} ms')]));

    return Padding(
      padding: const EdgeInsets.only(left: 14.0, top: 18.0),
      child: ListView(
        children: events,
      ),
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
