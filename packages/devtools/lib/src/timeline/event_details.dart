// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/elements.dart';
import '../ui/flutter_html_shim.dart';
import '../utils.dart';
import 'frame_flame_chart.dart';
import 'timeline_protocol.dart';

class EventDetails extends CoreElement {
  EventDetails() : super('div', classes: 'section-border') {
    flex();
    layoutVertical();

    addTitle();
    addDetails();
  }

  static const defaultTitleText = 'Event Details - [no event selected]';

  TimelineEvent _event;
  CoreElement _title;
  _Details _details;

  void addTitle() {
    const horizontalPadding = '12px';
    const verticalPadding = '3px';

    _title = div(text: defaultTitleText);
    _title.element.style
      ..fontWeight = 'bold'
      ..padding = '$verticalPadding $horizontalPadding';
    add(_title);
  }

  void addDetails() {
    _details = _Details()..attribute('hidden');
    add(_details);
  }

  void update(FlameChartItem item) {
    _event = item.event;

    // Update title.
    _title.text = '${_event.name}';
    _title.element.style.backgroundColor = colorToCss(item.backgroundColor);

    // Update details.
    _details.update(item.event);
  }

  void reset() {
    _title.text = defaultTitleText;
    _title.element.style.backgroundColor = 'transparent';
    _details.reset();
  }
}

class _Details extends CoreElement {
  _Details() : super('div') {
    element.style
      ..marginTop = '6px'
      ..marginLeft = '12px';

    add(_duration = div());

    // TODO(kenzie): query vm for samples.
  }

  CoreElement _duration;

  void update(TimelineEvent event) {
    attribute('hidden', false);
    _duration.text = 'Duration:'
        ' ${microsAsMsText(event.duration)} - '
        '[${event.startTime} - ${event.endTime}]';
  }

  void reset() {
    _duration.text = '';
  }
}
