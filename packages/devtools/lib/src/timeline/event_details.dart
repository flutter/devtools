// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
import 'package:devtools/src/ui/theme.dart';

import '../ui/elements.dart';
import '../ui/fake_flutter/dart_ui/dart_ui.dart';
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
    _title = div(text: defaultTitleText, c: 'event-details-title');
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
  _Details() : super('div', classes: 'event-details') {
    layoutVertical();
    flex();

    add(_duration = div());

    // TODO(kenzie): remove this once we can display CPU samples.
    // Adding two flex divs may not be the best way to center this text, but
    // this is fine here because the code is temporary.
    add(div()..flex());
    _comingSoon = div(
      text: 'Coming soon: view CPU sampling data in this area.',
      c: 'coming-soon',
    )
      ..flex()
      ..attribute('hidden');

    if (isDarkTheme) {
      _comingSoon.element.style.color = colorToCss(Colors.white);
    }

    add(_comingSoon);
    add(div()..flex());
  }

  CoreElement _duration;
  CoreElement _comingSoon;

  void update(TimelineEvent event) {
    attribute('hidden', false);
    _duration.text = 'Duration: ${_microsAsMsText(event.duration)}';
    _comingSoon.attribute('hidden', !event.isCpuEvent);
  }

  void reset() {
    _duration.text = '';
    _comingSoon.attribute('hidden', true);
  }
}

String _microsAsMsText(num micros, {bool includeUnit = true}) {
  return _msAsText(micros / 1000, includeUnit: includeUnit);
}

String _msAsText(num milliseconds, {bool includeUnit = true}) {
  return '${milliseconds.toStringAsFixed(3)}${includeUnit ? ' ms' : ''}';
}
