// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:intl/intl.dart';

class Logging {
  Logging() {
    model = TimeModel(this)..start();
  }

  late final TimeModel model;

  static Logging? _theLogging;

  static Logging get logging {
    _theLogging ??= Logging();
    return _theLogging!;
  }

  final List<String> _logs = [];

  void add(String entry) {
    final TimeStamp newTimeStamp = TimeStamp.record(DateTime.now());

    _logs.add('[${model.log.length}] : ${newTimeStamp.time}] $entry');
  }

  List<String> get logs => _logs;
}

class TimeStamp {
  TimeStamp({
    time = '',
    date = '',
    meridiem = '',
  });

  factory TimeStamp.record(DateTime now) {
    return TimeStamp(
      time: currentTime.format(now),
      date: currentDate.format(now),
      meridiem: currentMeridiem.format(now),
    );
  }

  late String time;
  late String date;
  late String meridiem;

  static DateFormat currentTime = DateFormat('H:mm:ss', 'en_US');
  static DateFormat currentDate = DateFormat('EEEE, MMM d', 'en_US');
  static DateFormat currentMeridiem = DateFormat('aaa', 'en_US');
}

class TimeModel {
  TimeModel(this._logging);

  final Logging _logging;

  List<TimeStamp> log = <TimeStamp>[];

  final String _time = '';
  final String _date = '';
  final String _meridiem = '';
  Timer? _clockUpdateTimer;
  DateTime now = DateTime.now();

  /// Start updating.
  void start() {
    log.add(TimeStamp());
    _updateLog();
    _clockUpdateTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _updateLog(),
    );
  }

  /// Stop updating.
  void stop() {
    _clockUpdateTimer?.cancel();
    _clockUpdateTimer = null;
  }

  /// The current time in the ambient format.
  String get time => _time;

  /// The current date in the ambient format.
  String get date => _date;

  /// The current meridiem in the ambient format.
  String get meridiem => _meridiem;

  String get partOfDay {
    if (now.hour < 5) {
      return 'night';
    }
    if (now.hour < 12) {
      return 'morning';
    }
    if (now.hour < 12 + 5) {
      return 'afternoon';
    }
    if (now.hour < 12 + 8) {
      return 'evening';
    }
    return 'night';
  }

  void _updateLog() {
    now = DateTime.now();
    final year = now.year;

    /// Due to a bug, need to verify the date has the current year before
    /// returning a date and time.
    if (year < 2019) {
      return;
    }

    final TimeStamp newTimeStamp = TimeStamp.record(now);

    log.add(newTimeStamp);

    if (newTimeStamp.time != log.last.time ||
        newTimeStamp.date != log.last.date ||
        newTimeStamp.meridiem != log.last.meridiem) {
      _logging.add('${newTimeStamp.time} idle...');
    }
  }
}
