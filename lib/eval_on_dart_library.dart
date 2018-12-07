import 'dart:async';
import 'package:vm_service_lib/vm_service_lib.dart';

import 'globals.dart';

class EvalOnDartLibrary {
  EvalOnDartLibrary(String libraryName, VmService service) {
    _libraryName = libraryName;
    _service = service;
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

  String _libraryName;
  Completer<LibraryRef> _libraryRef;
  VmService _service;
  String _isolateId;

  void _initialize(String isolateId) async {
    _isolateId = isolateId;

    _service.getIsolate(_isolateId).then<dynamic>((dynamic value) {
      if (value is Isolate) {
        for (LibraryRef library in value.libraries) {
          if (library.uri == _libraryName) {
            _libraryRef.complete(library);
            return;
          }
        }
        _libraryRef.completeError('Library $_libraryName not found.');
      }
    }).catchError((RPCError e) => print('RPCError ${e.code}: ${e.details}'));
  }

  Completer<InstanceRef> eval(String expression) {
    final Completer<InstanceRef> future = new Completer<InstanceRef>();
    _libraryRef.future.then((LibraryRef ref) {
      _service
          .evaluate(_isolateId, ref.id, expression)
          .then<dynamic>((dynamic response) => future.complete(response))
          .catchError((RPCError e) => print('RPCError ${e.code}: ${e.details}'))
          .catchError((Error e) => print('${e.kind}: ${e.message}'));
    });
    return future;
  }
}
