// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Method to convert degrees to radians
double degToRad(num deg) => deg * (pi / 180.0);

/// A small double value, used to ensure that comparisons between double are
/// valid.
const defaultEpsilon = 1 / 1000;

bool equalsWithinEpsilon(double a, double b) {
  return (a - b).abs() < defaultEpsilon;
}

const tooltipWait = Duration(milliseconds: 500);

const tooltipWaitLong = Duration(milliseconds: 1000);

/// Pluralizes a word, following english rules (1, many).
///
/// Pass a custom named `plural` for irregular plurals:
/// `pluralize('index', count, plural: 'indices')`
/// So it returns `indices` and not `indexs`.
String pluralize(String word, int count, {String? plural}) =>
    count == 1 ? word : (plural ?? '${word}s');

bool isPrivateMember(String member) => member.startsWith('_');

/// Public properties first, then sort alphabetically
int sortFieldsByName(String a, String b) {
  final isAPrivate = isPrivateMember(a);
  final isBPrivate = isPrivateMember(b);

  if (isAPrivate && !isBPrivate) {
    return 1;
  }
  if (!isAPrivate && isBPrivate) {
    return -1;
  }

  return a.compareTo(b);
}

/// A value notifier that calls each listener immediately when registered.
final class ImmediateValueNotifier<T> extends ValueNotifier<T> {
  ImmediateValueNotifier(T value) : super(value);

  /// Adds a listener and calls the listener upon registration.
  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    listener();
  }
}

Future<T> whenValueNonNull<T>(
  ValueListenable<T> listenable, {
  Duration? timeout,
}) {
  if (listenable.value != null) return Future.value(listenable.value);
  final completer = Completer<T>();
  void listener() {
    final value = listenable.value;
    if (value != null) {
      completer.complete(value);
      listenable.removeListener(listener);
    }
  }

  listenable.addListener(listener);

  if (timeout != null) {
    return completer.future.timeout(timeout);
  }
  return completer.future;
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
