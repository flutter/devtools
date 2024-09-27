// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:devtools_app/src/screens/performance/panes/rebuild_stats/rebuild_stats_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rebuild counts', () {
    late RebuildCountModel rebuildCountModel;

    setUp(() {
      rebuildCountModel = RebuildCountModel();
    });

    RebuildLocation? getLocation(int locationId) {
      return rebuildCountModel.locationStats.value
          .firstWhereOrNull((entry) => entry.location.id == locationId);
    }

    RebuildLocation? getLocationForFrame({
      required int frameId,
      required int locationId,
    }) {
      return rebuildCountModel
          .rebuildsForFrame(frameId)
          ?.firstWhereOrNull((entry) => entry.location.id == locationId);
    }

    test('handle locations', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event1));
      final locations = rebuildCountModel.locationStats.value;
      expect(locations, isNotEmpty);
      expect(getLocation(9)!.location.name, 'PlanetWidget');
      expect(getLocation(9)!.buildCount, 22);
      expect(rebuildCountModel.locationMap.locationsResolved.value, isTrue);
      expect(getLocationForFrame(frameId: 1, locationId: 9)!.buildCount, 22);

      rebuildCountModel.processRebuildEvent(jsonDecode(event3));
      expect(getLocationForFrame(frameId: 1, locationId: 9)!.buildCount, 22);
      expect(getLocationForFrame(frameId: 3, locationId: 9)!.buildCount, 11);
      expect(getLocation(9)!.buildCount, 33);
      expect(rebuildCountModel.locationMap.locationsResolved.value, isTrue);

      rebuildCountModel.processRebuildEvent(jsonDecode(event2));
      expect(getLocationForFrame(frameId: 2, locationId: 9)!.buildCount, 11);
      expect(getLocation(9)!.buildCount, 44);
      expect(rebuildCountModel.locationMap.locationsResolved.value, isTrue);
    });

    test('to json', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event1));
      rebuildCountModel.processRebuildEvent(jsonDecode(event3));
      rebuildCountModel.processRebuildEvent(jsonDecode(event2));
      final json = jsonEncode(rebuildCountModel.toJson());
      rebuildCountModel = RebuildCountModel.fromJson(jsonDecode(json));

      expect(getLocation(9)!.location.name, 'PlanetWidget');
      expect(getLocation(9)!.buildCount, 44);
      expect(getLocationForFrame(frameId: 1, locationId: 9)!.buildCount, 22);
      expect(getLocationForFrame(frameId: 2, locationId: 9)!.buildCount, 11);
      expect(getLocationForFrame(frameId: 3, locationId: 9)!.buildCount, 11);
    });

    test('unknown locations', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event3));
      expect(getLocation(9)!.buildCount, 11);
      expect(rebuildCountModel.locationMap.locationsResolved.value, isFalse);

      rebuildCountModel.processRebuildEvent(jsonDecode(event2));
      expect(getLocation(9)!.buildCount, 22);
      expect(rebuildCountModel.locationMap.locationsResolved.value, isFalse);
    });

    test('clearFromRestart', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event1));
      expect(rebuildCountModel.locationStats.value, isNotEmpty);
      expect(getLocation(9)!.buildCount, 22);

      rebuildCountModel.clearFromRestart();
      expect(rebuildCountModel.locationStats.value, isEmpty);
    });

    test('clearAllCounts', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event1));
      expect(rebuildCountModel.locationStats.value, isNotEmpty);
      expect(getLocation(9)!.buildCount, 22);
      expect(rebuildCountModel.locationMap.locationsResolved.value, isTrue);
      expect(rebuildCountModel.rebuildsForLastFrame, isNotEmpty);

      rebuildCountModel.clearAllCounts();
      expect(getLocation(9), isNull);
      expect(rebuildCountModel.locationMap.locationsResolved.value, isTrue);
      expect(rebuildCountModel.rebuildsForLastFrame, isNull);
    });

    test('clearAllCounts', () {
      rebuildCountModel.processRebuildEvent(jsonDecode(event1));
      expect(rebuildCountModel.locationStats.value, isNotEmpty);
      expect(getLocation(9)!.buildCount, 22);
      expect(rebuildCountModel.locationMap.locationsResolved.value, isTrue);
      expect(rebuildCountModel.rebuildsForLastFrame, isNotEmpty);

      rebuildCountModel.clearAllCounts();
      expect(getLocation(9), isNull);
      expect(rebuildCountModel.rebuildsForLastFrame, isNull);
    });
  });
}

const event1 =
    '{"startTime":20558388,"frameNumber":1,"events":[1,1,2,1,3,1,4,1,6,1,7,2,9,22,10,22,11,22,12,22],"locations":{"file:///Users/devoncarew/projects/devoncarew/planets/lib/main.dart":{"ids":[1,2,3,4,6,7,9,10,11,12],"lines":[23,32,35,85,106,111,132,247,251,258],"columns":[10,12,13,12,18,20,18,12,14,16],"names":["PlanetsApp","MaterialApp","SolarSystemWidget","Scaffold","CustomPaint","ValueListenableBuilder","PlanetWidget","Positioned","GestureDetector","Container"]}}}';

const event2 =
    '{"startTime":21386348,"frameNumber":2,"events":[7,1,9,11,10,11,11,11,12,11]}';
const event3 =
    '{"startTime":22385849,"frameNumber":3,"events":[7,1,9,11,10,11,11,11,12,11]}';
