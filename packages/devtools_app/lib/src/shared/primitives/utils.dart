// Copyright 2018 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// This file contain low level utils, i.e. utils that do not depend on
// libraries in this package.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'ansi_utils.dart';
import 'byte_utils.dart';
import 'simple_items.dart';

final _log = Logger('utils');

bool collectionEquals(Object? e1, Object? e2, {bool ordered = true}) {
  if (ordered) {
    return const DeepCollectionEquality().equals(e1, e2);
  }
  return const DeepCollectionEquality.unordered().equals(e1, e2);
}

// 2^52 is the max int for dart2js.
final maxJsInt = pow(2, 52) as int;

final nf = NumberFormat.decimalPattern();

String percent(double d, {int fractionDigits = 2}) =>
    '${(d * 100).toStringAsFixed(fractionDigits)}%';

/// Unifies printing of retained size to avoid confusion related to different rounding.
String? prettyPrintRetainedSize(int? bytes) =>
    prettyPrintBytes(bytes, includeUnit: true);

enum DurationDisplayUnit {
  micros('μs'),
  milliseconds('ms'),
  seconds('s');

  const DurationDisplayUnit(this.display);

  final String display;

  static DurationDisplayUnit unitFor(int micros) {
    if (micros < 100) {
      // Display values less than 0.1 millisecond as microseconds.
      return DurationDisplayUnit.micros;
    } else if (micros < 1000000) {
      return DurationDisplayUnit.milliseconds;
    }
    return DurationDisplayUnit.seconds;
  }
}

/// Converts a [Duration] into a readable text representation in the specified
/// [unit].
///
/// [includeUnit] - whether to include the unit at the end of the returned value
/// [fractionDigits] - how many fraction digits should appear after the decimal.
/// This parameter value will be ignored when the unit is specified or inferred
/// as [DurationDisplayUnit.micros], since there cannot be a fractional value of
/// microseconds from the [Duration] class.
/// [allowRoundingToZero] - when true, this method may return zero for a very
/// small number (e.g. '0.0 ms'). When false, this method will return a minimum
/// value with the less than operator for very small values (e.g. '< 0.1 ms').
/// The value returned will always respect the specified [fractionDigits].
String durationText(
  Duration dur, {
  DurationDisplayUnit? unit,
  bool includeUnit = true,
  int fractionDigits = 1,
  bool allowRoundingToZero = true,
}) {
  if (!allowRoundingToZero && unit == null) {
    throw AssertionError('To disable rounding to zero, please specify a unit.');
  }

  final micros = dur.inMicroseconds;
  unit ??= DurationDisplayUnit.unitFor(micros);
  double durationAsDouble;
  switch (unit) {
    case DurationDisplayUnit.micros:
      durationAsDouble = micros.toDouble();
      break;
    case DurationDisplayUnit.milliseconds:
      durationAsDouble = micros / 1000;
      break;
    case DurationDisplayUnit.seconds:
      durationAsDouble = micros / 1000000;
      break;
  }

  // Hide any fraction digits when the unit is microseconds, since the
  // duration displayed will always be a whole number in this case.
  if (unit == DurationDisplayUnit.micros) {
    fractionDigits = 0;
  }

  var durationStr = durationAsDouble.toStringAsFixed(fractionDigits);
  if (dur != Duration.zero && !allowRoundingToZero) {
    final zeroRegexp = RegExp(r'[0]+[.][0]+');
    if (zeroRegexp.hasMatch(durationStr)) {
      final buf = StringBuffer('< 0.');
      for (int i = 1; i < fractionDigits; i++) {
        buf.write('0');
      }
      buf.write('1');
      durationStr = buf.toString();
    }
  }
  return '$durationStr${includeUnit ? ' ${unit.display}' : ''}';
}

T? nullSafeMin<T extends num>(T? a, T? b) {
  if (a == null || b == null) {
    return a ?? b;
  }
  return min<T>(a, b);
}

T? nullSafeMax<T extends num>(T? a, T? b) {
  if (a == null || b == null) {
    return a ?? b;
  }
  return max<T>(a, b);
}

double logBase({required int x, required int base}) {
  return log(x) / log(base);
}

int log2(num x) => logBase(x: x.floor(), base: 2).floor();

int roundToNearestPow10(int x) =>
    pow(10, logBase(x: x, base: 10).ceil()).floor();

void executeWithDelay(
  Duration delay,
  void Function() callback, {
  bool executeNow = false,
}) {
  if (executeNow || delay.inMilliseconds <= 0) {
    callback();
  } else {
    Timer(delay, () {
      callback();
    });
  }
}

Future<void> delayToReleaseUiThread({int micros = 0}) async {
  // Even with a delay of 0 microseconds, awaiting this delay is enough to free
  // the UI thread to update the UI.
  await Future.delayed(Duration(microseconds: micros));
}

/// Use in long calculations, to release UI thread after each N steps.
class UiReleaser {
  UiReleaser({this.stepsBetweenDelays = 100000, this.delayLength = 0})
    : assert(stepsBetweenDelays > 0);

  final int stepsBetweenDelays;
  final int delayLength;

  int _stepCount = 0;

  /// Returns true if it is time to invoke [releaseUi].
  bool step() {
    _stepCount++;
    if (_stepCount == stepsBetweenDelays) {
      _stepCount = 0;
      return true;
    }
    return false;
  }

  Future<void> releaseUi() => delayToReleaseUiThread(micros: delayLength);
}

/// Creates a [Future] that completes either when `operation` completes or the
/// duration specified by `timeoutMillis` has passed.
///
/// Completes with null on timeout.
Future<T?> timeout<T>(Future<T> operation, int timeoutMillis) =>
    Future.any<T?>([
      operation,
      Future<T?>.delayed(
        Duration(milliseconds: timeoutMillis),
        () => Future<T?>.value(),
      ),
    ]);

String longestFittingSubstring(
  String originalText,
  num maxWidth,
  List<num> asciiMeasurements,
  num Function(int value) slowMeasureFallback,
) {
  if (originalText.isEmpty) return originalText;

  final runes = originalText.runes.toList();

  num currentWidth = 0;

  int i = 0;
  while (i < runes.length) {
    final rune = runes[i];
    final charWidth = rune < 128
        ? asciiMeasurements[rune]
        : slowMeasureFallback(rune);
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
String getSimpleStackFrameName(String? name) {
  name ??= '';
  final newName = name.replaceAll(anonymousClosureName, closureName);

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
  late StreamController controller;

  StreamSubscription? asub;
  StreamSubscription? bsub;
  StreamSubscription? csub;

  controller = StreamController(
    onListen: () {
      asub = a.listen(controller.add);
      bsub = b.listen(controller.add);
      csub = c.listen(controller.add);
    },
    onCancel: () {
      unawaited(asub?.cancel());
      unawaited(bsub?.cancel());
      unawaited(csub?.cancel());
    },
  );

  return controller.stream;
}

class Property<T> {
  Property(this._value);

  final _changeController = StreamController<T>.broadcast();
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

  VoidCallback? _closure;

  Timer? _minTimer;
  Timer? _maxTimer;

  void invoke(VoidCallback closure) {
    _closure = closure;

    if (_minTimer == null) {
      _minTimer = Timer(minDelay, _fire);
      _maxTimer = Timer(maxDelay, _fire);
    } else {
      _minTimer!.cancel();
      _minTimer = Timer(minDelay, _fire);
    }
  }

  void _fire() {
    _minTimer?.cancel();
    _minTimer = null;

    _maxTimer?.cancel();
    _maxTimer = null;

    _closure!();
    _closure = null;
  }
}

/// These utilities are ported from the Flutter IntelliJ plugin.
///
/// With Dart's terser JSON support, these methods don't provide much value so
/// we should consider removing them.
class JsonUtils {
  JsonUtils._();

  static String? getStringMember(Map<String, Object?> json, String memberName) {
    // TODO(jacobr): should we handle non-string values with a reasonable
    // toString differently?
    return json[memberName] as String?;
  }

  static int getIntMember(Map<String, Object?> json, String memberName) {
    return json[memberName] as int? ?? -1;
  }
}

/// Add pretty print for a JSON payload.
extension JsonMap on Map<String, Object?> {
  String prettyPrint() => const JsonEncoder.withIndent('  ').convert(this);
}

typedef RateLimiterCallback = Future<void> Function();

/// Rate limiter that ensures a [callback] is run no more  than the
/// specified rate and that at most one async [callback] is running at a time.
class RateLimiter {
  RateLimiter(double requestsPerSecond, this.callback)
    : delayBetweenRequests = 1000 ~/ requestsPerSecond;

  final RateLimiterCallback callback;
  Completer<void>? _pendingRequest;

  /// A request has been scheduled to run but is not yet pending.
  bool requestScheduledButNotStarted = false;
  int? _lastRequestTime;
  final int delayBetweenRequests;

  Timer? _activeTimer;

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

    if (_pendingRequest != null && !_pendingRequest!.isCompleted) {
      // Wait for the pending request to be done before scheduling the new
      // request. The existing request has already started so may return state
      // that is now out of date.
      requestScheduledButNotStarted = true;
      unawaited(
        _pendingRequest!.future.whenComplete(() {
          _pendingRequest = null;
          requestScheduledButNotStarted = false;
          scheduleRequest();
        }),
      );
      return;
    }

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (_lastRequestTime == null ||
        _lastRequestTime! + delayBetweenRequests <= currentTime) {
      // Safe to perform the request immediately.
      _performRequest();
      return;
    }
    // Track that we have scheduled a request and then schedule the request
    // to occur once the rate limiter is available.
    requestScheduledButNotStarted = true;
    _activeTimer = Timer(
      Duration(
        milliseconds: currentTime - _lastRequestTime! + delayBetweenRequests,
      ),
      () {
        _activeTimer = null;
        requestScheduledButNotStarted = false;
        _performRequest();
      },
    );
  }

  void _performRequest() async {
    try {
      _lastRequestTime = DateTime.now().millisecondsSinceEpoch;
      _pendingRequest = Completer();
      await callback();
    } finally {
      _pendingRequest!.complete(null);
    }
  }

  void dispose() {
    _activeTimer?.cancel();
    _activeTimer = null;
  }
}

// If the need arises, this enum can be expanded to include any of the
// remaining time units supported by [Duration] - (seconds, minutes, etc.).
/// Time unit for displaying time ranges.
enum TimeUnit { microseconds, milliseconds }

/// A builder used to build a well-formed [TimeRange] incrementally.
final class TimeRangeBuilder {
  /// Creates a new [TimeRangeBuilder] to build a [TimeRange]
  /// with the optionally specified [start] and [end] initial values.
  TimeRangeBuilder({int? start, int? end}) : _start = start, _end = end;

  int? _start;

  /// Sets the start time of this builder.
  ///
  /// The start time should be less than or equal to the end time.
  set start(int startTime) {
    _start = startTime;
  }

  int? _end;

  /// Sets the end time of this builder.
  ///
  /// The end time should be greater than or equal to the start time.
  set end(int endTime) {
    _end = endTime;
  }

  /// Whether both `start` and `end` properties are set,
  /// meaning [build] can safely be called.
  bool get canBuild => _start != null && _end != null;

  /// Returns a [TimeRange] built from the specified [start] and [end] values.
  ///
  /// If either [start] or [end] is `null`, throws an error.
  ///
  /// The [start] time must be less than or equal to the [end] time.
  TimeRange build() {
    final startTimestamp = _start;
    if (startTimestamp == null) {
      throw StateError('TimeRangeBuilder.start must be set before building!');
    }

    final endTimestamp = _end;
    if (endTimestamp == null) {
      throw StateError('TimeRangeBuilder.end must be set before building!');
    }

    return TimeRange(start: startTimestamp, end: endTimestamp);
  }

  /// Returns a new [TimeRangeBuilder] with the current values of this builder.
  TimeRangeBuilder copy() => TimeRangeBuilder(start: _start, end: _end);
}

final class TimeRange {
  /// Creates a [TimeRange] with the specified
  /// [start] and [end] times in microseconds.
  ///
  /// The [start] time must be less than or equal to the [end] time.
  TimeRange({required this.start, required this.end})
    : assert(start <= end, '$start is not less than or equal to end time $end'),
      assert(
        end >= start,
        '$end is not greater than or equal to start time $start',
      );

  /// Creates a [TimeRange] with the specified [start] time in microseconds and
  /// [end] calculated as being [duration] microseconds later.
  factory TimeRange.ofDuration(int duration, {int start = 0}) =>
      TimeRange(start: start, end: start + duration);

  /// The starting time in microseconds.
  final int start;

  /// The ending time in microseconds.
  final int end;

  /// The duration of time between the [start] and [end] microseconds.
  Duration get duration => Duration(microseconds: end - start);

  /// Whether this time range contains the specified [target] microsecond.
  bool contains(int target) => start <= target && end >= target;

  /// Whether this time range completely contains the
  /// specified [target] time range.
  bool containsRange(TimeRange target) =>
      start <= target.start && end >= target.end;

  @override
  String toString({TimeUnit? unit}) => switch (unit ?? TimeUnit.microseconds) {
    TimeUnit.microseconds => '[$start μs - $end μs]',
    TimeUnit.milliseconds => '[${start ~/ 1000} ms - ${end ~/ 1000} ms]',
  };

  @override
  bool operator ==(Object other) {
    if (other is! TimeRange) return false;
    return start == other.start && end == other.end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

String formatDateTime(DateTime time) {
  return DateFormat('H:mm:ss.S').format(time);
}

/// Divides [numerator] by [denominator], not returning infinite, NaN, or null
/// quotients.
///
/// Returns [ifNotFinite] as a return value when the result of dividing
/// [numerator] by [denominator] would be a non-finite value: either
/// NaN, null, or infinite.
///
/// [ifNotFinite] defaults to 0.0.
double safeDivide(
  num? numerator,
  num? denominator, {
  double ifNotFinite = 0.0,
}) {
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
/// For small N (~ &lt;20), [ChangeNotifier] implementations can be faster because
/// array access is more efficient than set access. Use [Reporter] instead in
/// cases where N is larger.
///
/// When disposing, any object with a registered listener should `unregister`
/// itself.
///
/// Only the object that created this reporter should call [notify].
class Reporter implements Listenable {
  final _listeners = <VoidCallback>{};

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
    for (final callback in _listeners.toList()) {
      callback();
    }
  }

  @override
  String toString() => describeIdentity(this);
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

extension SafeListOperations<T> on List<T> {
  T? safeGet(int index) => index < 0 || index >= length ? null : this[index];

  T? safeRemoveLast() => isNotEmpty ? removeLast() : null;

  List<T> safeSublist(int start, [int? end]) {
    if (start >= length || start >= (end ?? length)) return <T>[];
    return sublist(max(start, 0), min(length, end ?? length));
  }
}

extension SafeAccess<T> on Iterable<T> {
  T? get safeFirst => isNotEmpty ? first : null;

  T? get safeLast => isNotEmpty ? last : null;
}

/// Range class for all nums (double and int).
///
/// Only operations that work on both double and int should be added to this
/// class.
class Range {
  const Range(this.begin, this.end) : assert(begin <= end);

  final num begin;
  final num end;

  num get size => end - begin;

  bool contains(num target) => target >= begin && target <= end;

  @override
  String toString() => 'Range($begin, $end)';

  @override
  bool operator ==(Object other) {
    if (other is! Range) return false;
    return begin == other.begin && end == other.end;
  }

  @override
  int get hashCode => Object.hash(begin, end);
}

enum SortDirection { ascending, descending }

/// A Range-like class that works for inclusive ranges of lines in source code.
class LineRange {
  const LineRange(this.begin, this.end) : assert(begin <= end);

  final int begin;
  final int end;

  int get size => end - begin + 1;

  bool contains(num target) => target >= begin && target <= end;

  @override
  String toString() => 'LineRange($begin, $end)';

  @override
  bool operator ==(Object other) {
    if (other is! LineRange) return false;
    return begin == other.begin && end == other.end;
  }

  @override
  int get hashCode => Object.hash(begin, end);
}

extension SortDirectionExtension on SortDirection {
  SortDirection reverse() {
    return this == SortDirection.ascending
        ? SortDirection.descending
        : SortDirection.ascending;
  }
}

// /// A small double value, used to ensure that comparisons between double are
// /// valid.
// const defaultEpsilon = 1 / 1000;

// bool equalsWithinEpsilon(double a, double b) {
//   return (a - b).abs() < defaultEpsilon;
// }

/// A dev time class to help trace DevTools application events.
class DebugTimingLogger {
  DebugTimingLogger(this.name, {this.mute = false});

  final String name;
  final bool mute;

  Stopwatch? _timer;

  void log(String message) {
    if (mute) return;

    if (_timer != null) {
      _timer!.stop();
      _log.fine('[$name}]   ${_timer!.elapsedMilliseconds}ms');
      _timer!.reset();
    }

    _timer ??= Stopwatch();
    _timer!.start();

    _log.fine('[$name] $message');
  }
}

/// Compute a simple moving average.
/// [averagePeriod] default period is 50 units collected.
/// [ratio] default percentage is 50% range is 0..1
class MovingAverage {
  MovingAverage({
    this.averagePeriod = 50,
    this.ratio = 0.5,
    List<int>? newDataSet,
  }) : assert(ratio >= 0 && ratio <= 1, 'Value ratio $ratio is not 0 to 1.') {
    if (newDataSet != null) {
      var initialDataSet = newDataSet;
      final count = newDataSet.length;
      if (count > averagePeriod) {
        initialDataSet = newDataSet.sublist(count - averagePeriod);
      }

      dataSet.addAll(initialDataSet);
      for (final value in dataSet) {
        averageSum += value;
      }
    }
  }

  final dataSet = Queue<int>();

  /// Total collected items in the X axis (time) used to compute moving average.
  /// Default 100 periods for memory profiler 1-2 periods / seconds.
  final int averagePeriod;

  /// Ratio of first item in dataSet when comparing to last - mean
  /// e.g., 2 is 50% (dataSet.first ~/ ratioSpike).
  final double ratio;

  /// Sum of total heap used and external heap for unitPeriod.
  int averageSum = 0;

  /// Reset moving average data.
  void clear() {
    dataSet.clear();
    averageSum = 0;
  }

  // Update the sum to get a new mean.
  void add(int value) {
    averageSum += value;
    dataSet.add(value);

    // Update dataSet of values to not exceede the period of the moving average
    // to compute the normal mean.
    if (dataSet.length > averagePeriod) {
      averageSum -= dataSet.removeFirst();
    }
  }

  double get mean {
    final periodRange = min(averagePeriod, dataSet.length);
    return periodRange > 0 ? averageSum / periodRange : 0;
  }

  /// If the last - mean > ratioSpike% of first value in period we're spiking.
  bool hasSpike() {
    final first = dataSet.safeFirst ?? 0;
    final last = dataSet.safeLast ?? 0;

    return last - mean > (first * ratio);
  }

  /// If the mean @ ratioSpike% > last value in period we're dipping.
  bool isDipping() {
    final last = dataSet.safeLast ?? 0;
    return (mean * ratio) > last;
  }
}

List<TextSpan> textSpansFromAnsi(String input, TextStyle defaultStyle) {
  final parser = AnsiParser(input);
  return parser.parse().map((entry) {
    final styled = entry.bold || entry.fgColor != null || entry.bgColor != null;
    return TextSpan(
      text: entry.text,
      style: styled
          ? TextStyle(
              color: ansiToColor(entry.fgColor),
              backgroundColor: ansiToColor(entry.bgColor),
              fontWeight: entry.bold ? FontWeight.bold : FontWeight.normal,
            )
          : defaultStyle,
    );
  }).toList();
}

Color? ansiToColor(List<int>? ansiInput) {
  if (ansiInput == null) {
    return null;
  }

  assert(ansiInput.length == 3, 'Ansi color list should contain 3 elements');
  return Color.fromRGBO(ansiInput[0], ansiInput[1], ansiInput[2], 1);
}

/// An extension on [LogicalKeySet] to provide user-facing names for key
/// bindings.
extension LogicalKeySetExtension on LogicalKeySet {
  static final _modifiers = <LogicalKeyboardKey>{
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.shift,
  };

  static final _modifierNames = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.alt: 'Alt',
    LogicalKeyboardKey.control: 'Control',
    LogicalKeyboardKey.meta: 'Meta',
    LogicalKeyboardKey.shift: 'Shift',
  };

  /// Return a user-facing name for the [LogicalKeySet].
  String describeKeys({bool isMacOS = false}) {
    // Put the modifiers first. If it has a synonym, then it's something like
    // shiftLeft, altRight, etc.
    final sortedKeys = keys.toList()
      ..sort((a, b) {
        final aIsModifier = a.synonyms.isNotEmpty || _modifiers.contains(a);
        final bIsModifier = b.synonyms.isNotEmpty || _modifiers.contains(b);
        if (aIsModifier && !bIsModifier) {
          return -1;
        } else if (bIsModifier && !aIsModifier) {
          return 1;
        }
        return a.keyLabel.compareTo(b.keyLabel);
      });

    return sortedKeys.map((key) {
      if (_modifiers.contains(key)) {
        if (isMacOS && key == LogicalKeyboardKey.meta) {
          // TODO(https://github.com/flutter/devtools/issues/3352) Switch back
          // to using ⌘ once supported on web.
          return kIsWeb ? 'Command-' : '⌘';
        }
        return '${_modifierNames[key]}-';
      } else {
        return key.keyLabel.toUpperCase();
      }
    }).join();
  }
}

typedef DevToolsJsonFileHandler = void Function(DevToolsJsonFile file);

class DevToolsJsonFile extends DevToolsFile<Object> {
  const DevToolsJsonFile({
    required String name,
    required super.lastModifiedTime,
    required super.data,
  }) : super(path: name);
}

class DevToolsFile<T> {
  const DevToolsFile({
    required this.path,
    required this.lastModifiedTime,
    required this.data,
  });

  final String path;

  final DateTime lastModifiedTime;

  final T data;
}

final _lowercaseLookup = <String, String>{};

extension NullableStringExtension on String? {
  bool get isNullOrEmpty {
    final self = this;
    return self == null || self.isEmpty;
  }
}

// TODO(kenz): consider moving other String helpers into this extension.
// TODO(kenz): replace other uses of toLowerCase() for string matching with
// this extension method.
extension StringExtension on String {
  bool caseInsensitiveContains(Pattern? pattern) {
    if (pattern is RegExp) {
      assert(!pattern.isCaseSensitive);
      return contains(pattern);
    } else if (pattern is String) {
      final lowerCase = _lowercaseLookup.putIfAbsent(this, () => toLowerCase());
      final strLowerCase = _lowercaseLookup.putIfAbsent(
        pattern,
        () => pattern.toLowerCase(),
      );
      return lowerCase.contains(strLowerCase);
    }
    throw Exception(
      'Unhandled pattern type ${pattern.runtimeType} from '
      '`caseInsensitiveContains`',
    );
  }

  /// Whether [pattern] is a case insensitive match for this String.
  ///
  /// If [pattern] is a [RegExp], this method will return true if and only if
  /// this String is a complete [RegExp] match, meaning that the regular
  /// expression finds a match with starting index 0 and ending index
  /// [this.length].
  bool caseInsensitiveEquals(Pattern? pattern) {
    if (pattern is RegExp) {
      assert(!pattern.isCaseSensitive);
      final completeMatch = pattern
          .allMatches(this)
          .firstWhereOrNull((match) => match.start == 0 && match.end == length);
      return completeMatch != null;
    }
    return toLowerCase() == pattern.toString().toLowerCase();
  }

  /// Find all case insensitive matches of query in this String
  /// See [allMatches] for more info
  Iterable<Match> caseInsensitiveAllMatches(String? query) {
    if (query == null) return const [];
    return toLowerCase().allMatches(query.toLowerCase());
  }

  String toSentenceCase() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}

extension IterableExtension<T> on Iterable<T> {
  /// Joins the iterable with [separator], and also adds a trailing [separator].
  String joinWithTrailing([String separator = '']) {
    var result = join(separator);
    if (length > 0) {
      result += separator;
    }
    return result;
  }
}

extension ListExtension<T> on List<T> {
  List<T> joinWith(
    T separator, {
    bool includeTrailing = false,
    bool includeLeading = false,
  }) {
    return [
      if (includeLeading) separator,
      for (int i = 0; i < length; i++) ...[
        this[i],
        if (i != length - 1) separator,
      ],
      if (includeTrailing) separator,
    ];
  }

  T get second => this[1];

  T get third => this[2];

  T get fourth => this[3];

  T get fifth => this[4];

  List<int> allIndicesWhere(bool Function(T element) test) {
    final indices = <int>[];
    for (var i = 0; i < length; i++) {
      if (test(this[i])) {
        indices.add(i);
      }
    }
    return indices;
  }
}

extension NullableListExtension<T> on List<T>? {
  bool get isNullOrEmpty {
    final self = this;
    return self == null || self.isEmpty;
  }
}

extension SetExtension<T> on Set<T> {
  bool containsAny(Iterable<T> any) {
    for (final e in any) {
      if (contains(e)) {
        return true;
      }
    }
    return false;
  }
}

extension UiListExtension<T> on List<T> {
  int get numSpacers => max(0, length - 1);
}

double safePositiveDouble(double value) {
  if (value.isNaN) return 0.0;
  return max(value, 0.0);
}

/// Displays timestamp using locale's timezone HH:MM:SS, if isUtc is false.
/// @param isUTC - if true for testing, the UTC locale is used (instead of
/// the user's locale). Tests will then pass when run in any timezone. All
/// formatted timestamps are displayed using the UTC locale.
String prettyTimestamp(int? timestamp, {bool isUtc = false}) {
  if (timestamp == null) return '';
  final timestampDT = DateTime.fromMillisecondsSinceEpoch(
    timestamp,
    isUtc: isUtc,
  );
  return DateFormat.Hms().format(timestampDT); // HH:mm:ss
}

extension BoolExtension on bool {
  int boolCompare(bool other) {
    if ((this && other) || (!this && !other)) return 0;
    if (other) return 1;
    return -1;
  }
}

const connectToNewAppText = 'Connect to a new app';

/// Exception thrown when a request to process data has been cancelled in
/// favor of a new request.
class ProcessCancelledException implements Exception {}

/// Returns the file name from a URI or path string, by splitting the [uri] at
/// the directory separators '/', and returning the last element.
String? fileNameFromUri(String? uri) => uri?.split('/').lastOrNull;

/// Calculates subtraction of two maps.
///
/// Result map keys is union of the input maps' keys.
Map<K, R> subtractMaps<K, F, S, R>({
  required Map<K, S>? subtract,
  required Map<K, F>? from,
  required R? Function({required S? subtract, required F? from}) subtractor,
}) {
  from ??= <K, F>{};
  subtract ??= <K, S>{};

  final result = <K, R>{};
  final unionOfKeys = from.keys.toSet().union(subtract.keys.toSet());

  for (final key in unionOfKeys) {
    final diff = subtractor(from: from[key], subtract: subtract[key]);
    if (diff != null) result[key] = diff;
  }
  return result;
}

/// Returns the url (as a string) where the DevTools assets are served.
///
/// For Flutter apps and when DevTools is served via the `dart devtools`
/// command, this url should be equivalent to [html.window.location.origin].
/// However, when DevTools is served directly from DDS via the --observe flag,
/// the authentication token and 'devtools/' path part are also required.
///
/// Examples:
/// * 'http://127.0.0.1:61962/mb9Sw4gCYvU=/devtools/performance'
///     ==> 'http://127.0.0.1:61962/mb9Sw4gCYvU=/devtools'
/// * 'http://127.0.0.1:61962/performance' ==> 'http://127.0.0.1:61962'
String devtoolsAssetsBasePath({required String origin, required String path}) {
  // Ensure that we are truly only using the origin of the URI String passed as
  // the [origin] parameter.
  final trimmedOrigin = Uri.parse(origin).origin;
  const separator = '/';
  final pathParts = path.split(separator);
  // The last path part is the DevTools page (e.g. 'performance' or 'snapshot'),
  // which is not part of the hosted asset path.
  pathParts.removeLast();
  return '$trimmedOrigin${pathParts.join(separator)}';
}
