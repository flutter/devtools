// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vm_service/vm_service.dart';

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

/// Render the given [Duration] to text using either seconds or milliseconds as
/// the units, depending on the value of the duration.
String renderDuration(Duration duration) {
  if (duration.inMilliseconds < 1000) {
    return '${nf.format(duration.inMilliseconds)}ms';
  } else {
    return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
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

Future<void> delayForBatchProcessing({int micros = 0}) async {
  // Even with a delay of 0 microseconds, awaiting this delay is enough to free
  // the UI thread to update the UI.
  await Future.delayed(Duration(microseconds: micros));
}

/// Creates a [Future] that completes either when `operation` completes or the
/// duration specified by `timeoutMillis` has passed.
///
/// Completes with null on timeout.
Future<T> timeout<T>(Future<T> operation, int timeoutMillis) => Future.any<T>([
      operation,
      Future<T>.delayed(Duration(milliseconds: timeoutMillis), () => null)
    ]);

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

String pluralize(String word, int count) => count == 1 ? word : '${word}s';

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

/// Return a Stream that fires events whenever any of the three given parameter
/// streams fire.
Stream combineStreams(Stream a, Stream b, Stream c) {
  StreamController controller;

  StreamSubscription asub;
  StreamSubscription bsub;
  StreamSubscription csub;

  controller = StreamController(
    onListen: () {
      asub = a.listen(controller.add);
      bsub = b.listen(controller.add);
      csub = c.listen(controller.add);
    },
    onCancel: () {
      asub?.cancel();
      bsub?.cancel();
      csub?.cancel();
    },
  );

  return controller.stream;
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

/// Batch up calls to the given closure. Repeated calls to [invoke] will
/// overwrite the closure to be called. We'll delay at least [minDelay] before
/// calling the closure, but will not delay more than [maxDelay].
class DelayedTimer {
  DelayedTimer(this.minDelay, this.maxDelay);

  final Duration minDelay;
  final Duration maxDelay;

  VoidCallback _closure;

  Timer _minTimer;
  Timer _maxTimer;

  void invoke(VoidCallback closure) {
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

  bool overlaps(TimeRange t) => t.end > start && t.start < end;

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

/// A change reporter that can be listened to.
///
/// Unlike [ChangeNotifier], [Reporter] stores listeners in a set.  This allows
/// O(1) addition/removal of listeners and O(N) listener dispatch.
///
/// For small N (~ <20), [ChangeNotifier] implementations can be faster because
/// array access is more efficient than set access. Use [Reporter] instead in
/// cases where N is larger.
///
/// When disposing, any object with a registered listener should [unregister]
/// itself.
///
/// Only the object that created this reporter should call [notify].
class Reporter implements Listenable {
  final Set<VoidCallback> _listeners = {};

  /// Adds [callback] to this reporter.
  ///
  /// If [callback] is already registered to this reporter, nothing will happen.
  @override
  void addListener(VoidCallback callback) {
    _listeners.add(callback);
  }

  /// Removes the listener [callback].
  @override
  void removeListener(VoidCallback callback) {
    _listeners.remove(callback);
  }

  /// Whether or not this object has any listeners registered.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Notifies all listeners of a change.
  ///
  /// This does not do any change propagation, so if
  /// a notification callback leads to a change in the listeners,
  /// only the original listeners will be called.
  void notify() {
    for (var callback in _listeners.toList()) {
      callback();
    }
  }

  @override
  String toString() => '${describeIdentity(this)}';
}

/// A [Reporter] that notifies when its [value] changes.
///
/// Similar to [ValueNotifier], but with the same performance
/// benefits as [Reporter].
///
/// For small N (~ <20), [ValueNotifier] implementations can be faster because
/// array access is more efficient than set access. Use [ValueReporter] instead
/// in cases where N is larger.
class ValueReporter<T> extends Reporter implements ValueListenable<T> {
  ValueReporter(this._value);

  @override
  T get value => _value;

  set value(T value) {
    if (_value == value) return;
    _value = value;
    notify();
  }

  T _value;

  @override
  String toString() => '${describeIdentity(this)}($value)';
}

String toStringAsFixed(double num, [int fractionDigit = 1]) {
  return num.toStringAsFixed(fractionDigit);
}

/// A value notifier that calls each listener immediately when registered.
class ImmediateValueNotifier<T> extends ValueNotifier<T> {
  ImmediateValueNotifier(T value) : super(value);

  /// Adds a listener and calls the listener upon registration.
  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    listener();
  }
}

extension SafeAccessList<T> on List<T> {
  T safeGet(int index) => index < 0 || index >= length ? null : this[index];
}

extension SafeAccess<T> on Iterable<T> {
  T get safeFirst => isNotEmpty ? first : null;

  T get safeLast => isNotEmpty ? last : null;
}

class Range {
  const Range(this.begin, this.end) : assert(begin <= end);

  final double begin;
  final double end;

  double get size => end - begin;

  @override
  String toString() => 'Range($begin, $end)';

  @override
  bool operator ==(other) {
    return begin == other.begin && end == other.end;
  }

  @override
  int get hashCode => hashValues(begin, end);
}

enum SortDirection {
  ascending,
  descending,
}

extension SortDirectionExtension on SortDirection {
  SortDirection reverse() {
    return this == SortDirection.ascending
        ? SortDirection.descending
        : SortDirection.ascending;
  }
}

/// A small double value, used to ensure that comparisons between double are
/// valid.
const defaultEpsilon = 1 / 1000;

bool equalsWithinEpsilon(double a, double b) {
  return (a - b).abs() < defaultEpsilon;
}

/// Have a quiet period after a callback to ensure that rapid invocations of a
/// callback only result in one call.
class CallbackDwell {
  CallbackDwell(
    this.callback, {
    this.dwell = const Duration(milliseconds: 250),
  });

  final VoidCallback callback;
  final Duration dwell;

  Timer _timer;

  void invoke() {
    if (_timer == null) {
      _timer = Timer(dwell, () {
        _timer = null;
      });

      callback();
    }
  }
}
