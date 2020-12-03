// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:ansi_up/ansi_up.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:vm_service/vm_service.dart';

import 'config_specific/logger/logger.dart' as logger;
import 'notifications.dart';

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

String prettyPrintBytes(
  num bytes, {
  int kbFractionDigits = 0,
  int mbFractionDigits = 1,
  bool includeUnit = false,
}) {
  if (bytes == null) {
    return null;
  }
  // TODO(peterdjlee): Generalize to handle different kbFractionDigits.
  // Ensure a small number of bytes does not print as 0 KB.
  // If bytes >= 52 and kbFractionDigits == 1, it will start rounding to 0.1 KB.
  if (bytes.abs() < 52 && kbFractionDigits == 1) {
    var output = bytes.toString();
    if (includeUnit) {
      output += ' B';
    }
    return output;
  }
  final sizeInKB = bytes.abs() / 1024.0;
  if (sizeInKB < 1024.0) {
    return '${printKB(bytes, fractionDigits: kbFractionDigits, includeUnit: includeUnit)}';
  } else {
    return '${printMB(bytes, fractionDigits: mbFractionDigits, includeUnit: includeUnit)}';
  }
}

String printKB(num bytes, {int fractionDigits = 0, bool includeUnit = false}) {
  final NumberFormat _kbPattern = NumberFormat.decimalPattern()
    ..maximumFractionDigits = fractionDigits;

  // We add ((1024/2)-1) to the value before formatting so that a non-zero byte
  // value doesn't round down to 0. If showing decimal points, let it round normally.
  // TODO(peterdjlee): Round up to the respective digit when fractionDigits > 0.
  final processedBytes = fractionDigits == 0 ? bytes + 511 : bytes;
  var output = _kbPattern.format(processedBytes / 1024);
  if (includeUnit) {
    output += ' KB';
  }
  return output;
}

String printMB(num bytes, {int fractionDigits = 1, bool includeUnit = false}) {
  var output = (bytes / (1024 * 1024.0)).toStringAsFixed(fractionDigits);
  if (includeUnit) {
    output += ' MB';
  }
  return output;
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

/// Pluralizes a word, following english rules (1, many).
///
/// Pass a custom named `plural` for irregular plurals:
/// `pluralize('index', count, plural: 'indices')`
/// So it returns `indices` and not `indexs`.
String pluralize(String word, int count, {String plural}) =>
    count == 1 ? word : (plural ?? '${word}s');

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

/// Parses a 3 or 6 digit CSS Hex Color into a dart:ui Color.
Color parseCssHexColor(String input) {
  // Remove any leading # (and the escaped version to be lenient)
  input = input.replaceAll('#', '').replaceAll('%23', '');

  // Handle 3/4-digit hex codes (eg. #123 == #112233)
  if (input.length == 3 || input.length == 4) {
    input = input.split('').map((c) => '$c$c').join();
  }

  // Pad alpha with FF.
  if (input.length == 6) {
    input = '${input}ff';
  }

  // In CSS, alpha is in the lowest bits, but for Flutter's value, it's in the
  // highest bits, so move the alpha from the end to the start before parsing.
  if (input.length == 8) {
    input = '${input.substring(6)}${input.substring(0, 6)}';
  }
  final value = int.parse(input, radix: 16);

  return Color(value);
}

/// Converts a dart:ui Color into #RRGGBBAA format for use in CSS.
String toCssHexColor(Color color) {
  // In CSS Hex, Alpha comes last, but in Flutter's `value` field, alpha is
  // in the high bytes, so just using `value.toRadixString(16)` will put alpha
  // in the wrong position.
  String hex(int val) => val.toRadixString(16).padLeft(2, '0');
  return '#${hex(color.red)}${hex(color.green)}${hex(color.blue)}${hex(color.alpha)}';
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

String formatDateTime(DateTime time) {
  return DateFormat('h:mm:ss.S a').format(time);
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

/// A dev time class to help trace DevTools application events.
class DebugTimingLogger {
  DebugTimingLogger(this.name, {this.mute});

  final String name;
  final bool mute;

  Stopwatch _timer;

  void log(String message) {
    if (mute) return;

    if (_timer != null) {
      _timer.stop();
      print('[$name}]   ${_timer.elapsedMilliseconds}ms');
      _timer.reset();
    }

    _timer ??= Stopwatch();
    _timer.start();

    print('[$name] $message');
  }
}

/// Compute a simple moving average.
/// [averagePeriod] default period is 50 units collected.
/// [ratio] default percentage is 50% range is 0..1
class MovingAverage {
  MovingAverage({
    this.averagePeriod = 50,
    this.ratio = .5,
    List<int> newDataSet,
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

Future<void> launchUrl(String url, BuildContext context) async {
  if (await url_launcher.canLaunch(url)) {
    await url_launcher.launch(url);
  } else {
    Notifications.of(context).push('Unable to open $url.');
  }
}

/// Attempts to copy a String of `data` to the clipboard.
///
/// Shows a `successMessage` [Notification] on the passed in `context`.
Future<void> copyToClipboard(
  String data,
  String successMessage,
  BuildContext context,
) async {
  await Clipboard.setData(ClipboardData(
    text: data,
  ));

  if (successMessage != null) {
    Notifications.of(context)?.push(successMessage);
  }
}

List<TextSpan> processAnsiTerminalCodes(String input, TextStyle defaultStyle) {
  if (input == null) {
    return [];
  }
  return decodeAnsiColorEscapeCodes(input, AnsiUp())
      .map(
        (entry) => TextSpan(
          text: entry.text,
          style: entry.style.isEmpty
              ? defaultStyle
              : TextStyle(
                  color: entry.fgColor != null
                      ? colorFromAnsi(entry.fgColor)
                      : null,
                  backgroundColor: entry.bgColor != null
                      ? colorFromAnsi(entry.bgColor)
                      : null,
                  fontWeight: entry.bold ? FontWeight.bold : FontWeight.normal,
                ),
        ),
      )
      .toList();
}

Color colorFromAnsi(List<int> ansiInput) {
  assert(ansiInput.length == 3, 'Ansi color list should contain 3 elements');
  return Color.fromRGBO(ansiInput[0], ansiInput[1], ansiInput[2], 1);
}

/// An extension on [LogicalKeySet] to provide user-facing names for key
/// bindings.
extension LogicalKeySetExtension on LogicalKeySet {
  static final Set<LogicalKeyboardKey> _modifiers = {
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.shift,
  };

  static final Map<LogicalKeyboardKey, String> _modifierNames = {
    LogicalKeyboardKey.alt: 'Alt',
    LogicalKeyboardKey.control: 'Control',
    LogicalKeyboardKey.meta: 'Meta',
    LogicalKeyboardKey.shift: 'Shift',
  };

  /// Return a user-facing name for the [LogicalKeySet].
  String describeKeys({bool isMacOS = false}) {
    // Put the modifiers first. If it has a synonym, then it's something like
    // shiftLeft, altRight, etc.
    final List<LogicalKeyboardKey> sortedKeys = keys.toList()
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
          return '⌘';
        }
        return '${_modifierNames[key]}-';
      } else {
        return key.keyLabel.toUpperCase();
      }
    }).join();
  }
}

// Method to convert degrees to radians
num degToRad(num deg) => deg * (pi / 180.0);

typedef DevToolsJsonFileHandler = void Function(DevToolsJsonFile file);

class DevToolsJsonFile extends DevToolsFile<Object> {
  const DevToolsJsonFile({
    @required String name,
    @required DateTime lastModifiedTime,
    @required Object data,
  }) : super(
          path: name,
          lastModifiedTime: lastModifiedTime,
          data: data,
        );
}

class DevToolsFile<T> {
  const DevToolsFile({
    @required this.path,
    @required this.lastModifiedTime,
    @required this.data,
  });
  final String path;

  final DateTime lastModifiedTime;

  final T data;
}

/// Logging to debug console only in debug runs.
void debugLogger(String message) {
  // Debug only check.
  assert(() {
    logger.log('$message');
    return true;
  }());
}

final _lowercaseLookup = <String, String>{};

// TODO(kenz): consider moving other String helpers into this extension.
// TODO(kenz): replace other uses of toLowerCase() for string matching with
// this extension method.
extension StringExtension on String {
  bool caseInsensitiveContains(String str) {
    final lowerCase = _lowercaseLookup.putIfAbsent(this, () => toLowerCase());
    final strLowerCase =
        _lowercaseLookup.putIfAbsent(str, () => str.toLowerCase());
    return lowerCase.contains(strLowerCase);
  }
}

extension ListExtension<T> on List<T> {
  List<T> joinWith(T separator) {
    return [
      for (int i = 0; i < length; i++) ...[
        this[i],
        if (i != length - 1) separator,
      ]
    ];
  }
}

Map<String, String> devToolsQueryParams(String url) {
  // DevTools urls can have the form:
  // http://localhost:123/?key=value
  // http://localhost:123/#/?key=value
  // http://localhost:123/#/page-id?key=value
  // Since we just want the query params, we will modify the url to have an
  // easy-to-parse form.
  final modifiedUri = url.replaceFirst(RegExp(r'#\/(\w*)[?]'), '?');
  final uri = Uri.parse(modifiedUri);
  return uri.queryParameters;
}
