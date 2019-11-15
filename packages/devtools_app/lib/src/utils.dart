// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

import 'ui/fake_flutter/fake_flutter.dart';

bool collectionEquals(e1, e2) => const DeepCollectionEquality().equals(e1, e2);

const String loremIpsum = '''
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Donec faucibus dolor quis rhoncus feugiat. Ut imperdiet
libero vel vestibulum vulputate. Aliquam consequat, lectus nec euismod commodo, turpis massa volutpat ex, a
elementum tellus turpis nec arcu. Suspendisse erat nisl, rhoncus ut nisi in, lacinia pretium dui. Donec at erat
ultrices, tincidunt quam sit amet, cursus lectus. Integer justo turpis, vestibulum condimentum lectus eget,
sodales suscipit risus. Nullam consequat sit amet turpis vitae facilisis. Integer sit amet tempus arcu.
''';

// 2^52 is the max int for dart2js.
final int maxJsInt = pow(2, 52) as int;

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

String percent2(double d) => '${(d * 100).toStringAsFixed(2)}%';

String printMb(num bytes, [int fractionDigits = 1]) {
  return (bytes / (1024 * 1024)).toStringAsFixed(fractionDigits);
}

String msText(
  Duration dur, {
  bool includeUnit = true,
  int fractionDigits = 1,
}) {
  return '${(dur.inMicroseconds / 1000).toStringAsFixed(fractionDigits)}'
      '${includeUnit ? ' ms' : ''}';
}

T nullSafeMin<T extends num>(T a, T b) {
  if (a == null || b == null) {
    return a ?? b;
  }
  return min<T>(a, b);
}

T nullSafeMax<T extends num>(T a, T b) {
  if (a == null || b == null) {
    return a ?? b;
  }
  return max<T>(a, b);
}

int log2(num x) => (log(x) / log(2)).floor();

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
    return '${funcRefName(ref.owner as FuncRef)}.${ref.name}';
  } else {
    return ref.name;
  }
}

void executeWithDelay(Duration delay, void callback(),
    {bool executeNow = false}) {
  if (executeNow || delay.inMilliseconds <= 0) {
    callback();
  } else {
    Timer(delay, () {
      callback();
    });
  }
}

String longestFittingSubstring(
  String originalText,
  num maxWidth,
  List<num> asciiMeasurements,
  num slowMeasureFallback(int value),
) {
  if (originalText.isEmpty) return originalText;

  final runes = originalText.runes.toList();

  num currentWidth = 0;

  int i = 0;
  while (i < runes.length) {
    final rune = runes[i];
    final charWidth =
        rune < 128 ? asciiMeasurements[rune] : slowMeasureFallback(rune);
    if (currentWidth + charWidth > maxWidth) {
      break;
    }
    // [currentWidth] is approximate due to ignoring kerning.
    currentWidth += charWidth;
    i++;
  }

  return originalText.substring(0, i);
}

/// Whether a given code unit is a letter (A-Z or a-z).
bool isLetter(int codeUnit) =>
    (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122);

/// Returns a simplified version of a StackFrame name.
///
/// Given an input such as
/// `_WidgetsFlutterBinding&BindingBase&GestureBinding.handleBeginFrame`, this
/// method will strip off all the leading class names and return
/// `GestureBinding.handleBeginFrame`.
///
/// See (https://github.com/dart-lang/sdk/issues/36999).
String getSimpleStackFrameName(String name) {
  final newName = name.replaceAll('<anonymous closure>', '<closure>');

  // If the class name contains a space, then it is not a valid Dart name. We
  // throw out simplified names with spaces to prevent simplifying C++ class
  // signatures, where the '&' char signifies a reference variable - not
  // appended class names.
  if (newName.contains(' ')) {
    return newName;
  }
  return newName.split('&').last;
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

/// A typedef to represent a function taking no arguments and with no return
/// value.
typedef VoidFunction = void Function();

/// A typedef to represent a function taking no arguments and returning a void
/// future.
typedef VoidAsyncFunction = Future<void> Function();

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
    return json[memberName] as String;
  }

  static int getIntMember(Map<String, Object> json, String memberName) {
    return json[memberName] as int ?? -1;
  }

  static List<String> getValues(Map<String, Object> json, String member) {
    final List<dynamic> values = json[member] as List;
    if (values == null || values.isEmpty) {
      return const [];
    }

    return values.cast();
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
      _pendingRequest = Completer();
      await callback();
    } finally {
      _pendingRequest.complete(null);
    }
  }

  void dispose() {
    _activeTimer?.cancel();
  }
}

/// Time unit for displaying time ranges.
///
/// If the need arises, this enum can be expanded to include any of the
/// remaining time units supported by [Duration] - (seconds, minutes, etc.). If
/// you add a unit of time to this enum, modify the toString() method in
/// [TimeRange] to handle the new case.
enum TimeUnit {
  microseconds,
  milliseconds,
}

class TimeRange {
  TimeRange({this.singleAssignment = true});

  final bool singleAssignment;

  Duration get start => _start;

  Duration _start;

  set start(Duration value) {
    if (singleAssignment) {
      assert(_start == null);
    }
    _start = value;
  }

  Duration get end => _end;

  Duration _end;

  bool contains(Duration target) => target >= start && target <= end;

  set end(Duration value) {
    if (singleAssignment) {
      assert(_end == null);
    }
    _end = value;
  }

  Duration get duration => end - start;

  bool overlaps(TimeRange t) {
    return (t.start >= start && t.start <= end) ||
        (t.end >= start && t.end <= end);
  }

  @override
  String toString({TimeUnit unit}) {
    unit ??= TimeUnit.microseconds;
    switch (unit) {
      case TimeUnit.microseconds:
        return '[${_start?.inMicroseconds} μs - ${end?.inMicroseconds} μs]';
      case TimeUnit.milliseconds:
      default:
        return '[${_start?.inMilliseconds} ms - ${end?.inMilliseconds} ms]';
    }
  }

  @override
  bool operator ==(other) {
    return start == other.start && end == other.end;
  }

  @override
  int get hashCode => hashValues(start, end);
}

bool isDebugBuild() {
  bool debugBuild = false;
  assert((() {
    debugBuild = true;
    return true;
  })());
  return debugBuild;
}

/// Divides [numerator] by [denominator], not returning infinite, NaN, or null
/// quotients.
///
/// Returns [ifNotFinite] as a return value when the result of dividing
/// [numerator] by [denominator] would be a non-finite value: either
/// NaN, null, or infinite.
///
/// [ifNotFinite] defaults to 0.0.
double safeDivide(num numerator, num denominator, {double ifNotFinite = 0.0}) {
  if (numerator != null && denominator != null) {
    final quotient = numerator / denominator;
    if (quotient.isFinite) {
      return quotient;
    }
  }
  return ifNotFinite;
}

/// A simple change notifier.
///
/// When disposing, any object with a registered listener should [unregister]
/// itself.
///
/// Generally, a registering object should use `this` as its key.
///
/// Only the object that created this notifier should call [notify].
class Notifier {
  final Map<Object, void Function()> _listeners = {};

  /// Adds [callback] to this notifier, associated with [key].
  ///
  /// If [key] is already registered on this notifier, the previous callback
  /// will be overridden.
  void register(Object key, void Function() callback) {
    _listeners[key] = callback;
  }

  /// Removes the listener associated with [key].
  void unregister(Object key) {
    _listeners.remove(key);
  }

  /// Whether or not this object has any event listeners registered.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Notifies all listeners of a change.
  ///
  /// This does not do any change propagation, so if
  /// a notification callback leads to a change in the listeners,
  /// only the original listeners will be called.
  void notify() {
    for (var callback in _listeners.values.toList()) {
      callback();
    }
  }
}
