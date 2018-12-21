// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';

import 'context.dart';

export 'package:file/file.dart';
export 'package:file/local.dart';

/// This class was copied from
/// flutter/packages/flutter_tools/lib/src/base/file_system.dart. It supports
/// the use of [FlutterTestDriver].

const FileSystem _kLocalFs = LocalFileSystem();

/// Currently active implementation of the file system.
///
/// By default it uses local disk-based implementation. Override this in tests
/// with [MemoryFileSystem].
FileSystem get fs => context[FileSystem] ?? _kLocalFs;
