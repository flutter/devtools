// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:mime/mime.dart';
import 'package:vm_service/vm_service.dart';

import '../../screens/network/network_model.dart';
import '../globals.dart';
import '../primitives/utils.dart';
import 'http.dart';

final _log = Logger('http_request_data');

/// Used to represent an instant event emitted during an HTTP request.
class DartIOHttpInstantEvent {
  DartIOHttpInstantEvent._(this._event);

  final HttpProfileRequestEvent _event;

  String get name => _event.event;

  /// The time the instant event was recorded.
  int get timestampMicros => _event.timestamp;

  /// The amount of time since the last instant event completed.
  TimeRange? get timeRange => _timeRange;

  // This is set from within HttpRequestData.
  TimeRange? _timeRange;
}

/// An abstraction of an HTTP request made through dart:io.
class DartIOHttpRequestData extends NetworkRequest {
  DartIOHttpRequestData(
    int timelineMicrosBase,
    this._request, {
    bool requestFullDataFromVmService = true,
  }) : super(timelineMicrosBase) {
    if (requestFullDataFromVmService && _request.isResponseComplete) {
      unawaited(getFullRequestData());
    }
  }

  static const _connectionInfoKey = 'connectionInfo';
  static const _contentTypeKey = 'content-type';
  static const _localPortKey = 'localPort';

  HttpProfileRequestRef _request;

  final ValueNotifier<int> _updateCount = ValueNotifier<int>(0);

  /// A notifier that changes when the request data, or it's response body
  /// changes.
  ValueListenable<void> get requestUpdatedNotifier => _updateCount;
  bool isFetchingFullData = false;

  Future<void> getFullRequestData() async {
    try {
      if (isFetchingFullData) return; // We are already fetching
      isFetchingFullData = true;
      final updated = await serviceConnection.serviceManager.service!
          .getHttpProfileRequestWrapper(
        _request.isolateId,
        _request.id.toString(),
      );
      _request = updated;
      _updateCount.value++;
      final fullRequest = _request as HttpProfileRequest;
      _responseBody = utf8.decode(fullRequest.responseBody!);
      _requestBody = utf8.decode(fullRequest.requestBody!);
    } finally {
      isFetchingFullData = false;
    }
  }

  static List<Cookie> _parseCookies(List<String>? cookies) {
    if (cookies == null) return [];
    return cookies.map((cookie) => Cookie.fromSetCookieValue(cookie)).toList();
  }

  @override
  String get id => _request.id;

  bool get _hasError => _request.request?.hasError ?? false;

  int? get _endTime =>
      _hasError ? _request.endTime : _request.response?.endTime;

  @override
  Duration? get duration {
    if (inProgress || !isValid) return null;
    // Timestamps are in microseconds
    final range = TimeRange()
      ..start = Duration(microseconds: _request.startTime)
      ..end = Duration(microseconds: _endTime!);
    return range.duration;
  }

  /// Whether the request is safe to display in the UI.
  ///
  /// The dart:io HTTP profiling service extensions should never return invalid
  /// requests.
  bool get isValid => true;

  /// A map of general information associated with an HTTP request.
  Map<String, dynamic> get general {
    return {
      'method': _request.method,
      'uri': _request.uri.toString(),
      if (!didFail) ...{
        'connectionInfo': _request.request?.connectionInfo,
        'contentLength': _request.request?.contentLength,
      },
      if (_request.response != null) ...{
        'compressionState': _request.response!.compressionState,
        'isRedirect': _request.response!.isRedirect,
        'persistentConnection': _request.response!.persistentConnection,
        'reasonPhrase': _request.response!.reasonPhrase,
        'redirects': _request.response!.redirects,
        'statusCode': _request.response!.statusCode,
      },
    };
  }

  @override
  String? get contentType {
    final headers = responseHeaders;
    if (headers == null || headers[_contentTypeKey] == null) {
      return null;
    }
    return headers[_contentTypeKey].toString();
  }

  @override
  String get type {
    var mime = contentType;
    if (mime == null) return 'http';

    // Extract the MIME from `contentType`.
    // Example: "[text/html; charset-UTF-8]" --> "text/html"
    mime = mime.split(';').first;
    if (mime.startsWith('[')) {
      mime = mime.substring(1);
    }
    if (mime.endsWith(']')) {
      mime = mime.substring(0, mime.length - 1);
    }
    return _extensionFromMime(mime);
  }

  /// Extracts the extension from [mime], with overrides for shortened
  /// extenstions of common types (e.g., jpe -> jpeg).
  String _extensionFromMime(String mime) {
    final extension = extensionFromMime(mime);
    if (extension == 'jpe') {
      return 'jpeg';
    }
    if (extension == 'htm') {
      return 'html';
    }
    // text/plain -> conf
    if (extension == 'conf') {
      return 'txt';
    }
    return extension;
  }

  @override
  String get method => _request.method;

  @override
  int? get port {
    final Map<String, dynamic>? connectionInfo = general[_connectionInfoKey];
    return connectionInfo != null ? connectionInfo[_localPortKey] : null;
  }

  /// True if the HTTP request hasn't completed yet, determined by the lack of
  /// an end time in the response data.
  @override
  bool get inProgress =>
      _hasError ? !_request.isRequestComplete : !_request.isResponseComplete;

  /// All instant events logged to the timeline for this HTTP request.
  List<DartIOHttpInstantEvent> get instantEvents {
    if (_instantEvents == null) {
      _instantEvents = [
        for (final event in _request.request?.events ?? [])
          DartIOHttpInstantEvent._(event),
      ];
      _recalculateInstantEventTimes();
    }
    return _instantEvents!;
  }

  List<DartIOHttpInstantEvent>? _instantEvents;

  /// True if either the request or response contained cookies.
  bool get hasCookies =>
      requestCookies.isNotEmpty || responseCookies.isNotEmpty;

  /// A list of all cookies contained within the request headers.
  List<Cookie> get requestCookies => _hasError
      ? []
      : DartIOHttpRequestData._parseCookies(_request.request?.cookies);

  /// A list of all cookies contained within the response headers.
  List<Cookie> get responseCookies =>
      DartIOHttpRequestData._parseCookies(_request.response?.cookies);

  /// The request headers for the HTTP request.
  Map<String, dynamic>? get requestHeaders =>
      _hasError ? null : _request.request?.headers;

  /// The response headers for the HTTP request.
  Map<String, dynamic>? get responseHeaders => _request.response?.headers;

  @override
  bool get didFail {
    if (status == null) return false;
    if (status == 'Error') return true;

    try {
      final code = int.parse(status!);
      // Status codes 400-499 are client errors and 500-599 are server errors.
      if (code >= 400) {
        return true;
      }
    } on Exception catch (e, st) {
      _log.shout('Could not parse HTTP request status: $status', e, st);
      return true;
    }
    return false;
  }

  /// Merges the information from another [HttpRequestData] into this instance.
  void merge(DartIOHttpRequestData data) {
    _request = data._request;
    _updateCount.value++;
  }

  @override
  DateTime? get endTimestamp {
    final endTime = _endTime;
    return endTime == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(
            timelineMicrosecondsSinceEpoch(endTime),
          );
  }

  @override
  DateTime get startTimestamp => DateTime.fromMicrosecondsSinceEpoch(
        timelineMicrosecondsSinceEpoch(_request.startTime),
      );

  @override
  String? get status =>
      _hasError ? 'Error' : _request.response?.statusCode.toString();

  @override
  String get uri => _request.uri.toString();

  String? get responseBody {
    if (_request is! HttpProfileRequest) {
      return null;
    }
    final fullRequest = _request as HttpProfileRequest;
    try {
      if (!_request.isResponseComplete) return null;
      if (_responseBody != null) return _responseBody;
      _responseBody = utf8.decode(fullRequest.responseBody!);
      return _responseBody;
    } on FormatException {
      return '<binary data>';
    }
  }

  Uint8List? get encodedResponse {
    if (!_request.isResponseComplete) return null;
    final fullRequest = _request as HttpProfileRequest;
    return fullRequest.responseBody;
  }

  String? _responseBody;

  String? get requestBody {
    if (_request is! HttpProfileRequest) {
      return null;
    }
    final fullRequest = _request as HttpProfileRequest;
    try {
      if (!_request.isResponseComplete) return null;
      final acceptedMethods = {'POST', 'PUT', 'PATCH'};
      if (!acceptedMethods.contains(_request.method)) return null;
      if (_requestBody != null) return _requestBody;
      if (fullRequest.requestBody == null) return null;
      _requestBody = utf8.decode(fullRequest.requestBody!);
      return _requestBody;
    } on FormatException {
      return '<binary data>';
    }
  }

  String? _requestBody;

  void _recalculateInstantEventTimes() {
    int lastTime = _request.startTime;
    for (final instant in instantEvents) {
      final instantTime = instant.timestampMicros;
      instant._timeRange = TimeRange()
        ..start = Duration(microseconds: lastTime)
        ..end = Duration(microseconds: instantTime);
      lastTime = instantTime;
    }
  }

  @override
  // ignore: avoid-dynamic, necessary here.
  bool operator ==(other) {
    return other is DartIOHttpRequestData && id == other.id && super == other;
  }

  @override
  int get hashCode => Object.hash(
        id,
        method,
        uri,
        contentType,
        type,
        port,
        startTimestamp,
      );
}
