// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'http.dart';

extension HttpCookie on Cookie {
  static List<Cookie> parseCookies(List cookies) {
    return [for (final cookie in cookies) Cookie.fromSetCookieValue(cookie)];
  }
}

// TODO(bkonyi): handle in-progress events which are completed while we're paused.
class HttpRequests {
  List<HttpRequestData> requests = [];
  final Map<String, HttpRequestData> outstanding = {};

  void clear() {
    requests.clear();
    outstanding.clear();
  }
}

class HttpRequestData {
  HttpRequestData._(this._timelineMicrosBase, this._startEvent, this.endEvent,
      this._instantEvents);

  factory HttpRequestData.fromTimeline(
      int timelineMicrosBase, List<Map> events) {
    Map startEvent;
    Map endEvent;
    final instantEvents = <Map>[];

    for (final event in events) {
      if (_isStartEvent(event)) {
        assert(startEvent == null);
        startEvent = event;
      } else if (_isEndEvent(event)) {
        assert(endEvent == null);
        endEvent = event;
      } else if (_isInstantEvent(event)) {
        instantEvents.add(event);
      } else {
        assert(false, 'Unexpected event type');
      }
    }

    return HttpRequestData._(
        timelineMicrosBase, startEvent, endEvent, instantEvents);
  }

  static bool _isStartEvent(Map event) => event['ph'] == 'b';
  static bool _isEndEvent(Map event) => event['ph'] == 'e';
  static bool _isInstantEvent(Map event) => event['ph'] == 'n';

  int getTimelineMicrosecondsSinceEpoch(Map event) {
    assert(event.containsKey('ts'));
    return _timelineMicrosBase + event['ts'];
  }

  bool get hasCookies =>
      requestCookies.isNotEmpty || responseCookies.isNotEmpty;

  List<Cookie> get requestCookies {
    final headers = requestHeaders;
    if (headers == null) {
      return [];
    }
    return HttpCookie.parseCookies(headers['cookie'] ?? []);
  }

  List<Cookie> get responseCookies {
    final headers = responseHeaders;
    if (headers == null) {
      return [];
    }
    return HttpCookie.parseCookies(headers['set-cookie'] ?? []);
  }

  bool get inProgress => endEvent == null;

  Uri get uri {
    assert(_startEvent['args'].containsKey('uri'));
    return Uri.parse(_startEvent['args']['uri']);
  }

  int get status {
    int statusCode;
    if (endEvent != null) {
      final endArgs = endEvent['args'];
      if (endArgs.containsKey('error')) {
        // TODO(bkonyi): get proper status codes from error. Assume connection
        // refused (502) for now.
        statusCode = 502;
      } else {
        statusCode = endArgs['statusCode'];
      }
    }
    return statusCode;
  }

  double get durationMs {
    if (endEvent == null) {
      return null;
    }
    // Timestamps are in microseconds
    double millis = (endEvent['ts'] - _startEvent['ts']) / 1000;
    if (millis >= 1.0) {
      millis = millis.truncateToDouble();
    }
    return millis;
  }

  int get requestTimeMicros {
    assert(_startEvent != null);
    return getTimelineMicrosecondsSinceEpoch(_startEvent);
  }

  DateTime get requestTime {
    assert(_startEvent != null);
    return DateTime.fromMicrosecondsSinceEpoch(
        getTimelineMicrosecondsSinceEpoch(_startEvent));
  }

  String get name => uri.toString();

  String get method {
    assert(_startEvent['args'].containsKey('method'));
    return _startEvent['args']['method'];
  }

  Map get general {
    final copy = Map.from(_startEvent['args']);
    if (endEvent != null) {
      copy.addAll(endEvent['args']);
    }
    copy.remove('requestHeaders');
    copy.remove('responseHeaders');
    copy.remove('filterKey');
    return copy;
  }

  Map get requestHeaders {
    if (endEvent == null) {
      return null;
    }
    return endEvent['args']['requestHeaders'];
  }

  Map get responseHeaders {
    if (endEvent == null) {
      return null;
    }
    return endEvent['args']['responseHeaders'];
  }

  List<Map> get instantEvents => _instantEvents;

  final int _timelineMicrosBase;
  final Map _startEvent;
  Map endEvent;
  final List<Map> _instantEvents;

  bool selected = false;
}
