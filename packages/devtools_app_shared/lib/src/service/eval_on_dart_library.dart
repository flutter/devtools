// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This code is directly based on src/io/flutter/inspector/EvalOnDartLibrary.java
// If you add a method to this class you should also add it to EvalOnDartLibrary.java
import 'dart:async';
import 'dart:core' hide Error;
import 'dart:core' as core;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart' hide Error;
import 'package:vm_service/vm_service.dart' as vm_service;

import '../utils/auto_dispose.dart';
import 'service_manager.dart';
import 'service_utils.dart';

final _log = Logger('eval_on_dart_library');

class Disposable {
  bool disposed = false;

  @mustCallSuper
  void dispose() {
    disposed = true;
  }
}

// TODO(https://github.com/flutter/devtools/issues/6239): try to remove this.
@sealed
class EvalOnDartLibrary extends DisposableController
    with AutoDisposeControllerMixin {
  EvalOnDartLibrary(
    this.libraryName,
    this.service, {
    required this.serviceManager,
    ValueListenable<IsolateRef?>? isolate,
    this.disableBreakpoints = true,
    this.oneRequestAtATime = false,
  }) : _clientId = Random().nextInt(1000000000) {
    _libraryRef = Completer<LibraryRef>();

    // For evals in tests, we will pass the isolateId into the constructor.
    isolate ??= serviceManager.isolateManager.mainIsolate;
    addAutoDisposeListener(isolate, () => _init(isolate!.value));
    _init(isolate.value);
  }

  /// Whether to wait for one request to complete before issuing another
  /// request.
  ///
  /// This makes it possible to cancel requests and provides clear ordering
  /// guarantees but significantly hurts performance particularly when the
  /// VM Service and DevTools are not running on the same machine.
  final bool oneRequestAtATime;

  /// Whether to disable breakpoints triggered while evaluating expressions.
  final bool disableBreakpoints;

  /// An ID unique to this instance, so that [asyncEval] keeps working even if
  /// the devtool is opened on multiple tabs at the same time.
  final int _clientId;

  /// The service manager to use for this instance of [EvalOnDartLibrary].
  final ServiceManager serviceManager;

  void _init(IsolateRef? isolateRef) {
    if (_isolateRef == isolateRef) return;

    _currentRequestId++;
    _isolateRef = isolateRef;
    if (_libraryRef.isCompleted) {
      _libraryRef = Completer();
    }

    if (isolateRef != null) {
      unawaited(_initialize(isolateRef, _currentRequestId));
    }
  }

  bool get disposed => _disposed;
  bool _disposed = false;

  @override
  void dispose() {
    _dartDeveloperEvalCache?.dispose();
    _widgetInspectorEvalCache?.dispose();
    _disposed = true;
    super.dispose();
  }

  final String libraryName;
  final VmService service;

  IsolateRef? get isolateRef => _isolateRef;
  IsolateRef? _isolateRef;

  int _currentRequestId = 0;

  late Completer<LibraryRef> _libraryRef;
  Future<LibraryRef> get libraryRef => _libraryRef.future;

  Completer? allPendingRequestsDone;

  Isolate? get isolate => _isolate;
  Isolate? _isolate;

  Future<void> _initialize(IsolateRef isolateRef, int requestId) async {
    if (_currentRequestId != requestId) {
      // The initialize request is obsolete.
      return;
    }

    try {
      final Isolate? isolate =
          await serviceManager.isolateManager.isolateState(isolateRef).isolate;
      if (_currentRequestId != requestId) {
        // The initialize request is obsolete.
        return;
      }
      _isolate = isolate;
      for (LibraryRef library in isolate?.libraries ?? []) {
        if (libraryName == library.uri) {
          assert(!_libraryRef.isCompleted);
          _libraryRef.complete(library);
          return;
        }
      }
      assert(!_libraryRef.isCompleted);
      _libraryRef.completeError(LibraryNotFound(libraryName));
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  Future<InstanceRef?> eval(
    String expression, {
    required Disposable? isAlive,
    Map<String, String>? scope,
    bool shouldLogError = true,
  }) async {
    if ((scope?.isNotEmpty ?? false) &&
        serviceManager.connectedApp!.isDartWebAppNow!) {
      final result = await eval(
        '(${scope!.keys.join(',')}) => $expression',
        isAlive: isAlive,
        shouldLogError: shouldLogError,
      );
      if (result == null || (isAlive?.disposed ?? true)) return null;
      return await invoke(
        result,
        'call',
        scope.values.toList(),
        isAlive: isAlive,
        shouldLogError: shouldLogError,
      );
    }
    return await addRequest<InstanceRef?>(
      isAlive,
      () => _eval(
        expression,
        scope: scope,
        shouldLogError: shouldLogError,
      ),
    );
  }

  Future<InstanceRef?> invoke(
    InstanceRef instanceRef,
    String name,
    List<String> argRefs, {
    required Disposable? isAlive,
    bool shouldLogError = true,
  }) {
    return addRequest(
      isAlive,
      () => _invoke(
        instanceRef,
        name,
        argRefs,
        shouldLogError: shouldLogError,
      ).then((value) => value!),
    );
  }

  Future<LibraryRef> _waitForLibraryRef() async {
    while (true) {
      final id = _currentRequestId;
      final libraryRef = await _libraryRef.future;
      if (_libraryRef.isCompleted && _currentRequestId == id) {
        // Avoid race condition where a new isolate loaded
        // while we were waiting for the library ref.
        // TODO(jacobr): checking the isolateRef matches the isolateRef when the method started.
        return libraryRef;
      }
    }
  }

  Future<InstanceRef?> _eval(
    String expression, {
    required Map<String, String>? scope,
    bool shouldLogError = true,
  }) async {
    if (_disposed) return null;

    try {
      final libraryRef = await _waitForLibraryRef();
      final result = await service.evaluate(
        _isolateRef!.id!,
        libraryRef.id!,
        expression,
        scope: scope,
        disableBreakpoints: disableBreakpoints,
      );
      if (result is Sentinel) {
        return null;
      }
      if (result is ErrorRef) {
        throw result;
      }
      return result as FutureOr<InstanceRef?>;
    } catch (e, stack) {
      if (shouldLogError) {
        _handleError('$e - $expression', stack);
      }
    }
    return null;
  }

  Future<InstanceRef?> _invoke(
    InstanceRef instanceRef,
    String name,
    List<String> argRefs, {
    bool shouldLogError = true,
  }) async {
    if (_disposed) return null;

    try {
      final result = await service.invoke(
        _isolateRef!.id!,
        instanceRef.id!,
        name,
        argRefs,
        disableBreakpoints: disableBreakpoints,
      );
      if (result is Sentinel) {
        return null;
      }
      if (result is ErrorRef) {
        throw result;
      }
      return result as FutureOr<InstanceRef?>;
    } catch (e, stack) {
      if (shouldLogError) {
        _handleError('$e - $name', stack);
      }
    }
    return null;
  }

  void _handleError(Object e, StackTrace stack) {
    if (_disposed) return;

    if (e is RPCError) {
      _log.shout('RPCError: $e', e, stack);
    } else if (e is vm_service.Error) {
      _log.shout('${e.kind}: ${e.message}', e, stack);
    } else {
      _log.shout('Unrecognized error: $e', e, stack);
    }
    _log.shout(stack.toString(), e, stack);
  }

  T _verifySaneValue<T>(T? value, Disposable? isAlive) {
    /// Throwing when the request is cancelled instead of returning `null`
    /// allows easily chaining eval calls, without having to check "disposed"
    /// between each request.
    /// It also removes the need for using `!` once the devtool is migrated to NNBD
    if (isAlive?.disposed ?? true) {
      // throw before _handleError as we don't want to log cancellations.
      throw CancelledException();
    }

    if (value == null) {
      throw StateError('Expected an instance of $T but received null');
    }

    return value;
  }

  Future<Library?> getLibrary(LibraryRef instance, Disposable isAlive) {
    return getObjHelper(instance, isAlive);
  }

  Future<Class?> getClass(ClassRef instance, Disposable isAlive) {
    return getObjHelper(instance, isAlive);
  }

  Future<Class> safeGetClass(ClassRef instance, Disposable isAlive) async {
    final value = await getObjHelper<Class>(instance, isAlive);
    return _verifySaneValue(value, isAlive);
  }

  Future<Func?> getFunc(FuncRef instance, Disposable isAlive) {
    return getObjHelper(instance, isAlive);
  }

  Future<Instance?> getInstance(
    FutureOr<InstanceRef> instanceRefFuture,
    Disposable? isAlive,
  ) async {
    return await getObjHelper(await instanceRefFuture, isAlive);
  }

  Future<Instance> safeGetInstance(
    FutureOr<InstanceRef> instanceRefFuture,
    Disposable? isAlive,
  ) async {
    final instanceRef = await instanceRefFuture;
    final value = await getObjHelper<Instance>(instanceRef, isAlive);
    return _verifySaneValue(value, isAlive);
  }

  Future<int> getHashCode(
    InstanceRef instance, {
    required Disposable? isAlive,
  }) async {
    // identityHashCode will be -1 if the Flutter SDK is not recent enough
    if (instance.identityHashCode != -1 && instance.identityHashCode != null) {
      return instance.identityHashCode!;
    }

    final hash = await evalInstance(
      'instance.hashCode',
      isAlive: isAlive,
      scope: {'instance': instance.id!},
    );

    return int.parse(hash.valueAsString!);
  }

  /// Eval an expression and immediately obtain its [Instance].
  Future<Instance> evalInstance(
    String expression, {
    required Disposable? isAlive,
    Map<String, String>? scope,
  }) {
    return safeGetInstance(
      // This is safe to do because `safeEval` will throw instead of returning `null`
      // when the request is cancelled, so `getInstance` will not receive `null`
      // as parameter.
      safeEval(expression, isAlive: isAlive, scope: scope),
      isAlive,
    );
  }

  static int _nextAsyncEvalId = 0;

  EvalOnDartLibrary? _dartDeveloperEvalCache;
  EvalOnDartLibrary get _dartDeveloperEval {
    return _dartDeveloperEvalCache ??= EvalOnDartLibrary(
      'dart:developer',
      service,
      serviceManager: serviceManager,
    );
  }

  EvalOnDartLibrary? _widgetInspectorEvalCache;
  EvalOnDartLibrary get _widgetInspectorEval {
    return _widgetInspectorEvalCache ??= EvalOnDartLibrary(
      'package:flutter/src/widgets/widget_inspector.dart',
      service,
      serviceManager: serviceManager,
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
  Future<InstanceRef?> asyncEval(
    String expression, {
    required Disposable? isAlive,
    Map<String, String>? scope,
  }) async {
    final futureId = _nextAsyncEvalId++;

    // start awaiting the event before starting the evaluation, in case the
    // event is received before the eval function completes.
    final future = serviceManager.service!.onExtensionEvent.firstWhere((event) {
      return event.extensionKind == 'future_completed' &&
          event.extensionData!.data['future_id'] == futureId &&
          // Using `_clientId` here as if two chrome tabs open the devtool, it is
          // possible to have conflicts on `future_id`
          event.extensionData!.data['client_id'] == _clientId;
    });

    final readerGroup = 'asyncEval-$futureId';

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
      scope: {'widgetInspectorService': widgetInspectorServiceRef.id!},
    ).then((ref) => ref.valueAsString!);

    await safeEval(
      '() async {'
      '  final reader = widgetInspectorService.toObject("$readerId", "$readerGroup") as List;'
      '  try {'
      // Cast as dynamic so that it is possible to await Future<void>
      '    dynamic result = ($expression) as dynamic;'
      '    reader.add(result);'
      '  } catch (err, stack) {'
      '    reader.add(err);'
      '    reader.add(stack);'
      '  } finally {'
      '    postEvent("future_completed", {"future_id": $futureId, "client_id": $_clientId});'
      '  }'
      '}()',
      isAlive: isAlive,
      scope: {
        ...?scope,
        'postEvent': postEventRef.id!,
        'widgetInspectorService': widgetInspectorServiceRef.id!,
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
      scope: {'widgetInspectorService': widgetInspectorServiceRef.id!},
    );

    assert(resultRef.length == 1 || resultRef.length == 2);
    if (resultRef.length == 2) {
      throw FutureFailedException(
        expression,
        resultRef.elements![0],
        resultRef.elements![1],
      );
    }

    return resultRef.elements![0];
  }

  /// An [eval] that throws when a [Sentinel]/error occurs or if [isAlive] was
  /// disposed while the request was pending.
  ///
  /// If `isAlive` was disposed while the request was pending, will throw a [CancelledException].
  Future<InstanceRef> safeEval(
    String expression, {
    required Disposable? isAlive,
    Map<String, String>? scope,
  }) async {
    Object? result;

    try {
      if (disposed) {
        throw StateError(
          'Called `safeEval` on a disposed `EvalOnDartLibrary` instance',
        );
      }

      result = await addRequest(isAlive, () async {
        final libraryRef = await _waitForLibraryRef();

        return await service.evaluate(
          isolateRef!.id!,
          libraryRef.id!,
          expression,
          scope: scope,
          disableBreakpoints: disableBreakpoints,
        );
      });

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
      /// Throwing when the request is cancelled instead of returning `null`
      /// allows easily chaining eval calls, without having to check "disposed"
      /// between each request.
      /// It also removes the need for using `!` once the devtool is migrated to NNBD
      if (isAlive?.disposed ?? true) {
        // throw before _handleError as we don't want to log cancellations.
        core.Error.throwWithStackTrace(CancelledException(), stack);
      }

      _handleError(err, stack);
      rethrow;
    }

    return result;
  }

  /// Public so that other related classes such as InspectorService can ensure
  /// their requests are in a consistent order with existing requests.
  ///
  /// When [oneRequestAtATime] is true, using this method
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
  Future<T?> addRequest<T>(
    Disposable? isAlive,
    Future<T?> Function() request,
  ) async {
    if (isAlive != null && isAlive.disposed) return null;

    if (!oneRequestAtATime) {
      return request();
    }
    // Future that completes when the request has finished.
    final Completer<T?> response = Completer();
    // This is an optimization to avoid sending stale requests across the wire.
    void wrappedRequest() async {
      if (isAlive != null && isAlive.disposed || _disposed) {
        response.complete(null);
        return;
      }
      try {
        final value = await request();
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

    if (allPendingRequestsDone == null || allPendingRequestsDone!.isCompleted) {
      allPendingRequestsDone = response;
      wrappedRequest();
    } else {
      if (isAlive != null && isAlive.disposed || _disposed) {
        response.complete(null);
        return response.future;
      }

      final Future previousDone = allPendingRequestsDone!.future;
      allPendingRequestsDone = response;
      // Schedule this request only after the previous request completes.
      try {
        await previousDone;
      } catch (e, st) {
        if (!_disposed) {
          _log.shout(e, e, st);
        }
      }
      wrappedRequest();
    }
    return response.future;
  }

  Future<T?> getObjHelper<T extends Obj>(
    ObjRef instance,
    Disposable? isAlive, {
    int? offset,
    int? count,
  }) {
    return addRequest<T>(isAlive, () async {
      final T value = await service.getObject(
        _isolateRef!.id!,
        instance.id!,
        offset: offset,
        count: count,
      ) as T;
      return value;
    });
  }

  Future<String?> retrieveFullValueAsString(InstanceRef stringRef) {
    return service.retrieveFullStringValue(_isolateRef!.id!, stringRef);
  }
}

final class LibraryNotFound implements Exception {
  LibraryNotFound(this.name);

  final String name;

  String get message => 'Library matchining $name not found';
}

final class FutureFailedException implements Exception {
  FutureFailedException(this.expression, this.errorRef, this.stacktraceRef);

  final String expression;
  final InstanceRef errorRef;
  final InstanceRef stacktraceRef;

  @override
  String toString() {
    return 'The future from the expression `$expression` failed.';
  }
}

final class CancelledException implements Exception {}

final class UnknownEvalException implements Exception {
  UnknownEvalException({
    required this.expression,
    required this.scope,
    required this.exception,
  });

  final String expression;
  final Object? exception;
  final Map<String, String?>? scope;

  @override
  String toString() {
    return 'Unknown error during the evaluation of `$expression`: $exception';
  }
}

final class SentinelException implements Exception {
  SentinelException(this.sentinel);

  final Sentinel sentinel;

  @override
  String toString() {
    return 'SentinelException(sentinel: $sentinel)';
  }
}

final class EvalSentinelException extends SentinelException {
  EvalSentinelException({
    required this.expression,
    required this.scope,
    required Sentinel sentinel,
  }) : super(sentinel);

  final String expression;
  final Map<String, String?>? scope;

  @override
  String toString() {
    return 'Evaluation `$expression` returned the Sentinel $sentinel';
  }
}

final class EvalErrorException implements Exception {
  EvalErrorException({
    required this.expression,
    required this.scope,
    required this.errorRef,
  });

  final ErrorRef errorRef;
  final String expression;
  final Map<String, String?>? scope;

  @override
  String toString() {
    return 'Evaluation `$expression` failed with $errorRef';
  }
}
