// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// TODO(kenz): delete this script once we can confirm it is not used in the
// Dart SDK or in infra tooling.

import 'dart:io';

void main(List<String> args) {
  final mainDevToolsDirectory = Directory.current;
  if (!mainDevToolsDirectory.path.endsWith('/devtools')) {
    throw Exception(
      'Please execute this script from your top level '
      '\'devtools/\' directory. Running the `update_perfetto.sh` script will'
      'automatically do this.',
    );
  }

  final perfettoDistDir = Directory.fromUri(
    Uri.parse(
      '${mainDevToolsDirectory.path}/third_party/packages/perfetto_ui_compiled/lib/dist',
    ),
  );

  // Find the new perfetto version number.
  String newVersionNumber = '';
  final versionRegExp = RegExp(r'v\d+[.]\d+-[0-9a-fA-F]+');
  final entities = perfettoDistDir.listSync();
  for (FileSystemEntity entity in entities) {
    final path = entity.path;
    final match = versionRegExp.firstMatch(path);
    if (match != null) {
      newVersionNumber = path.split('/').last;
      print('New Perfetto version: $newVersionNumber');
      break;
    }
  }

  if (newVersionNumber.isEmpty) {
    throw Exception(
      'Error updating Perfetto assets: could not find Perfetto version number '
      'from entities: ${entities.map((e) => e.path).toList()}',
    );
  }

  final pubspec = File.fromUri(
    Uri.parse(
      '${mainDevToolsDirectory.path}/packages/devtools_app/pubspec.yaml',
    ),
  );

  // TODO(kenz): Ensure the pubspec.yaml contains an entry for each file in
  // [perfettoDistDir].

  final perfettoAssetRegExp = RegExp(
    r'(?<prefix>^.*packages\/perfetto_ui_compiled\/dist\/)(?<version>v\d+[.]\d+-[0-9a-fA-F]+)(?<suffix>\/.*$)',
  );
  final lines = pubspec.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final match = perfettoAssetRegExp.firstMatch(line);
    if (match != null) {
      final prefix = match.namedGroup('prefix')!;
      final suffix = match.namedGroup('suffix')!;
      lines[i] = '$prefix$newVersionNumber$suffix';
    }
  }

  print(
    'Updating devtools_app/pubspec.yaml for new Perfetto version'
    '$newVersionNumber',
  );
  final pubspecLinesAsString = '${lines.join('\n')}\n';
  pubspec.writeAsStringSync(pubspecLinesAsString);
}
