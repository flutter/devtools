import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps [widget] with the build context it needs to load in a test.
Widget wrap(Widget widget, {Size windowSize}) => MaterialApp(home: widget);

/// Sets the size of the app window under test to [windowSize].
///
/// This will be reset on each test invocation, so it doesn't need to be reset
/// in [tearDown] calls.
Future<void> setWindowSize(Size windowSize) async {
  final TestWidgetsFlutterBinding binding =
      TestWidgetsFlutterBinding.ensureInitialized();
  await binding.setSurfaceSize(windowSize);
  binding.window.physicalSizeTestValue = windowSize;
  binding.window.devicePixelRatioTestValue = 1.0;
}
