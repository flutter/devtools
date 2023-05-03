import 'dart:async';

import 'src/post_message/post_message.dart';

class DartCodeApi {
  final DartCodeDebugApi debug;
  final DartCodeLanguageApi? language;

  StreamSubscription? _postMessageSubscription;
  final Completer<String> _parentOriginCompleter = Completer<String>();
  final _requestCompleters = <int, Completer<Object?>>{};
  final _eventStreamControllers = <String, StreamController>{};
  var _nextId = 1;

  // TODO(dantup): Handle null for language, or another way to check it's
  //  available.
  DartCodeApi()
      : debug = DartCodeDebugApi(),
        language = DartCodeLanguageApi() {
    debug._registerEvents(_registerEvent);
    try {
      _postMessageSubscription = onPostMessage.listen((event) {
        _handleIncomingMessage(event);
      });
    } on UnsupportedError {
      // for non-web testing
    }
  }

  Stream<T> _registerEvent<T>(String event, T Function(Map) converter) {
    final controller = StreamController<Map>.broadcast();
    _eventStreamControllers[event] = controller;
    return controller.stream.map(converter);
  }

  Future<String> get _parentOrigin => _parentOriginCompleter.future;
  void dispose() {
    // TODO(dantup): others?

    unawaited(_postMessageSubscription?.cancel()); // Is this valid?
    _postMessageSubscription = null;
  }

  Future<Object?> executeCommand(String command, [List<Object?>? args]) {
    return _sendRequest(
        'vscode.executeCommand', {'command': command, 'args': args});
  }

  Future<Object?> lspRequest(String method, Map<String, Object?> params) {
    return _sendRequest(
        'language.rawRequest', {'method': method, 'params': params});
  }

  void _handleEvent(String event, Map params) {
    // TODO(dantup): if debug session starts when iframe isn't visible, we
    //  won't get the events here. How should we handle this? Provide APIs to
    //  get the current view of anything that has events?
    _eventStreamControllers[event]?.add(params);
  }

  void _handleIncomingMessage(PostMessageEvent message) {
    // print('_handleIncomingMessage: ${jsonEncode(message.data)}');
    final data = message.data;
    if (data is! Map) return;

    if (!_parentOriginCompleter.isCompleted) {
      _parentOriginCompleter.complete(message.origin);
    }

    final id = data['id'];
    final result = data['result'];
    final error = data['error'];
    final method = data['method'];
    final event = data['event'];
    final params = data['params'];

    if (id != null && result != null) {
      _requestCompleters.remove(id)?.complete(result);
    } else if (id != null && error != null) {
      _requestCompleters.remove(id)?.completeError(error);
    } else if (id != null && method is String) {
      if (params is! Map) return;
      _handleRequest(method, params);
    } else if (event is String) {
      if (params is! Map) return;
      _handleEvent(event, params);
    }
  }

  void _handleRequest(String method, Map params) {}

  Future<void> _sendRaw(Map<String, Object?> payload) async {
    // TODO(dantup): Queue these, because this await probably doesn't guarantee
    //  order? Or change state once we have parent origin so we don't need to
    //  be async.
    postMessage({
      'direction': 'WEBVIEW_TO_EXTENSION',
      'payload': payload,
    }, await _parentOrigin);
  }

  Future<Object?> _sendRequest(String method, Map<String, Object?> params) {
    final id = _nextId++;
    final completer = Completer<Object?>();
    _requestCompleters[id] = completer;

    _sendRaw({
      'id': id,
      'method': method,
      'params': params,
    });

    return completer.future;
  }
}

class DebugSession {
  final String id;
  final Map configuration;

  final _vmServiceCompleter = Completer<String>();
  final _sessionEndCompleter = Completer<void>();

  DebugSession({required this.id, required this.configuration});
  Future<void> get sessionEnd => _sessionEndCompleter.future;

  Future<String> get vmService => _vmServiceCompleter.future;
}

class DebugSessionEvent {
  final DebugSession session;

  DebugSessionEvent(this.session);
}

class DartCodeDebugApi {
  late final Stream<DartDebugSessionStartingEvent> onSessionStarting;
  late final Stream<DartDebugSessionStartedEvent> onSessionStarted;
  late final Stream<DartDebugSessionEndedEvent> onSessionEnded;

  void _registerEvents(
      Stream<T> Function<T>(String event, T Function(Map converter))
          registerEvent) {
    onSessionStarting = registerEvent(
        "debug.onSessionStarting", DartDebugSessionStartingEvent._fromMap);
    onSessionStarted = registerEvent(
        "debug.onSessionStarted", DartDebugSessionStartedEvent._fromMap);
    onSessionEnded = registerEvent(
        "debug.onSessionEnded", DartDebugSessionEndedEvent._fromMap);
  }
}

class DartCodeLanguageApi {
  Future<Object?> rawRequest(String method, Map<String, Object?> params) {
    throw '';
  }
}

class DartDebugSessionStartingEvent {
  final String id;
  final Map configuration;

  DartDebugSessionStartingEvent._({
    required this.id,
    required this.configuration,
  });

  factory DartDebugSessionStartingEvent._fromMap(Map map) =>
      DartDebugSessionStartingEvent._(
        id: map['id'] as String,
        configuration: map['configuration'] as Map,
      );
}

class DartDebugSessionStartedEvent {
  final String id;
  final String? vmService;

  DartDebugSessionStartedEvent._({
    required this.id,
    required this.vmService,
  });

  factory DartDebugSessionStartedEvent._fromMap(Map map) =>
      DartDebugSessionStartedEvent._(
        id: map['id'] as String,
        vmService: map['vmService'] as String?,
      );
}

class DartDebugSessionEndedEvent {
  final String id;

  DartDebugSessionEndedEvent._({
    required this.id,
  });

  factory DartDebugSessionEndedEvent._fromMap(Map map) =>
      DartDebugSessionEndedEvent._(
        id: map['id'] as String,
      );
}

class EventHandler<T> {
  final StreamController<T> controller;
  final T Function(Map) converter;

  EventHandler(this.controller, this.converter);
}
