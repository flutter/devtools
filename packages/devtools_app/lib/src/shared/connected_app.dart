// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import 'console/primitives/eval_history.dart';
import 'diagnostics/dap_object_node.dart';
import 'diagnostics/dart_object_node.dart';

/// Extension methods for the [ConnectedApp] class.
///
/// Using extension methods makes testing easier, as we do not have to mock
/// these methods.
extension ConnectedAppExtension on ConnectedApp {
  String get display {
    final identifiers = <String>[];
    if (isFlutterAppNow!) {
      identifiers.addAll([
        'Flutter',
        isFlutterWebAppNow ? 'web' : 'native',
        isProfileBuildNow! ? '(profile build)' : '(debug build)',
      ]);
    } else {
      identifiers.addAll(['Dart', isDartWebAppNow! ? 'web' : 'CLI']);
    }
    return identifiers.join(' ');
  }

  bool get isIosApp => operatingSystem == 'ios';
}

class AutocompleteCache {
  final classes = <ClassRef, Class>{};

  /// Cache of autocomplete matches for a library for code written within that
  /// library.
  ///
  /// This cache includes autocompletes from all libraries imported and exported
  /// by the library as well as all private autocompletes for the library.
  final libraryMemberAndImportsAutocomplete =
      <LibraryRef, Future<Set<String?>>>{};

  /// Cache of autocomplete matches to show for a library when that library is
  /// imported.
  ///
  /// This cache includes autocompletes from libraries exported by the library
  /// but does not include autocompletes for libraries imported by this library.
  final libraryMemberAutocomplete = <LibraryRef, Future<Set<String?>>>{};

  void _clear() {
    classes.clear();
    libraryMemberAndImportsAutocomplete.clear();
    libraryMemberAutocomplete.clear();
  }
}

class AppState extends DisposableController with AutoDisposeControllerMixin {
  AppState(ValueListenable<IsolateRef?> isolateRef) {
    addAutoDisposeListener(isolateRef, () => cache._clear());
  }

  // TODO(polina-c): add explanation for variables.
  ValueListenable<List<DartObjectNode>> get variables => _variables;
  final _variables = ValueNotifier<List<DartObjectNode>>([]);
  void setVariables(List<DartObjectNode> value) => _variables.value = value;

  ValueListenable<List<DapObjectNode>> get dapVariables => _dapVariables;
  final _dapVariables = ValueNotifier<List<DapObjectNode>>([]);
  void setDapVariables(List<DapObjectNode> value) =>
      _dapVariables.value = value;

  ValueListenable<Frame?> get currentFrame => _currentFrame;
  final _currentFrame = ValueNotifier<Frame?>(null);
  void setCurrentFrame(Frame? value) => _currentFrame.value = value;

  final evalHistory = EvalHistory();

  final cache = AutocompleteCache();

  @override
  void dispose() {
    _variables.dispose();
    _currentFrame.dispose();
    super.dispose();
  }
}
