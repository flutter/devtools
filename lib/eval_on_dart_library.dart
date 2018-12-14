import 'dart:async';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'globals.dart';

class EvalOnDartLibrary {
  EvalOnDartLibrary(this.libraryName, this.service) {
    _libraryRef = new Completer<LibraryRef>();

    // TODO: do we need to dispose this subscription at some point? Where?
    serviceManager.isolateManager.getCurrentFlutterIsolate((IsolateRef isolate) {
      if (_libraryRef.isCompleted) {
        _libraryRef = new Completer<LibraryRef>();
      }

      if (isolate != null) {
        _initialize(isolate.id);
      }
    });
  }

  final String libraryName;
  final VmService service;
  Completer<LibraryRef> _libraryRef;
  String _isolateId;

  void _initialize(String isolateId) async {
    _isolateId = isolateId;

    try {
      final Isolate isolate = await service.getIsolate(_isolateId);
      for (LibraryRef library in isolate.libraries) {
        if (library.uri == libraryName) {
          _libraryRef.complete(library);
          return;
        }
      }
    } catch (e) {
      _handleError(e);
    }
  }

  Future<InstanceRef> eval(String expression) async {
    try {
      final LibraryRef libraryRef = await _libraryRef.future;
      return await service.evaluate(_isolateId, libraryRef.id, expression);
    } catch (e) {
      _handleError(e);
    }
    return null;
  }

  void _handleError(dynamic e) {
    switch (e.runtimeType) {
      case RPCError:
        print('RPCError ${e.code}: ${e.details}');
        break;
      case Error:
        print('${e.kind}: ${e.message}');
        break;
      default:
        print('Unrecognized error: $e');
    }
  }
}
