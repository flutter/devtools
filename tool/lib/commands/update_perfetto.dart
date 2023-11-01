// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:devtools_tool/model.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import '../utils.dart';

const _buildFlag = 'build';

class UpdatePerfettoCommand extends Command {
  UpdatePerfettoCommand() {
    argParser.addOption(
      _buildFlag,
      abbr: 'b',
      help: 'The build location of the Perfetto assets. When this is not '
          'specified, the Perfetto assets will be fetched from the latest '
          'source code at "android.googlesource.com".',
      valueHelp: '/Users/me/path/to/perfetto/out/ui/ui/dist',
    );
  }

  @override
  String get name => 'update-perfetto';

  @override
  String get description =>
      'Updates the Perfetto assets that are included in the DevTools app bundle.';

  @override
  Future run() async {
    final processManager = ProcessManager();

    final perfettoUiCompiledLib = pathFromRepoRoot(
      path.join('third_party', 'packages', 'perfetto_ui_compiled', 'lib'),
    );
    final perfettoDevToolsPath =
        path.join(perfettoUiCompiledLib, 'dist', 'devtools');

    logStatus(
      'moving DevTools-Perfetto integration files to a temp directory.',
    );
    final tempPerfettoDevTools =
        Directory(path.join(Directory.systemTemp.path, 'perfetto_devtools'))
          ..createSync();
    await copyPath(perfettoDevToolsPath, tempPerfettoDevTools.path);

    logStatus('deleting existing Perfetto build');
    final existingBuild = Directory(path.join(perfettoUiCompiledLib, 'dist'));
    existingBuild.deleteSync(recursive: true);

    logStatus('updating Perfetto build');
    final buildLocation = argResults![_buildFlag];
    if (buildLocation != null) {
      logStatus('using Perfetto build from $buildLocation');
      await processManager.runProcess(CliCommand('cp -R $buildLocation ./'));
    } else {
      logStatus('cloning Perfetto from HEAD and building from source');
      final tempPerfettoClone =
          Directory(path.join(Directory.systemTemp.path, 'perfetto_clone'))
            ..createSync();
      await processManager.runProcess(
        CliCommand.git(
          'clone https://android.googlesource.com/platform/external/perfetto',
        ),
        workingDirectory: tempPerfettoClone.path,
      );

      logStatus('installing build deps and building the Perfetto UI');
      await processManager.runAll(
        commands: [
          CliCommand('${path.join('tools', 'install-build-deps')} --ui'),
          CliCommand(path.join('ui', 'build')),
        ],
        workingDirectory: path.join(tempPerfettoClone.path, 'perfetto'),
      );
      await copyPath(
        path.join(
          tempPerfettoClone.path,
          'perfetto',
          'out',
          'ui',
          'ui',
          'dist',
        ),
        perfettoUiCompiledLib,
      );

      logStatus('deleting perfetto clone');
      tempPerfettoClone.deleteSync(recursive: true);
    }

    logStatus('deleting unnecessary js source map files from build');
    final deleteMatchers = [
      RegExp(r'\.js\.map'),
      RegExp(r'traceconv\.wasm'),
      RegExp(r'traceconv_bundle\.js'),
      RegExp(r'catapult_trace_viewer\..*'),
      RegExp(r'rec_.*\.png'),
    ];
    final libDirectory = Directory(perfettoUiCompiledLib);
    final libFiles = libDirectory.listSync();
    for (final file in libFiles) {
      if (deleteMatchers
          .any((matcher) => matcher.hasMatch(file.path))) {
        logStatus('deleting ${file.path}');
        file.deleteSync();
      }
    }

    logStatus(
      'moving DevTools-Perfetto integration files back from the temp directory',
    );
    Directory(path.join(perfettoUiCompiledLib, 'dist', 'devtools'))
        .createSync();
    await copyPath(tempPerfettoDevTools.path, perfettoDevToolsPath);

    logStatus(
      'updating index.html headers to include DevTools-Perfetto integration files',
    );
    await processManager.runAll(
      commands: [
        CliCommand(
          // ignore: unnecessary_string_escapes
          'gsed -i "s/<\/head>/  <link id=\"devtools-style\" rel=\"stylesheet\" href=\"devtools\/devtools_dark.css\">\n<\/head>/g" ${path.join('dist', 'index.html')}',
        ),
        CliCommand(
          // ignore: unnecessary_string_escapes
          'gsed -i "s/<\/head>/  <script src=\"devtools\/devtools_theme_handler.js\"><\/script>\n<\/head>/g" ${path.join('dist', 'index.html')}',
        ),
      ],
      workingDirectory: perfettoUiCompiledLib,
    );

    logStatus('deleting temporary directory');
    tempPerfettoDevTools.deleteSync(recursive: true);

    logStatus('updating perfetto assets in the devtools_app pubspec.yaml file');
    _updatePerfettoAssetsInPubspec();
  }

  void _updatePerfettoAssetsInPubspec() {
    final mainDevToolsDirectory = DevToolsRepo.getInstance().repoPath;
    final perfettoDistDir = Directory.fromUri(
      Uri.parse(
        '$mainDevToolsDirectory/third_party/packages/perfetto_ui_compiled/lib/dist',
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
        logStatus('new Perfetto version: $newVersionNumber');
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
      Uri.parse('$mainDevToolsDirectory/packages/devtools_app/pubspec.yaml'),
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

    logStatus(
      'updating devtools_app/pubspec.yaml for new Perfetto version'
      '$newVersionNumber',
    );
    final pubspecLinesAsString = '${lines.join('\n')}\n';
    pubspec.writeAsStringSync(pubspecLinesAsString);
  }
}
