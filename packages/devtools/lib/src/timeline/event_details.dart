// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../ui/elements.dart';
import '../ui/flutter_html_shim.dart';
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
    layoutVertical();
    flex();

    element.style
      ..marginTop = '6px'
      ..marginLeft = '12px';

    add(_duration = div());

    // TODO(kenzie): remove this once we can display CPU samples.
    // Adding two flex divs may not be the best way to center this text, but
    // this is fine here because the code is temporary.
    add(div()..flex());
    add(div(
      text: 'Coming soon: view CPU sampling data in this area.',
      c: 'coming-soon',
    )..flex());
    add(div()..flex());
  }

  CoreElement _duration;

  void update(TimelineEvent event) {
    attribute('hidden', false);
    _duration.text = 'Duration: ${_microsAsMsText(event.duration)}';
  }

  void reset() {
    _duration.text = '';
  }
}

String _microsAsMsText(num micros, {bool includeUnit = true}) {
  return _msAsText(micros / 1000, includeUnit: includeUnit);
}

String _msAsText(num milliseconds, {bool includeUnit = true}) {
  return '${milliseconds.toStringAsFixed(3)}${includeUnit ? ' ms' : ''}';
}
