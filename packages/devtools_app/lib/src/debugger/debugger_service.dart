import 'package:vm_service/vm_service.dart';

import '../globals.dart';

class DebuggerService {
  Stream<Event> get onDebugEvent => serviceManager.service.onDebugEvent;

  Stream<IsolateRef> get onSelectedIsolateChanged =>
      serviceManager.isolateManager.onSelectedIsolateChanged;

  Future<Success> pause(String isolateId) =>
      serviceManager.service.pause(isolateId);

  Future<Success> resume(String isolateId, {String step}) =>
      serviceManager.service.resume(isolateId, step: step);

  Future<void> addBreakpoint(String isolateId, String scriptId, int line) =>
      serviceManager.service.addBreakpoint(isolateId, scriptId, line);

  Future<void> removeBreakpoint(String isolateId, String breakpointId) =>
      serviceManager.service.removeBreakpoint(isolateId, breakpointId);

  Future<void> setExceptionPauseMode(String isolateId, String mode) =>
      serviceManager.service.setExceptionPauseMode(isolateId, mode);

  Future<Stack> getStack(String isolateId) =>
      serviceManager.service.getStack(isolateId);

  Future<Isolate> getIsolate(String isolateId) =>
      serviceManager.service.getIsolate(isolateId);

  Future<Script> getScript(String isolateId, String scriptId) async =>
      await getObject(isolateId, scriptId) as Script;

  Future<ScriptList> getScripts(String isolateId) =>
      serviceManager.service.getScripts(isolateId);

  Future<Obj> getObject(String isolateId, String objectId) =>
      serviceManager.service.getObject(isolateId, objectId);
}
