// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:convert';

import 'package:devtools_app/src/screens/performance/rebuild_counts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rebuild counts', () {
    RebuildCountModel rebuildCountModel;

    setUp(() {
      rebuildCountModel = RebuildCountModel();
    });

    RebuildLocation getLocation(int id) {
      return rebuildCountModel.locations.value
          .firstWhere((location) => location.id == id);
    }

    test('handle new locations', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event1));
      final locations = rebuildCountModel.locations.value;
      expect(locations, isNotEmpty);
      expect(getLocation(9).name, 'PlanetWidget');
      expect(getLocation(9).buildCount, 22);

      rebuildCountModel.processRebuildEvent(jsonDecode(event3));
      expect(getLocation(9).buildCount, 33);

      rebuildCountModel.processRebuildEvent(jsonDecode(event2));
      expect(getLocation(9).buildCount, 44);
    });

    test('handle old locations', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event1_old));
      final locations = rebuildCountModel.locations.value;
      expect(locations, isNotEmpty);
      expect(getLocation(9).name, 'main.dart:132');
      expect(getLocation(9).buildCount, 22);

      rebuildCountModel.processRebuildEvent(jsonDecode(event3));
      expect(getLocation(9).buildCount, 33);

      rebuildCountModel.processRebuildEvent(jsonDecode(event2));
      expect(getLocation(9).buildCount, 44);
    });

    test('clearFromReload', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event1));
      expect(rebuildCountModel.locations.value, isNotEmpty);
      expect(getLocation(9).buildCount, 22);

      rebuildCountModel.clearFromReload();
      expect(rebuildCountModel.locations.value, isEmpty);
    });

    test('clearCurrentCounts', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event1));
      expect(rebuildCountModel.locations.value, isNotEmpty);
      expect(getLocation(9).buildCount, 22);

      rebuildCountModel.clearCurrentCounts();
      expect(getLocation(9).buildCount, 0);
    });
  });
}

const event1 =
    '{"startTime":20558388,"events":[1,1,2,1,3,1,4,1,6,1,7,2,9,22,10,22,11,22,12,22],"locations":{"file:///Users/devoncarew/projects/devoncarew/planets/lib/main.dart":{"ids":[1,2,3,4,6,7,9,10,11,12],"lines":[23,32,35,85,106,111,132,247,251,258],"columns":[10,12,13,12,18,20,18,12,14,16],"names":["PlanetsApp","MaterialApp","SolarSystemWidget","Scaffold","CustomPaint","ValueListenableBuilder","PlanetWidget","Positioned","GestureDetector","Container"]}}}';
const event1_old =
    '{"startTime":20558388,"events":[1,1,2,1,3,1,4,1,6,1,7,2,9,22,10,22,11,22,12,22],"newLocations":{"file:///Users/devoncarew/projects/devoncarew/planets/lib/main.dart":[1,23,10,2,32,12,3,35,13,4,85,12,6,106,18,7,111,20,9,132,18,10,247,12,11,251,14,12,258,16]}}';
const event2 = '{"startTime":21386348,"events":[7,1,9,11,10,11,11,11,12,11]}';
const event3 = '{"startTime":22385849,"events":[7,1,9,11,10,11,11,11,12,11]}';
