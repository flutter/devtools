// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:vm_service_lib/vm_service_lib.dart';

const String loremIpsum = '''
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec faucibus dolor quis rhoncus feugiat. Ut imperdiet
libero vel vestibulum vulputate. Aliquam consequat, lectus nec euismod commodo, turpis massa volutpat ex, a
elementum tellus turpis nec arcu. Suspendisse erat nisl, rhoncus ut nisi in, lacinia pretium dui. Donec at erat
ultrices, tincidunt quam sit amet, cursus lectus. Integer justo turpis, vestibulum condimentum lectus eget,
sodales suscipit risus. Nullam consequat sit amet turpis vitae facilisis. Integer sit amet tempus arcu.
''';

String getLoremText([int paragraphCount = 1]) {
  String str = '';
  for (int i = 0; i < paragraphCount; i++) {
    str += '$loremIpsum\n';
  }
  return str.trim();
}

final Random r = Random();

final List<String> _words = loremIpsum
    .replaceAll('\n', ' ')
    .split(' ')
    .map((String w) => w.toLowerCase())
    .map((String w) => w.endsWith('.') ? w.substring(0, w.length - 1) : w)
    .map((String w) => w.endsWith(',') ? w.substring(0, w.length - 1) : w)
    .toList();

String getLoremFragment([int wordCount]) {
  wordCount ??= r.nextInt(8) + 1;
  return toBeginningOfSentenceCase(
      List<String>.generate(wordCount, (_) => _words[r.nextInt(_words.length)])
          .join(' ')
          .trim());
}

String escape(String text) => text == null ? '' : htmlEscape.convert(text);

final NumberFormat nf = NumberFormat.decimalPattern();

String percent(double d) => '${(d * 100).toStringAsFixed(1)}%';

String percent2(double d) => '${(d * 100).toStringAsFixed(2)}%';

String printMb(num bytes, [int fractionDigits = 1]) {
  return (bytes / (1024 * 1024)).toStringAsFixed(fractionDigits);
}

String isolateName(IsolateRef ref) {
  // analysis_server.dart.snapshot$main
  String name = ref.name;
  name = name.replaceFirst(r'.snapshot', '');
  if (name.contains(r'.dart$')) {
    name = name + '()';
  }
  return name;
}

String funcRefName(FuncRef ref) {
  if (ref.owner is LibraryRef) {
    //(ref.owner as LibraryRef).uri;
    return ref.name;
  } else if (ref.owner is ClassRef) {
    return '${ref.owner.name}.${ref.name}';
  } else if (ref.owner is FuncRef) {
    return '${funcRefName(ref.owner)}.${ref.name}';
  } else {
    return ref.name;
  }
}

class Property<T> {
  Property(this._value);

  final StreamController<T> _changeController = StreamController<T>.broadcast();
  T _value;

  T get value => _value;

  set value(T newValue) {
    if (newValue != _value) {
      _value = newValue;
      _changeController.add(newValue);
    }
  }

  Stream<T> get onValueChange => _changeController.stream;
}

/// The directory used to store per-user settings for Dart tooling.
Directory getDartPrefsDirectory() {
  return Directory(path.join(getUserHomeDir(), '.dart'));
}

/// Return the user's home directory.
String getUserHomeDir() {
  final String envKey =
      Platform.operatingSystem == 'windows' ? 'APPDATA' : 'HOME';
  final String value = Platform.environment[envKey];
  return value == null ? '.' : value;
}

/// A typedef to represent a function taking no arguments and with no return
/// value.
typedef VoidFunction = void Function();

/// A typedef to represent a function taking no arguments and returning a void
/// future.
typedef VoidAsyncFunction = Future<void> Function();

/// A typedef to represent a function taking a single argument and with no
/// return value.
typedef VoidFunctionWithArg = void Function(dynamic arg);

/// Batch up calls to the given closure. Repeated calls to [invoke] will
/// overwrite the closure to be called. We'll delay at least [minDelay] before
/// calling the closure, but will not delay more than [maxDelay].
class DelayedTimer {
  DelayedTimer(this.minDelay, this.maxDelay);

  final Duration minDelay;
  final Duration maxDelay;

  VoidFunction _closure;

  Timer _minTimer;
  Timer _maxTimer;

  void invoke(VoidFunction closure) {
    _closure = closure;

    if (_minTimer == null) {
      _minTimer = Timer(minDelay, _fire);
      _maxTimer = Timer(maxDelay, _fire);
    } else {
      _minTimer.cancel();
      _minTimer = Timer(minDelay, _fire);
    }
  }

  void _fire() {
    _minTimer?.cancel();
    _minTimer = null;

    _maxTimer?.cancel();
    _maxTimer = null;

    _closure();
    _closure = null;
  }
}

/// These utilities are ported from the Flutter IntelliJ plugin.
///
/// With Dart's terser JSON support, these methods don't provide much value so
/// we should consider removing them.
class JsonUtils {
  JsonUtils._();

  static String getStringMember(Map<String, Object> json, String memberName) {
    // TODO(jacobr): should we handle non-string values with a reasonable
    // toString differently?
    return json[memberName];
  }

  static int getIntMember(Map<String, Object> json, String memberName) {
    return json[memberName] ?? -1;
  }

  static List<String> getValues(Map<String, Object> json, String member) {
    final List<Object> values = json[member];
    if (values == null || values.isEmpty) {
      return const [];
    }

    return values.toList();
  }

  static bool hasJsonData(String data) {
    return data != null && data.isNotEmpty && data != 'null';
  }
}

typedef RateLimiterCallback = Future<Object> Function();

/// Rate limiter that ensures a [callback] is run no more  than the
/// specified rate and that at most one async [callback] is running at a time.
class RateLimiter {
  RateLimiter(double requestsPerSecond, this.callback)
      : delayBetweenRequests = 1000 ~/ requestsPerSecond;

  final RateLimiterCallback callback;
  Completer<void> _pendingRequest;

  /// A request has been scheduled to run but is not yet pending.
  bool requestScheduledButNotStarted = false;
  int _lastRequestTime;
  final int delayBetweenRequests;

  Timer _activeTimer;

  /// Schedules the callback to be run the next time the rate limiter allows it.
  ///
  /// If multiple calls to scheduleRequest are made before a request is allowed,
  /// only a single request will be made.
  void scheduleRequest() {
    if (requestScheduledButNotStarted) {
      // No need to schedule a request if one has already been scheduled but
      // hasn't yet actually started executing.
      return;
    }

    if (_pendingRequest != null && !_pendingRequest.isCompleted) {
      // Wait for the pending request to be done before scheduling the new
      // request. The existing request has already started so may return state
      // that is now out of date.
      requestScheduledButNotStarted = true;
      _pendingRequest.future.whenComplete(() {
        _pendingRequest = null;
        requestScheduledButNotStarted = false;
        scheduleRequest();
      });
      return;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (_lastRequestTime == null ||
        _lastRequestTime + delayBetweenRequests <= currentTime) {
      // Safe to perform the request immediately.
      _performRequest();
      return;
    }
    // Track that we have scheduled a request and then schedule the request
    // to occur once the rate limiter is available.
    requestScheduledButNotStarted = true;
    _activeTimer = Timer(
        Duration(
            milliseconds:
                currentTime - _lastRequestTime + delayBetweenRequests), () {
      _activeTimer = null;
      requestScheduledButNotStarted = false;
      _performRequest();
    });
  }

  void _performRequest() async {
    try {
      _lastRequestTime = DateTime.now().millisecondsSinceEpoch;
      await callback();
    } finally {
      _pendingRequest.complete(null);
    }
  }

  void dispose() {
    _activeTimer?.cancel();
  }
}
