// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This code is directly based on src/io/flutter/inspector/EvalOnDartLibrary.java
// If you add a method to this class you should also add it to EvalOnDartLibrary.java
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'globals.dart';
import 'inspector/inspector_service.dart';
import 'vm_service_wrapper.dart';

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

  bool _disposed = false;

  void dispose() {
    selectedIsolateStreamSubscription.cancel();
    _disposed = true;
  }

  final Set<String> _candidateLibraryNames;
  final VmServiceWrapper service;
  Completer<LibraryRef> _libraryRef;
  Future<void> _initializeComplete;
  StreamSubscription selectedIsolateStreamSubscription;

  String get isolateId => _isolateId;
  String _isolateId;

  Future<LibraryRef> get libraryRef => _libraryRef.future;
  Completer allPendingRequestsDone;

  Future<void> _initialize(String isolateId) async {
    _isolateId = isolateId;

    try {
      final Isolate isolate = await service.getIsolate(_isolateId);
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
      _libraryRef.completeError(new LibraryNotFound(_candidateLibraryNames));
    } catch (e, stack) {
      _handleError(e, stack);
    }
  }

  Future<InstanceRef> eval(
    String expression, {
    @required ObjectGroup isAlive,
    Map<String, String> scope,
  }) {
    return addRequest(isAlive, () => _eval(expression, scope: scope));
  }

  Future<InstanceRef> _eval(
    String expression, {
    @required Map<String, String> scope,
  }) async {
    if (_disposed) return null;

    try {
      LibraryRef libraryRef;
      while (true) {
        libraryRef = await _libraryRef.future;
        if (_libraryRef.isCompleted) {
          // Avoid race condition where a new isolate loaded
          // while we were waiting for the library ref.
          break;
        }
      }
      if (libraryRef == null) return null;
      final result = await service.evaluate(
        _isolateId,
        libraryRef.id,
        expression,
        scope: scope,
      );
      if (result is Sentinel) {
        return null;
      }
      if (result is ErrorRef) {
        throw result;
      }
      return result;
    } catch (e, stack) {
      _handleError(e, stack);
    }
    return null;
  }

  void _handleError(dynamic e, StackTrace stack) {
    if (_disposed) return;

    switch (e.runtimeType) {
      case RPCError:
        print('RPCError: $e');
        break;
      case Error:
        print('${e.kind}: ${e.message}');
        break;
      default:
        print('Unrecognized error: $e');
    }
    if (stack != null) {
      print(stack);
    }
  }

  Future<Library> getLibrary(LibraryRef instance, ObjectGroup isAlive) {
    return getObjHelper(instance, isAlive);
  }

  Future<Class> getClass(ClassRef instance, ObjectGroup isAlive) {
    return getObjHelper(instance, isAlive);
  }

  Future<Func> getFunc(FuncRef instance, ObjectGroup isAlive) {
    return getObjHelper(instance, isAlive);
  }

  Future<Instance> getInstance(
    FutureOr<InstanceRef> instanceRefFuture,
    ObjectGroup isAlive,
  ) async {
    return await getObjHelper(await instanceRefFuture, isAlive);
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
  Future<T> addRequest<T>(ObjectGroup isAlive, Future<T> request()) async {
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
          print(e);
        }
      }
      wrappedRequest();
    }
    return response.future;
  }

  Future<T> getObjHelper<T extends Obj>(
    ObjRef instance,
    ObjectGroup isAlive, {
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
}

class LibraryNotFound implements Exception {
  LibraryNotFound(this.candidateNames);

  Iterable<String> candidateNames;

  String get message => 'Library matchining one of $candidateNames not found';
}
