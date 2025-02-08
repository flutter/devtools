// Copyright 2021 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

// Code in this file should be able to be imported by both web and dart:io
// dependent libraries.

import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:stack_trace/stack_trace.dart' as stack_trace;

import '../primitives/utils.dart';

/// Base class for all screen metrics classes.
///
/// Create a subclass of this class to store custom metrics for a screen. All
/// subclasses are expected to add custom metrics as fields. For example:
///
/// ```dart
/// class MyScreenAnalyticsMetrics extends ScreenAnalyticsMetrics {
///   const MyScreenAnalyticsMetrics({this.myMetric1, this.myMetric2});
///
///   final int myMetric1;
///
///   final String myMetric2;
/// }
/// ```
///
/// Then, add your fields to the [GtagEventDevTools] factory constructor and add
/// a corresponding getter in the class.
abstract class ScreenAnalyticsMetrics {}

/// The character limit for each event parameter value sent to GA4.
const ga4ParamValueCharacterLimit = 100;

/// Returns a stack trace as a [Map] for consumption by GA4 analytics.
///
/// The returned [Map] is indexed into [stackTraceChunksLimit] chunks, where
/// each chunk is a substring of length [ga4ParamValueCharacterLimit]. Each
/// substring contains information for ~1 stack frame, so including
/// [stackTraceChunksLimit] chunks should give us enough information to
/// understand the source of the exception.
///
/// This method uses a heuristic to attempt to include a minimal amount of
/// DevTools-related information in each stack trace. However, there is no
/// guarantee that the returned stack trace will contain any DevTools
/// information. For example, this may happen if all stack frames in the stack
/// trace are from the Flutter framework or from some other package.
Map<String, String?> createStackTraceForAnalytics(
  stack_trace.Trace? stackTrace,
) {
  if (stackTrace == null) return {};

  // Consider a stack frame that contains the 'devtools' String to be from one
  // of the DevTools packages (devtools_app, devtools_shared, etc.).
  const devToolsIdentifier = 'devtools';
  const stackTraceChunksLimit = 10;
  const maxCharacterLimit = stackTraceChunksLimit * ga4ParamValueCharacterLimit;

  // Reduce whitespace characters to optimize available space.
  final trimmedStackFrames =
      stackTrace.frames
          .map((f) => '${_normalizePath(f.location)} | ${f.member}\n')
          .toList();
  final stackTraceAsString = trimmedStackFrames.join();

  var stackTraceChunksForGa = chunkForGa(
    stackTraceAsString,
    chunkCountLimit: stackTraceChunksLimit,
  );

  // Count the number of stack frames that fully fit within [maxCharacterLimit].
  final framesThatFitCount = countFullFramesThatFit(
    trimmedStackFrames,
    maxCharacterLimit: maxCharacterLimit,
  );
  final framesThatFit = trimmedStackFrames.sublist(0, framesThatFitCount);

  final containsDevToolsFrame = framesThatFit.join().contains(
    devToolsIdentifier,
  );
  // If the complete stack frames in [stackTraceChunksForGa] do not contain any
  // DevTools data, modify the stack trace to add DevTools information that may
  // help with debugging the exception.
  if (!containsDevToolsFrame) {
    final devToolsFrames = trimmedStackFrames
        .where((entry) => entry.contains(devToolsIdentifier))
        .toList()
        .safeSublist(0, 3);
    if (devToolsFrames.isNotEmpty) {
      const modifierLine = '<modified to include DevTools frames>\n';
      final devToolsFramesCharacterLength = devToolsFrames.fold(
        0,
        (sum, frame) => sum += frame.length,
      );
      final originalStackTraceCharLimit =
          maxCharacterLimit -
          devToolsFramesCharacterLength -
          modifierLine.length;
      final originalFramesThatFitCount = countFullFramesThatFit(
        trimmedStackFrames,
        maxCharacterLimit: originalStackTraceCharLimit,
      );

      final modifiedStackFrames = [
        ...trimmedStackFrames.sublist(0, originalFramesThatFitCount),
        modifierLine,
        ...devToolsFrames,
      ];
      stackTraceChunksForGa = chunkForGa(
        modifiedStackFrames.join(),
        chunkCountLimit: stackTraceChunksLimit,
      );
    }
  }

  final stackTraceChunks = {
    'stackTraceChunk0': stackTraceChunksForGa.safeGet(0),
    'stackTraceChunk1': stackTraceChunksForGa.safeGet(1),
    'stackTraceChunk2': stackTraceChunksForGa.safeGet(2),
    'stackTraceChunk3': stackTraceChunksForGa.safeGet(3),
    'stackTraceChunk4': stackTraceChunksForGa.safeGet(4),
    'stackTraceChunk5': stackTraceChunksForGa.safeGet(5),
    'stackTraceChunk6': stackTraceChunksForGa.safeGet(6),
    'stackTraceChunk7': stackTraceChunksForGa.safeGet(7),
    'stackTraceChunk8': stackTraceChunksForGa.safeGet(8),
    'stackTraceChunk9': stackTraceChunksForGa.safeGet(9),
  };
  assert(stackTraceChunks.length == stackTraceChunksLimit);
  return stackTraceChunks;
}

/// A regex that matches a string that starts with a Windows drive letter (with
/// colon).
final _startsWithWindowsDriveLetterRegex = RegExp(r'^[a-zA-Z]:');

/// Normalize a file path from either platform to the POSIX equivalent so that
/// paths are the same for both Windows and non-Windows paths.
String _normalizePath(String path) {
  // Windows path with drive letter.
  if (_startsWithWindowsDriveLetterRegex.hasMatch(path)) {
    // Strip drive letter and normalize slashes to match POSIX.
    // C:\foo\bar -> /foo/bar
    return path.substring(2).replaceAll(r'\', '/');
  }

  // Otherwise, return as-is.
  return path;
}

/// Returns the number of stack frames from [stackFrameStrings] that fit within
/// [maxCharacterLimit].
int countFullFramesThatFit(
  List<String> stackFrameStrings, {
  required int maxCharacterLimit,
}) {
  var count = 0;
  var characterCount = 0;
  for (final stackFrameAsString in stackFrameStrings) {
    characterCount += stackFrameAsString.length;
    if (characterCount < maxCharacterLimit) {
      count++;
    } else {
      break;
    }
  }
  return count;
}

/// Splits [value] up into substrings of size [ga4ParamValueCharacterLimit] so
/// that the data can be set to GA4 through unified_analytics.
///
/// This will return a [List] up to size [chunkCountLimit] at a maximum.
List<String> chunkForGa(String value, {required int chunkCountLimit}) {
  return value
      .trim()
      .characters
      .slices(ga4ParamValueCharacterLimit)
      .map((slice) => slice.join())
      .toList()
      .safeSublist(0, chunkCountLimit);
}
