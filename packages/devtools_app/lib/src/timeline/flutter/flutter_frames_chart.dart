// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../flutter/controllers.dart';
import '../../ui/fake_flutter/_real_flutter.dart';
import '../timeline_controller.dart';
import '../timeline_model.dart';

class FlutterFramesChart extends StatefulWidget {
  @override
  _FlutterFramesChartState createState() => _FlutterFramesChartState();
}

class _FlutterFramesChartState extends State<FlutterFramesChart> {
  TimelineController _controller;

  List<TimelineFrame> frames = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = Controllers.of(context).timeline;
  }

  @override
  void dispose() {
    // TODO(kenz): dispose [_controller] here.
    super.dispose();
  }

  // TODO(terry): replace this temporary UI with the bar chart.
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Container(
        height: 150.0,
        child: StreamBuilder(
          // TODO(terry): we should listen to this stream to add a frame /
          // data point to the bar chart.
          stream: _controller.frameBasedTimeline.onFrameAdded,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              frames.add(snapshot.data);
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: frames.length,
                itemBuilder: (BuildContext context, int index) {
                  return _createFrameWidget(frames[index]);
                },
              );
            } else {
              return Container();
            }
          },
        ),
      ),
    );
  }

  Widget _createFrameWidget(TimelineFrame frame) {
    return InkWell(
      child: Container(
        width: 50.0,
        height: 100.0,
        color: frames.indexOf(frame) % 2 == 0
            ? Colors.blueAccent
            : Colors.lightBlueAccent,
      ),
      // TODO(terry): this should be used in onSelect for a bar chart bar.
      onTap: () => _controller.frameBasedTimeline.selectFrame(frame),
    );
  }
}
