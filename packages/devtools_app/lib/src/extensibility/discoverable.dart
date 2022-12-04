import 'dart:async';

import '../primitives/simple_items.dart';
import '../screens/memory/memory_controller_discoverable.dart';
import '../screens/performance/performance_controller_discoverable.dart';
import '../shared/globals.dart';
import 'services_proxy.dart';

export '../screens/memory/memory_controller_discoverable.dart';
export '../screens/performance/performance_controller_discoverable.dart';

class StructuredLogEvent {
  StructuredLogEvent(this.type, {this.data});
  final String type;
  final Object? data;
}

class VMEvent extends StructuredLogEvent {
  VMEvent(type, {data}) : super(type, data: data);
}

class DevToolsUserEvent extends StructuredLogEvent {
  DevToolsUserEvent(type, {data}) : super(type, data: data);
}

/// An event manager class. Clients can listen for classes of events, optionally
/// filtered by a string type. This can be used to decouple events sources and
/// event listeners.
class EventsManager {
  EventsManager() {
    _controller = StreamController.broadcast();
    setGlobal(EventsManager, this);
  }

  late StreamController<StructuredLogEvent> _controller;

  /// Listen for events. Clients can pass in an optional [type]
  /// which filters the events to only those specific ones.
  /// To stop listening to events, keep a reference to the resulting
  /// [StreamSubscription] and cancel it.
  Stream<StructuredLogEvent> onEvent({String? type}) {
    if (type == null) {
      return _controller.stream;
    } else {
      return _controller.stream.where(
        (StructuredLogEvent event) =>
            event.type == type || event.type.startsWith(type),
      );
    }
  }

  /// Add an event to the event bus.
  void addEvent(StructuredLogEvent event) {
    _controller.add(event);
  }

  /// Close (destroy) this [StructuredLogEventsManager]. This is generally not used
  /// outside of a testing context. All stream listeners will be closed and the
  /// bus will not fire any more events.
  void close() {
    unawaited(_controller.close());
  }
}

class DiscoverableDevToolsApp {
  DiscoverableDevToolsApp() {
    vmServicesProxy = VMServicesProxy();
    setGlobal(DiscoverableDevToolsApp, this);
    frameworkController.onPageChange.listen((event) {
      _selectedPageId = event.id;
    });
  }

  late VMServicesProxy vmServicesProxy;

  /// Get the available screen ids from [ScreenIds] class.
  void selectPage(String pageId) {
    frameworkController.notifyShowPageId(pageId);
  }

  String? _selectedPageId;
  String? get selectedPageId => _selectedPageId;

  DiscoverableMemoryPage? memoryPage;
  DiscoverablePerformancePage? performancePage;
  // TODO: add of the other pages here

  static const pageChangedEventKeyPrefix = 'page-changed.';
  static final memoryPageChangedEventKey =
      '$pageChangedEventKeyPrefix${DiscoverableMemoryPage.id}';
  static final performancePageChangedEventKey =
      '$pageChangedEventKeyPrefix${DiscoverablePerformancePage.id}';
}

abstract class DiscoverablePage {}
