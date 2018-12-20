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
import 'globals.dart';
import 'ui/primer.dart';

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

final Random r = new Random();

final List<String> _words = loremIpsum
    .replaceAll('\n', ' ')
    .split(' ')
    .map((String w) => w.toLowerCase())
    .map((String w) => w.endsWith('.') ? w.substring(0, w.length - 1) : w)
    .map((String w) => w.endsWith(',') ? w.substring(0, w.length - 1) : w)
    .toList();

String getLoremFragment([int wordCount]) {
  wordCount ??= r.nextInt(8) + 1;
  return toBeginningOfSentenceCase(new List<String>.generate(
      wordCount, (_) => _words[r.nextInt(_words.length)]).join(' ').trim());
}

String escape(String text) => text == null ? '' : htmlEscape.convert(text);

final NumberFormat nf = new NumberFormat.decimalPattern();

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

  final StreamController<T> _changeController =
      new StreamController<T>.broadcast();
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
  return new Directory(path.join(getUserHomeDir(), '.dart'));
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
typedef void VoidFunction();

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

// TODO(kenzie): perhaps add same icons we use in IntelliJ to these buttons.
// This would help to build icon familiarity.
PButton createExtensionButton(String text, String extensionName) {
  final PButton button = new PButton(text)..small();
  button.click(() {
    final bool wasSelected = button.element.classes.contains('selected');
    serviceManager.serviceExtensionManager.setServiceExtensionState(
        extensionName, !wasSelected, !wasSelected);
  });
  return button;
}
