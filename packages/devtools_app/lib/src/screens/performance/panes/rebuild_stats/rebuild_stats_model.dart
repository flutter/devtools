// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

// An example of a widget rebuild count event:

// {
//   "startTime": 2352949,
//   "frameNumber": 57,
//   "events": [1, 1, 2, 1, ...],
//   "locations": {
//     "file": {
//       "ids": [1, 2, ...],
//       "lines": [23, 32, ...],
//       "columns": [10, 12, ...],
//       "names": ["PlanetsApp", "MaterialApp", ...]
//     }
//   },
// }

class _RebuildCountStats {
  ValueListenable<List<RebuildLocation>> get locations => _locations;
  final _locations = ListValueNotifier<RebuildLocation>(<RebuildLocation>[]);

  final _rebuildLocationMap = <int, RebuildLocation>{};

  /// Increment the count associated with the [location] by [value].
  void incrementCount(Location location, int value) {
    final id = location.id;
    final existing = _rebuildLocationMap[id];
    if (existing != null) {
      existing.buildCount += value;
    } else {
      final rebuildLocation = RebuildLocation(location, buildCount: value);
      _locations.add(rebuildLocation);
      _rebuildLocationMap[id] = rebuildLocation;
    }
  }

  void clear() {
    _locations.clear();
    _rebuildLocationMap.clear();
  }

  void dataChanged() {
    _locations.notifyListeners();
  }
}

const _idsKey = 'ids';
const _linesKey = 'lines';
const _columnsKey = 'columns';
const _namesKey = 'names';
const _framesKey = 'frames';
const _locationsKey = 'locations';
const _frameNumberKey = 'frameNumber';
const _eventsKey = 'events';

/// Mapping from ids to [Location] objects.
///
/// Some Locations may be unresolved with ids but no valid path while valid
/// paths are being fetched from the running Flutter application.
class LocationMap {
  LocationMap();

  final _locationMap = <int, Location>{};

  int _countUnknownLocations = 0;

  void clear() {
    _countUnknownLocations = 0;
    _locationMap.clear();
  }

  ValueListenable<bool> get locationsResolved => _locationsResolved;
  final _locationsResolved = ValueNotifier(true);

  Location operator [](int id) {
    var location = _locationMap[id];
    if (location == null) {
      _countUnknownLocations++;
      _locationsResolved.value = false;
      // Add a placeholder location until we receive an event with the
      // path + line + column for the location.
      _locationMap[id] = location = Location(id: id);
    }
    return location;
  }

  Map<String, Object> toJson() {
    final json = <String, Object>{};
    final pathToLocations = <String, List<Location>>{};
    for (var location in _locationMap.values) {
      if (location.isResolved) {
        pathToLocations
            .putIfAbsent(location.fileUriString!, () => <Location>[])
            .add(location);
      }
    }
    pathToLocations.forEach((path, locations) {
      final ids = <int>[];
      final lines = <int>[];
      final columns = <int>[];
      final names = <String>[];
      for (var location in locations) {
        ids.add(location.id);
        lines.add(location.line!);
        columns.add(location.column!);
        names.add(location.name!);
      }
      json[path] = {
        _idsKey: ids,
        _linesKey: lines,
        _columnsKey: columns,
        _namesKey: names,
      };
    });
    return json;
  }

  void processLocationMap(Map<String, dynamic> json) {
    for (final String path in json.keys) {
      final entries = (json[path]! as Map).cast<String, List<Object?>>();

      final ids = entries[_idsKey]!.cast<int>();
      final lines = entries[_linesKey]!.cast<int>();
      final columns = entries[_columnsKey]!.cast<int>();
      final names = entries[_namesKey]!.cast<String>();

      for (var i = 0; i < ids.length; i++) {
        final id = ids[i];
        final existing = _locationMap[id];
        if (existing != null) {
          if (existing.fileUriString == null) {
            // Fill in the empty placeholder location in _locationsMap for this
            // location id. The empty placeholder entry must be completely empty.
            existing.fileUriString = path;
            assert(existing.line == null);
            existing.line = lines[i];
            assert(existing.column == null);
            existing.column = columns[i];
            assert(existing.name == null);
            existing.name = names[i];
            _countUnknownLocations--;
          } else {
            // Existing entry already has a path. Ensure it is consistent.
            // Data could become inconsistent if we had a bug and comingled data
            // from before and after a hot restart.
            assert(existing.fileUriString == path);
            assert(existing.line == lines[i]);
            assert(existing.column == columns[i]);
            assert(existing.name == names[i]);
          }
        } else {
          final location = Location(
            id: id,
            fileUriString: path,
            line: lines[i],
            column: columns[i],
            name: names[i],
          );

          _locationMap[ids[i]] = location;
        }
      }
    }

    _locationsResolved.value = _countUnknownLocations == 0;
  }
}

class RebuildCountModel {
  RebuildCountModel();

  RebuildCountModel.fromJson(Map<String, Object?> json) {
    if (json.isEmpty) return;
    locationMap.processLocationMap(json[_locationsKey] as Map<String, Object?>);
    final frames =
        (json[_framesKey] as List<Object?>).cast<Map<String, Object?>>();
    frames.forEach(processRebuildsForFrame);
  }

  // Maximum number of historic frames to keep rebuild counts to ensure memory
  // usage from rebuild counts is not excessive.
  static const int rebuildFrameCacheSize = 10000;

  /// Source of truth for all resolution fo location ids to [Location] objects.
  final locationMap = LocationMap();

  /// Map from frame id to list of rebuilds for the frame.
  final _rebuildsForFrame = <int, List<RebuildLocation>>{};

  final _stats = _RebuildCountStats();
  ValueListenable<List<RebuildLocation>> get locationStats => _stats.locations;

  List<RebuildLocation>? get rebuildsForLastFrame =>
      _rebuildsForFrame.values.lastOrNull;

  List<RebuildLocation>? rebuildsForFrame(int frameNumber) {
    return _rebuildsForFrame[frameNumber];
  }

  bool get isNotEmpty => _rebuildsForFrame.isNotEmpty;

  Map<String, Object?>? toJson() {
    if (_rebuildsForFrame.isEmpty) {
      // No need to encode data unless there were actually rebuilds reported.
      return null;
    }
    final frames = <Object>[];

    _rebuildsForFrame.forEach((id, rebuilds) {
      final events = <int>[];
      for (RebuildLocation rebuild in rebuilds) {
        events
          ..add(rebuild.location.id)
          ..add(rebuild.buildCount);
      }
      frames.add({_frameNumberKey: id, _eventsKey: events});
    });
    return <String, Object?>{
      _locationsKey: locationMap.toJson(),
      _framesKey: frames,
    };
  }

  void processRebuildEvent(Map<String, dynamic> json) {
    // parse locations
    if (json.containsKey(_locationsKey)) {
      locationMap
          .processLocationMap(json[_locationsKey] as Map<String, dynamic>);
    }

    processRebuildsForFrame(json);

    // We've updated the build counts and possibly the locations.
    _stats.dataChanged();
  }

  void clearFromRestart() {
    clearAllCounts();
    locationMap.clear();
  }

  void clearAllCounts() {
    _stats.clear();
    _rebuildsForFrame.clear();
  }

  void processRebuildsForFrame(Map<String, dynamic> json) {
    if (json[_frameNumberKey] == null) {
      // Old version of the rebuild JSON that is not supported by DevTools.
      return;
    }

    final int frameNumber = json[_frameNumberKey];
    // parse events
    final List<int> events = (json[_eventsKey] as List).cast<int>();
    final rebuildsForFrame = <RebuildLocation>[];
    for (int i = 0; i < events.length; i += 2) {
      final id = events[i];
      final count = events[i + 1];

      final location = locationMap[id];
      rebuildsForFrame.add(RebuildLocation(location, buildCount: count));
      _stats.incrementCount(location, count);
    }
    _rebuildsForFrame[frameNumber] = rebuildsForFrame;
    while (_rebuildsForFrame.length > rebuildFrameCacheSize) {
      _rebuildsForFrame.remove(_rebuildsForFrame.keys.first);
    }
  }
}

class Location {
  Location({
    required this.id,
    this.fileUriString,
    this.line,
    this.column,
    this.name,
  });

  final int id;

  /// Either all of path, line, column, and name are null or none are.
  String? fileUriString;
  int? line;
  int? column;
  String? name;

  bool get isResolved => fileUriString != null;
}

class RebuildLocation {
  RebuildLocation(this.location, {this.buildCount = 0});
  final Location location;
  int buildCount;
}

/// Helper class to merge together rebuild stats from multiple sources.
///
/// For example, rebuild on a per frame basis and total rebuilds since
/// the last route change.
class RebuildLocationStats {
  RebuildLocationStats(this.location, {required int numStats})
      : buildCounts = List<int>.filled(numStats, 0);
  final Location location;
  final List<int> buildCounts;
}

List<RebuildLocationStats> combineStats(
  List<List<RebuildLocation>> rebuildStats,
) {
  final numStats = rebuildStats.length;
  final output = <Location, RebuildLocationStats>{};
  for (int i = 0; i < rebuildStats.length; i++) {
    final statsForIndex = rebuildStats[i];
    for (var entry in statsForIndex) {
      output
          .putIfAbsent(
            entry.location,
            () => RebuildLocationStats(
              entry.location,
              numStats: numStats,
            ),
          )
          .buildCounts[i] = entry.buildCount;
    }
  }
  return output.values.toList(growable: false);
}
