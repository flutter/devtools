import 'dart:async';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'globals.dart';

class EvalOnDartLibrary {
  EvalOnDartLibrary(this.libraryName, this.service) {
    _libraryRef = new Completer<LibraryRef>();

    // TODO: do we need to dispose this subscription at some point? Where?
    serviceInfo.isolateManager.getCurrentFlutterIsolate((IsolateRef isolate) {
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

    final Isolate isolate = await service.getIsolate(_isolateId)
        .catchError((RPCError e) => print('RPCError ${e.code}: ${e.details}'));
    for (LibraryRef library in isolate.libraries) {
      if (library.uri == libraryName) {
        _libraryRef.complete(library);
        return;
      }
    }
  }

  Future<InstanceRef> eval(String expression) async {
    final LibraryRef libraryRef = await _libraryRef.future;
    final InstanceRef instanceRef = await service
        .evaluate(_isolateId, libraryRef.id, expression)
        .then<InstanceRef>((dynamic response) => response)
        .catchError((RPCError e) => print('RPCError ${e.code}: ${e.details}'))
        .catchError((Error e) => print('${e.kind}: ${e.message}'))
        .catchError((dynamic e) => print('Unrecognized error: $e'));
    return instanceRef;
  }
}
