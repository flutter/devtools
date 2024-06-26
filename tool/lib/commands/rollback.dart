// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:args/command_runner.dart';

import '../model.dart';

const _toVersionArg = 'to-version';

class RollbackCommand extends Command {
  RollbackCommand() : super() {
    argParser.addOption(_toVersionArg, mandatory: true);
  }

  @override
  String get name => 'rollback';

  @override
  String get description => 'Rolls back to a specific DevTools version.';

  @override
  Future run() async {
    final repo = DevToolsRepo.getInstance();
    print('DevTools repo at ${repo.repoPath}.');

    final tempDir =
        (await io.Directory.systemTemp.createTemp('devtools-rollback'))
            .absolute;
    print('file://${tempDir.path}');
    final tarball = io.File(
      '${tempDir.path}/devtools.tar.gz',
    );
    final extractDir =
        await io.Directory('${tempDir.path}/extract/').absolute.create();
    final client = io.HttpClient();
    final version = argResults![_toVersionArg] as String;
    print('downloading tarball to ${tarball.path}');
    final tarballRequest = await client.getUrl(
      Uri.http(
        'storage.googleapis.com',
        'pub-packages/packages/devtools-$version.tar.gz',
      ),
    );
    final tarballResponse = await tarballRequest.close();
    await tarballResponse.pipe(tarball.openWrite());
    print('Tarball written; unzipping.');

    await io.Process.run(
      'tar',
      ['-x', '-z', '-f', tarball.path.split('/').last, '-C', extractDir.path],
      workingDirectory: tempDir.path,
    );
    print('file://${tempDir.path}');

    final buildDir = io.Directory('${repo.repoPath}/packages/devtools/build/');
    await buildDir.delete(recursive: true);
    await io.Directory('${extractDir.path}build/')
        .rename('${repo.repoPath}/packages/devtools/build/');

    print('Build outputs from Devtools version $version checked out and moved '
        'to ${buildDir.path}');
    print('To complete the rollback, go to ${repo.repoPath}/packages/devtools, '
        'rev pubspec.yaml, update the changelog, unhide build/ from the '
        'packages/devtools/.gitignore file, then run pub publish.');
    // TODO(djshuckerow): automatically rev pubspec.yaml and update the
    // changelog so that the user can just run pub publish from
    // packages/devtools.
  }
}
