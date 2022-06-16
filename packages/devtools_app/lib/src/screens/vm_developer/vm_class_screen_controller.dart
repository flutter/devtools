import 'package:flutter/foundation.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/auto_dispose.dart';
import '../../service/vm_service_wrapper.dart';
import '../../shared/globals.dart';
import '../debugger/debugger_model.dart';

/// Auto DisposableController for fetching and displaying data on the class screen.
class ClassScreenController extends DisposableController
    with AutoDisposeControllerMixin {
  ClassScreenController(ObjRef? objRef) {
    _classRef = objRef as ClassRef;
    refresh();
  }

  VmServiceWrapper get _service => serviceManager.service!;

  IsolateRef? _isolate;
  ClassRef? _classRef;

  Class? get clazz => _clazz;
  Class? _clazz;

  InstanceSet? get instances => _instances;
  InstanceSet? _instances;

  String? get scriptUri => _scriptUri;
  String? _scriptUri;

  SourcePosition? get pos => _pos;
  SourcePosition? _pos;

  ValueListenable<bool> get refreshing => _refreshing;
  final _refreshing = ValueNotifier<bool>(false);

  Future<void> refresh() async {
    final isolateRef = serviceManager.isolateManager.selectedIsolate.value!;
    _isolate = await _service.getIsolate(isolateRef.id!);
    _clazz = await _service.getObject(_isolate!.id!, _classRef!.id!) as Class?;
    _instances =
        await _service.getInstances(_isolate!.id!, _classRef!.id!, 100);

    if (_clazz?.location != null) {
      final script = await _service.getObject(
        _isolate!.id!,
        _clazz!.location!.script!.id!,
      );
      _scriptUri = _clazz!.location!.script!.uri;
      _pos = SourcePosition.calculatePosition(
        script as Script,
        _clazz!.location!.tokenPos!,
      );
    }

    _refreshing.value = !_refreshing.value;
  }
}
