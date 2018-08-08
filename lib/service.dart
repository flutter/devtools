// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Event;
import 'dart:typed_data';

import 'package:vm_service_lib/vm_service_lib.dart';

Future<VmService> connect(String host, int port, Completer finishedCompleter) {
  WebSocket ws = new WebSocket('ws://${host}:${port}/ws');

  Completer<VmService> connectedCompleter = new Completer();

  ws.onOpen.listen((_) {
    VmService service = new VmService(
      ws.onMessage.asyncMap((MessageEvent e) {
        if (e.data is String) return e.data as String;

        final FileReader fileReader = new FileReader();
        fileReader.readAsArrayBuffer(e.data as Blob);
        return fileReader.onLoadEnd.first.then((_) {
          return new ByteData.view((fileReader.result as Uint8List).buffer);
        });
      }),
      (String message) => ws.send(message),
    );

    ws.onClose.listen((_) {
      finishedCompleter.complete();
      service.dispose();
    });

    connectedCompleter.complete(service);
  });

  ws.onError.listen((e) {
    //_logger.fine('Unable to connect to observatory, port ${port}', e);
    if (!connectedCompleter.isCompleted) connectedCompleter.completeError(e);
  });

  return connectedCompleter.future;
}

class ServiceConnectionManager {
  final StreamController _stateController = new StreamController.broadcast();
  final StreamController<VmService> _connectionAvailableController =
      new StreamController.broadcast();
  final StreamController _connectionClosedController =
      new StreamController.broadcast();
  final IsolateManager isolateManager = new IsolateManager();

  VmService service;
  VM vm;
  String sdkVersion;

  bool get hasConnection => service != null;

  Stream get onStateChange => _stateController.stream;

  Stream<VmService> get onConnectionAvailable =>
      _connectionAvailableController.stream;

  Stream get onConnectionClosed => _connectionClosedController.stream;

  void vmServiceOpened(VmService _service, Future onClosed) {
    //_service.onSend.listen((s) => print('==> $s'));
    //_service.onReceive.listen((s) => print('<== $s'));

    _service.getVM().then((VM vm) {
      this.vm = vm;
      sdkVersion = vm.version;
      if (sdkVersion.contains(' ')) {
        sdkVersion = sdkVersion.substring(0, sdkVersion.indexOf(' '));
      }

      this.service = _service;

      _stateController.add(null);
      _connectionAvailableController.add(service);

      isolateManager._initIsolates(vm.isolates);
      service.onIsolateEvent.listen(isolateManager._handleIsolateEvent);

      onClosed.then((_) => vmServiceClosed());

      service.streamListen('Stdout');
      service.streamListen('Stderr');
      service.streamListen('VM');
      service.streamListen('Isolate');
      service.streamListen('Debug');
      service.streamListen('GC');
      service.streamListen('Timeline');
      service.streamListen('Extension');
      service.streamListen('_Graph');
      service.streamListen('_Logging');

      isolateManager.onIsolateCreated.listen(print);
      isolateManager.onSelectedIsolateChanged.listen(print);
      isolateManager.onIsolateExited.listen(print);
    }).catchError((e) {
      // TODO:
      print(e);
    });
  }

  void vmServiceClosed() {
    service = null;
    vm = null;
    sdkVersion = null;

    _stateController.add(null);
    _connectionClosedController.add(null);
  }
}

class IsolateManager {
  List<IsolateRef> _isolates = [];
  IsolateRef _selectedIsolate;

  final StreamController<IsolateRef> _isolateCreatedController =
      new StreamController.broadcast();
  final StreamController<IsolateRef> _isolateExitedController =
      new StreamController.broadcast();

  final StreamController<IsolateRef> _selectedIsolateController =
      new StreamController.broadcast();

  List<IsolateRef> get isolates => new List.unmodifiable(_isolates);

  IsolateRef get selectedIsolate => _selectedIsolate;

  void selectIsolate(String isolateRefId) {
    IsolateRef ref =
        _isolates.firstWhere((r) => r.id == isolateRefId, orElse: () => null);
    if (ref != _selectedIsolate) {
      _selectedIsolate = ref;
      _selectedIsolateController.add(_selectedIsolate);
    }
  }

  Stream<IsolateRef> get onIsolateCreated => _isolateCreatedController.stream;

  Stream<IsolateRef> get onSelectedIsolateChanged =>
      _selectedIsolateController.stream;

  Stream<IsolateRef> get onIsolateExited => _isolateExitedController.stream;

  void _initIsolates(List<IsolateRef> isolates) {
    _isolates = isolates;
    _selectedIsolate = isolates.isNotEmpty ? isolates.first : null;

    if (_selectedIsolate != null) {
      _isolateCreatedController.add(_selectedIsolate);
      _selectedIsolateController.add(_selectedIsolate);
    }
  }

  void _handleIsolateEvent(Event event) {
    if (event.kind == 'IsolateStart') {
      _isolates.add(event.isolate);
      _isolateCreatedController.add(event.isolate);
      if (_selectedIsolate == null) {
        _selectedIsolate = event.isolate;
        _selectedIsolateController.add(event.isolate);
      }
    } else if (event.kind == 'IsolateExit') {
      _isolates.remove(event.isolate);
      _isolateExitedController.add(event.isolate);
      if (_selectedIsolate == event.isolate) {
        _selectedIsolate = _isolates.isEmpty ? null : _isolates.first;
        _selectedIsolateController.add(_selectedIsolate);
      }
    }
  }
}
