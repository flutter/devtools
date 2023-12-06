// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

// Note: this is a helper script for development. This is helpful for generating
// test data from DevTools exports.

/// Generates a dart file with a [Map] variable 'data' that contains the JSON
/// data contained in the given json file (first argument).
///
/// To use:
///
/// `dart json_to_map.dart ~/Users/me/path/to/my_file.json`
///
/// This will generate a file with the same name but with a '.dart' extension
/// instead of '.json' (e.g. ~/path/to/my_file.dart). This will be a valid dart
/// file with a single [Map] variable [data].
void main(List<String> args) {
  if (args.isEmpty) {
    throw Exception('Please pass a file location for the json file.');
  }
  final jsonFileLocation = args.first;
  final jsonFilePath = Uri.parse(jsonFileLocation).path;
  final jsonFile = File(jsonFilePath);
  if (!jsonFile.existsSync()) {
    throw FileSystemException('File not found at $jsonFileLocation');
  }

  final jsonFileName = jsonFilePath.split('/').last;
  final fileNameWithoutExtension =
      (jsonFileName.split('.')..removeLast()).join('.');
  final jsonFileDirectoryPath =
      Uri.parse((jsonFilePath.split('/')..removeLast()).join('/'));

  final Map<String, Object?> jsonAsMap =
      jsonDecode(jsonFile.readAsStringSync());
  var jsonFormattedString = JsonEncoder.withIndent('  ').convert(jsonAsMap);

  // Escape any '$' characters so that Dart does not think we are trying to do
  // String interpolation.
  jsonFormattedString = jsonFormattedString.replaceAll('\$', '\\\$');

  final dartFile = File('$jsonFileDirectoryPath/$fileNameWithoutExtension.dart')
    ..createSync()
    ..writeAsStringSync(
      '''
// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: prefer_single_quotes
// ignore_for_file: prefer-trailing-comma
// ignore_for_file: require_trailing_commas

final Map<String, dynamic> data = <String, dynamic>$jsonFormattedString;
''',
    );

  print('Created ${dartFile.path}');
}
