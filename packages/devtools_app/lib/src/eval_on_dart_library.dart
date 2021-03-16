// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This code is directly based on src/io/flutter/inspector/EvalOnDartLibrary.java
// If you add a method to this class you should also add it to EvalOnDartLibrary.java
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import 'config_specific/logger/logger.dart';
import 'globals.dart';
import 'inspector/inspector_service.dart';
import 'vm_service_wrapper.dart';

abstract class Disposable {
  bool get disposed;

  void dispose();
}

class IsAlive extends Disposable {
  @override
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }
}

class EvalOnDartLibrary {
  EvalOnDartLibrary(
    Iterable<String> candidateLibraryNames,
    this.service, {
    String isolateId,
  }) : _candidateLibraryNames = Set.from(candidateLibraryNames) {
    _libraryRef = Completer<LibraryRef>();

    // For evals in tests, we will pass the isolateId into the constructor.
    if (isolateId != null) {
      _init(isolateId, false);
    } else {
      selectedIsolateStreamSubscription = serviceManager.isolateManager
          .getSelectedIsolate((IsolateRef isolate) {
        final String id = isolate?.id;
        _initializeComplete = null;
        _init(id, isolate == null);
      });
    }
  }

  Future<void> _init(String isolateId, bool isIsolateNull) async {
    await _initializeComplete;

    if (_libraryRef.isCompleted) {
      _libraryRef = Completer<LibraryRef>();
    }

    if (!isIsolateNull) {
      _initializeComplete = _initialize(isolateId);
    }
  }

  bool get disposed => _disposed;
  bool _disposed = false;

  void dispose() {
    selectedIsolateStreamSubscription.cancel();
    _disposed = true;
  }

  final Set<String> _candidateLibraryNames;
  final VmServiceWrapper service;
  Future<void> _initializeComplete;
  StreamSubscription selectedIsolateStreamSubscription;

  String get isolateId => _isolateId;
  String _isolateId;

  Completer<LibraryRef> _libraryRef;
  Future<LibraryRef> get libraryRef => _libraryRef.future;
  Completer allPendingRequestsDone;

  Isolate get isolate => _isolate;
  Isolate _isolate;

  Future<void> _initialize(String isolateId) async {
    _isolateId = isolateId;

    try {
      final Isolate isolate = await service.getIsolate(_isolateId);
      _isolate = isolate;
      if (isolate == null || _libraryRef.isCompleted) {
        // Nothing to do here.
        return;
      }
      for (LibraryRef library in isolate.libraries) {
        if (_candidateLibraryNames.contains(library.uri)) {
          assert(!_libraryRef.isCompleted);
          _libraryRef.complete(library);
          return;
        }
      }
      assert(!_libraryRef.isCompleted);
      _libraryRef.completeError(LibraryNotFound(_candidateLibraryNames));
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  Future<InstanceRef> eval(
    String expression, {
    @required Disposable isAlive,
    Map<String, String> scope,
  }) {
    return addRequest(isAlive, () => _eval(expression, scope: scope));
  }

  Future<LibraryRef> _waitForLibraryRef() async {
    while (true) {
      final libraryRef = await _libraryRef.future;
      if (_libraryRef.isCompleted) {
        // Avoid race condition where a new isolate loaded
        // while we were waiting for the library ref.
        return libraryRef;
      }
    }
  }

  Future<InstanceRef> _eval(
    String expression, {
    @required Map<String, String> scope,
  }) async {
    if (_disposed) return null;

    try {
      final libraryRef = await _waitForLibraryRef();
      if (libraryRef == null) return null;
      final result = await service.evaluate(
        _isolateId,
        libraryRef.id,
        expression,
        scope: scope,
        disableBreakpoints: true,
      );
      if (result is Sentinel) {
        return null;
      }
      if (result is ErrorRef) {
        throw result;
      }
      return result;
    } catch (e, stack) {
      _handleError('$e - $expression', stack);
    }
    return null;
  }

  void _handleError(dynamic e, StackTrace stack) {
    if (_disposed) return;

    switch (e.runtimeType) {
      case RPCError:
        log('RPCError: $e', LogLevel.error);
        break;
      case Error:
        log('${e.kind}: ${e.message}', LogLevel.error);
        break;
      default:
        log('Unrecognized error: $e', LogLevel.error);
    }
    if (stack != null) {
      log(stack.toString(), LogLevel.error);
    }
  }

  Future<Library> getLibrary(LibraryRef instance, Disposable isAlive) {
    return getObjHelper(instance, isAlive);
  }

  Future<Class> getClass(ClassRef instance, Disposable isAlive) {
    return getObjHelper(instance, isAlive);
  }

  Future<Func> getFunc(FuncRef instance, Disposable isAlive) {
    return getObjHelper(instance, isAlive);
  }

  Future<Instance> getInstance(
    FutureOr<InstanceRef> instanceRefFuture,
    Disposable isAlive,
  ) async {
    return await getObjHelper(await instanceRefFuture, isAlive);
  }

  Future<int> getHashCode(
    InstanceRef instance, {
    @required Disposable isAlive,
  }) async {
    final hash = await evalInstance(
      'instance.hashCode',
      isAlive: isAlive,
      scope: {'instance': instance.id},
    );

    return int.parse(hash.valueAsString);
  }

  /// Eval an expression and immediately obtain its [Instance].
  Future<Instance> evalInstance(
    String expression, {
    @required Disposable isAlive,
    Map<String, String> scope,
  }) async {
    final ref = await safeEval(expression, isAlive: isAlive, scope: scope);
    if (ref == null) return null;

    return getInstance(ref, isAlive);
  }

  static int _nextAsyncEvalId = 0;

  EvalOnDartLibrary _dartDeveloperEvalCache;
  EvalOnDartLibrary get _dartDeveloperEval {
    return _dartDeveloperEvalCache ??= EvalOnDartLibrary(
      const ['dart:developer'],
      service,
    );
  }

  EvalOnDartLibrary _widgetInspectorEvalCache;
  EvalOnDartLibrary get _widgetInspectorEval {
    return _widgetInspectorEvalCache ??= EvalOnDartLibrary(
      inspectorLibraryUriCandidates,
      service,
    );
  }

  /// A [safeEval] variant that can use `await`.
  ///
  /// This is useful to obtain the value emitted by a future, by potentially doing:
  ///
  /// ```dart
  /// final result = await asyncEval('await Future.value(42)');
  /// ```
  ///
  /// where `result` will be an [InstanceRef] that points to `42`.
  ///
  /// If the [FutureOr] awaited threw, [asyncEval] will throw a [FutureFailedException],
  /// which can be caught to access the [StackTrace] and error.
  Future<InstanceRef> asyncEval(
    String expression, {
    @required Disposable isAlive,
    Map<String, String> scope,
  }) async {
    final id = _nextAsyncEvalId++;

    // start awaiting the event before starting the evaluation, in case the
    // event is received before the eval function completes.
    final future = serviceManager.service.onExtensionEvent.firstWhere((event) {
      return event.extensionKind == 'future_completed' &&
          event.extensionData.data['id'] == id;
    });

    final readerGroup = 'asyncEval-$id';

    /// Workaround to not being able to import libraries directly from an evaluation
    final postEventRef = await _dartDeveloperEval.safeEval(
      'postEvent',
      isAlive: isAlive,
    );
    final widgetInspectorServiceRef = await _widgetInspectorEval.safeEval(
      'WidgetInspectorService.instance',
      isAlive: isAlive,
    );

    final readerId = await safeEval(
      // since we are awaiting the Future, we need to make sure that during the awaiting,
      // the "reader" is not GCed
      'widgetInspectorService.toId(<dynamic>[], "$readerGroup")',
      isAlive: isAlive,
      scope: {'widgetInspectorService': widgetInspectorServiceRef.id},
    ).then((ref) => ref.valueAsString);

    await safeEval(
      '() async {'
      '  final reader = widgetInspectorService.toObject("$readerId", "$readerGroup") as List;'
      '  try {'
      '    final result = $expression;'
      '    reader.add(result);'
      '  } catch (err, stack) {'
      '    reader.add(err);'
      '    reader.add(stack);'
      '  } finally {'
      '    postEvent("future_completed", {"id": $id});'
      '  }'
      '}()',
      isAlive: isAlive,
      scope: {
        ...?scope,
        'postEvent': postEventRef.id,
        'widgetInspectorService': widgetInspectorServiceRef.id,
      },
    );

    await future;

    final resultRef = await evalInstance(
      '() {'
      '  final result = widgetInspectorService.toObject("$readerId", "$readerGroup") as List;'
      '  widgetInspectorService.disposeGroup("$readerGroup");'
      '  return result;'
      '}()',
      isAlive: isAlive,
      scope: {'widgetInspectorService': widgetInspectorServiceRef.id},
    );

    assert(resultRef.length == 1 || resultRef.length == 2);
    if (resultRef.length == 2) {
      throw FutureFailedException(
        expression,
        resultRef.elements[0],
        resultRef.elements[1],
      );
    }

    return resultRef.elements[0];
  }

  /// An [eval] that throws when a [Sentinel]/error occurs or if [isAlive] was
  /// disposed while the request was pending.
  ///
  /// If `isAlive` was disposed while the request was pending, will throw a [CancelledException].
  Future<InstanceRef> safeEval(
    String expression, {
    @required Disposable isAlive,
    Map<String, String> scope,
  }) async {
    Object result;

    try {
      if (disposed) {
        throw StateError(
          'Called `safeEval` on a disposed `EvalOnDartLibrary` instance',
        );
      }

      result = await addRequest(isAlive, () async {
        final libraryRef = await _waitForLibraryRef();

        return await service.evaluate(
          isolateId,
          libraryRef.id,
          expression,
          scope: scope,
        );
      });

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
    } catch (err, stack) {
      _handleError(err, stack);
      rethrow;
    }

    // We throw if the request was canceled instead of returning `null` because
    // `null` is a valid value for `InstanceRef` (when the evaluation returns `null`).
    // This could confuse the caller into believing that the evaluation suceeded
    // and perform extra operations, when in fact the caller should stop all operations.
    if (isAlive.disposed) {
      // throw outside of the try/catch to not log this exception, since
      // "cancelled" is an expected exception.
      throw CancelledException('safeEval');
    }

    return result;
  }

  /// Public so that other related classes such as InspectorService can ensure
  /// their requests are in a consistent order with existing requests. This
  /// eliminates otherwise surprising timing bugs, such as if a request to
  /// dispose an InspectorService.ObjectGroup was issued after a request to read
  /// properties from an object in a group, but the request to dispose the
  /// object group occurred first.
  ///
  /// With this design, we have at most 1 pending request at a time. This
  /// sacrifices some throughput, but we gain the advantage of predictable
  /// semantics and the ability to skip large numbers of requests from object
  /// groups that should no longer be kept alive.
  ///
  /// The optional ObjectGroup specified by [isAlive] indicates whether the
  /// request is still relevant or should be cancelled. This is an optimization
  /// for the Inspector so that it does not overload the service with stale requests.
  /// Stale requests will be generated if the user is quickly navigating through the
  /// UI to view specific details subtrees.
  Future<T> addRequest<T>(Disposable isAlive, Future<T> request()) async {
    if (isAlive != null && isAlive.disposed) return null;

    // Future that completes when the request has finished.
    final Completer<T> response = Completer();
    // This is an optimization to avoid sending stale requests across the wire.
    void wrappedRequest() async {
      if (isAlive != null && isAlive.disposed || _disposed) {
        response.complete(null);
        return;
      }
      try {
        final Object value = await request();
        if (!_disposed && value is! Sentinel) {
          response.complete(value);
        } else {
          response.complete(null);
        }
      } catch (e) {
        if (_disposed || isAlive?.disposed == true) {
          response.complete(null);
        } else {
          response.completeError(e);
        }
      }
    }

    if (allPendingRequestsDone == null || allPendingRequestsDone.isCompleted) {
      allPendingRequestsDone = response;
      wrappedRequest();
    } else {
      if (isAlive != null && isAlive.disposed || _disposed) {
        response.complete(null);
        return response.future;
      }

      final Future previousDone = allPendingRequestsDone.future;
      allPendingRequestsDone = response;
      // Schedule this request only after the previous request completes.
      try {
        await previousDone;
      } catch (e) {
        if (!_disposed) {
          log(e.toString(), LogLevel.error);
        }
      }
      wrappedRequest();
    }
    return response.future;
  }

  Future<T> getObjHelper<T extends Obj>(
    ObjRef instance,
    Disposable isAlive, {
    int offset,
    int count,
  }) {
    return addRequest<T>(isAlive, () async {
      final T value = await service.getObject(
        _isolateId,
        instance.id,
        offset: offset,
        count: count,
      );
      return value;
    });
  }

  Future<String> retrieveFullValueAsString(InstanceRef stringRef) {
    return service.retrieveFullStringValue(_isolateId, stringRef);
  }
}

class LibraryNotFound implements Exception {
  LibraryNotFound(this.candidateNames);

  Iterable<String> candidateNames;

  String get message => 'Library matchining one of $candidateNames not found';
}

class FutureFailedException implements Exception {
  FutureFailedException(this.expression, this.errorRef, this.stacktraceRef);

  final String expression;
  final InstanceRef errorRef;
  final InstanceRef stacktraceRef;

  @override
  String toString() {
    return 'The future from the expression `$expression` failed.';
  }
}

class CancelledException implements Exception {
  CancelledException(this.operationName);

  final String operationName;

  @override
  String toString() {
    return 'The operation $operationName was cancelled';
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

  @override
  String toString() {
    return 'SentinelException(sentinel: $sentinel)';
  }
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
