/// A few utilities related to evaluating dart code
library eval;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart' hide Error;

import '../eval_on_dart_library.dart';
import '../globals.dart';
import '../inspector/inspector_service.dart';
import 'result.dart';

/// An [EvalOnDartLibrary] that has access to `provider`
///
/// Not suitable to be used when evaluating third-party objects, as it would
/// otherwise not be possible to read private properties.
final evalProvider = Provider<EvalOnDartLibrary>((ref) {
  final eval = EvalOnDartLibrary(
    ['package:provider/src/provider.dart'],
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

Result<T> parseSentinel<T>(Object value) {
  if (value is T) {
    return Result.data(value);
  } else if (value is Sentinel) {
    return Result.error(SentinelException(value));
  } else {
    return Result.error(
      UnsupportedError('unkown type ${value.runtimeType}'),
      StackTrace.current,
    );
  }
}

extension SafeEval on EvalOnDartLibrary {
  Future<Instance> evalInstance(
    String expression, {
    @required Disposable isAlive,
    Map<String, String> scope,
  }) async {
    final ref = await safeEval(expression, isAlive: isAlive, scope: scope);

    try {
      return getInstance(ref, isAlive);
    } catch (err) {
      print('did throw');
      rethrow;
    }
  }

  static int _nextId = 0;

  /// a [safeEval] variant that does not complete until the Future evaluated completes
  ///
  /// The expression **must** return a [Future].
  ///
  /// Works only if the evaluated library includes the following code:
  ///
  /// ```dart
  /// Future<T> $await<T>(Future<T> future, String id) async {
  ///   try {
  ///     return await future;
  ///   } finally {
  ///     postEvent('future_completed', {'id': id});
  ///   }
  /// }
  /// ```
  Future<InstanceRef> awaitEval(
    String expression, {
    @required Disposable isAlive,
    Map<String, String> scope,
  }) async {
    final id = _nextId++;

    final result = await safeEval(
      '\$await($expression, "$id")',
      isAlive: isAlive,
      scope: scope,
    );

    await serviceManager.service.onExtensionEvent.firstWhere((event) {
      return event.extensionKind == 'future_completed' &&
          event.extensionData.data['id'] == '$id';
    });

    return result;
  }

  /// An `eval` that does not return `null` when a `Sentinel` or an error occurs
  Future<InstanceRef> safeEval(
    String expression, {
    @required Disposable isAlive,
    Map<String, String> scope,
  }) async {
    try {
      if (disposed) {
        throw StateError(
          'Called `safeEval` on a disposed `EvalOnDartLibrary` instance',
        );
      }

      // copied from `_eval`
      String libraryRefId;
      while (true) {
        final libraryRef = await this.libraryRef;
        if (libraryRefCompleter.isCompleted) {
          libraryRefId = libraryRef.id;
          // Avoid race condition where a new isolate loaded
          // while we were waiting for the library ref.
          break;
        }
      }

      final result = await service.evaluate(
        isolateId,
        libraryRefId,
        expression,
        scope: scope,
      );
      // end copy

      if (result == null) return null;

      if (result is! InstanceRef) {
        if (result is ErrorRef) {
          throw EvalErrorException(
            expression: expression,
            scope: scope,
            errorRef: result,
          );
        }
        if (result is Sentinel) {
          throw EvalSentinelException(
            expression: expression,
            scope: scope,
            sentinel: result,
          );
        }
        throw UnknownEvalException(
          expression: expression,
          scope: scope,
          exception: result,
        );
      }

      return result;
    } catch (err, stack) {
      handleError(err, stack);
      rethrow;
    }
  }
}

class UnknownEvalException implements Exception {
  UnknownEvalException({
    @required this.expression,
    @required this.scope,
    @required this.exception,
  });

  final String expression;
  final Object exception;
  final Map<String, String> scope;

  @override
  String toString() {
    return 'Unknown error during the evaluation of `$expression`: $exception';
  }
}

class SentinelException implements Exception {
  SentinelException(this.sentinel);

  final Sentinel sentinel;
}

class EvalSentinelException extends SentinelException {
  EvalSentinelException({
    @required this.expression,
    @required this.scope,
    @required Sentinel sentinel,
  }) : super(sentinel);

  final String expression;
  final Map<String, String> scope;

  @override
  String toString() {
    return 'Evaluation `$expression` returned the Sentinel $sentinel';
  }
}

class EvalErrorException implements Exception {
  EvalErrorException({
    @required this.expression,
    @required this.scope,
    @required this.errorRef,
  });

  final ErrorRef errorRef;
  final String expression;
  final Map<String, String> scope;

  @override
  String toString() {
    return 'Evaluation `$expression` failed with $errorRef';
  }
}
