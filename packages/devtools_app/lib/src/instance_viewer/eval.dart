/// A few utilities related to evaluating dart code
library eval;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../eval_on_dart_library.dart';
import '../globals.dart';

/// An [EvalOnDartLibrary] that has access to no specific library in particular
///
/// Not suitable to be used when evaluating third-party objects, as it would
/// otherwise not be possible to read private properties.
final evalProvider = Provider<EvalOnDartLibrary>((ref) {
  final eval = EvalOnDartLibrary(['dart:io'], serviceManager.service);
  ref.onDispose(eval.dispose);
  return eval;
});

/// An [EvalOnDartLibrary] that has access to `provider`
final providerEvalProvider = Provider<EvalOnDartLibrary>((ref) {
  final eval = EvalOnDartLibrary(
    ['package:provider/src/provider.dart'],
    serviceManager.service,
  );

  ref.onDispose(eval.dispose);
  return eval;
});

/// An [EvalOnDartLibrary] that has access to `riverpod`
final riverpodEvalProvider = Provider<EvalOnDartLibrary>((ref) {
  final eval = EvalOnDartLibrary(
    ['package:riverpod/src/provider.dart'],
    serviceManager.service,
  );

  ref.onDispose(eval.dispose);
  return eval;
});

/// An [EvalOnDartLibrary] for custom objects.
final libraryEvalProvider =
    AutoDisposeProviderFamily<EvalOnDartLibrary, String>((ref, libraryPath) {
  final eval = EvalOnDartLibrary([libraryPath], serviceManager.service);

  ref.onDispose(eval.dispose);
  return eval;
});
