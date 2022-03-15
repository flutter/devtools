// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../primitives/utils.dart';

// An example of a widget rebuild count event:

// {
//   "startTime": 2352949,
//   "events": [1, 1, 2, 1, ...],
//   "locations": {
//     "file": {
//       "ids": [1, 2, ...],
//       "lines": [23, 32, ...],
//       "columns": [10, 12, ...],
//       "names": ["PlanetsApp", "MaterialApp", ...]
//     }
//   },
//   "newLocations": {
//     "file": [id1, line1, column1, id2, line2, column2, ...],
//     }
//   }
// }

class RebuildCountModel {
  final Map<int, RebuildLocation> _locationMap = <int, RebuildLocation>{};

  final _locations = ListValueNotifier<RebuildLocation>(<RebuildLocation>[]);

  ValueListenable<List<RebuildLocation>> get locations => _locations;

  void processRebuildEvent(Map<String, dynamic> json) {
    // parse locations
    if (json.containsKey('locations')) {
      final fileLocationsMap =
          (json['locations'] as Map).cast<String, dynamic>();

      for (final String file in fileLocationsMap.keys) {
        final entries =
            (fileLocationsMap[file] as Map).cast<String, List<dynamic>>();

        final ids = entries['ids']!.cast<int>();
        final lines = entries['lines']!.cast<int>();
        final columns = entries['columns']!.cast<int>();
        final names = entries['names']!.cast<String>();

        for (var i = 0; i < ids.length; i++) {
          final location = RebuildLocation(
            id: ids[i],
            path: file,
            line: lines[i],
            column: columns[i],
            name: names[i],
          );
          _locationMap[ids[i]] = location;
          _locations.add(location);
        }
      }
    } else if (json.containsKey('newLocations')) {
      // Fall back to the older 'newLocations' field.
      final fileLocationsMap =
          (json['newLocations'] as Map).cast<String, dynamic>();

      for (final file in fileLocationsMap.keys) {
        final List<int> entries = (fileLocationsMap[file] as List).cast<int>();

        final shortName = path.posix.split(file).last;

        final len = entries.length ~/ 3;
        for (var i = 0; i < (len * 3); i += 3) {
          final id = entries[i];
          final line = entries[i + 1];
          final location = RebuildLocation(
            id: id,
            path: file,
            line: line,
            column: entries[i + 2],
            name: '$shortName:$line',
          );
          _locationMap[id] = location;
          _locations.add(location);
        }
      }
    }

    // parse events
    final List<int> events = (json['events'] as List).cast<int>();
    for (int i = 0; i < events.length; i += 2) {
      final id = events[i];
      final count = events[i + 1];

      final location = _locationMap[id];
      location?.buildCount += count;
    }

    // We've updated the build counts and possibly the locations.
    _locations.notifyListeners();
  }

  void clearFromReload() {
    // TODO(devoncarew): We need to call this when we see a hot reload or restart.

    _locationMap.clear();
    _locations.clear();
  }

  void clearCurrentCounts() {
    for (final location in _locationMap.values) {
      location.buildCount = 0;
    }

    // We've updated the build counts.
    _locations.notifyListeners();
  }
}

class RebuildLocation {
  RebuildLocation({this.id, this.path, this.line, this.column, this.name});

  final int? id;
  final String? path;
  final int? line;
  final int? column;
  final String? name;

  int buildCount = 0;
}
