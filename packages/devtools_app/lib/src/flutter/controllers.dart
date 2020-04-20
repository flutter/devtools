// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../auto_dispose.dart';
import '../debugger/flutter/debugger_controller.dart';
import '../globals.dart';
import '../logging/logging_controller.dart';
import '../memory/flutter/memory_controller.dart';
import '../performance/performance_controller.dart';
import '../timeline/flutter/timeline_controller.dart';
import 'banner_messages.dart';

/// Container for controllers that should outlive individual screens of the app.
///
/// Note that [dispose] should only be called when nothing will be using this
/// particular [ProvidedControllers] instance again.
///
/// To get a [ProvidedControllers] instance, use [Controllers.of].
@immutable
class ProvidedControllers implements DisposableController {
  const ProvidedControllers({
    @required this.logging,
    @required this.timeline,
    @required this.memory,
    @required this.performance,
    @required this.debugger,
    @required this.bannerMessages,
  })  : assert(logging != null),
        assert(timeline != null),
        assert(memory != null),
        assert(performance != null),
        assert(debugger != null),
        assert(bannerMessages != null);

  /// Builds the default providers for the app.
  factory ProvidedControllers.defaults() {
    return ProvidedControllers(
      logging: LoggingController(
        onLogCountStatusChanged: (_) {
          // TODO(devoncarew): This callback is not used.
        },
        // TODO(djshuckerow): Use a notifier pattern for the logging controller.
        // That way, it is visible if it has listeners and invisible otherwise.
        isVisible: () => true,
      ),
      timeline: TimelineController(),
      memory: MemoryController(),
      performance: PerformanceController(),
      debugger: DebuggerController(),
      bannerMessages: BannerMessagesController(),
    );
  }

  final LoggingController logging;
  final TimelineController timeline;
  final MemoryController memory;
  final PerformanceController performance;
  final DebuggerController debugger;
  final BannerMessagesController bannerMessages;

  @override
  void dispose() {
    logging.dispose();
    timeline.dispose();
    memory.dispose();
    performance.dispose();
    debugger.dispose();
  }
}

/// Provider for controllers that should outlive individual screens of the app.
///
/// [Initializer] builds a [Controllers] after it has a connection to the VM
/// service and it has loaded [ensureInspectorDependencies].
///
/// See [Controllers.of] for how to retrieve a [ProvidedControllers] instance.
class Controllers extends StatefulWidget {
  const Controllers({Key key, Widget child}) : this._(key: key, child: child);

  @visibleForTesting
  const Controllers.overridden({Key key, this.child, this.overrideProviders});

  const Controllers._({Key key, this.child, this.overrideProviders})
      : super(key: key);

  /// Callback that overrides [ProvidedControllers.defaults].
  @visibleForTesting
  final ProvidedControllers Function() overrideProviders;

  final Widget child;

  @override
  _ControllersState createState() => _ControllersState();

  /// Provides a [ProvidedControllers].
  ///
  /// Note that this method cannot be called during [State.initState] or
  /// [State.dispose]. To retrieve [ProvidedControllers] that you want to use
  /// during a state's entire lifetime, call this method during [State.didChangeDependencies].
  ///
  /// A pattern like the following is appropriate:
  ///
  /// ```dart
  /// class _DependentState extends State<DependentWidget> with AutoDisposeStateMixin {
  ///   @override
  ///   void didChangeDependencies() {
  ///     super.didChangeDependencies();
  ///     cancel();
  ///     addAutoDisposeListener(Controllers.of(context).logging.onLogsUpdated, () {
  ///       setState(() {
  ///         // callback logic here.
  ///       });
  ///     });
  ///   }
  /// }
  /// ```
  static ProvidedControllers of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<_InheritedProvider>();
    return provider?.data;
  }
}

/// Manager for the creation of new providers.
///
/// This state will use [widget.overrideProviders] to update [data]
/// when its widget is updated.
///
/// It is not responsible for passing notifications down
class _ControllersState extends State<Controllers> {
  ProvidedControllers data;

  @override
  void initState() {
    super.initState();
    // Everything depends on the serviceManager being available.
    assert(serviceManager != null);

    _initializeProviderData();
  }

  @override
  void didUpdateWidget(Controllers oldWidget) {
    super.didUpdateWidget(oldWidget);

    // TODO(#1732): We create controllers twice - here, and in initState().
    // Additionally, when creating new controllers in didUpdateWidget, we never
    // dispose of the old controllers. For places like the debugger page, this
    // means that we send many more requests to the VM for the same data than we
    // need to.

    _initializeProviderData();
  }

  void _initializeProviderData() {
    if (widget.overrideProviders != null) {
      data = widget.overrideProviders();
      assert(
        data != null,
        'Attempted to build overridden providers, but got a null value.',
      );
    } else {
      // TODO(#1732): Don't re-create controllers on each hot reload, or,
      // dispose of the old controllers here.
      data = ProvidedControllers.defaults();
    }
  }

  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedProvider(data: data, child: widget.child);
  }
}

/// A container for the [ProvidedControllers] [data].
///
/// It creates a custom [InheritedElement] that is able to dispose of old [data]
/// only after notifying clients of the updated [data].
///
/// This is necessary to avoid situations where a [Listenable] from one of
/// the controllers has been disposed, but one of the clients still attempts to
/// remove its registered listener.
class _InheritedProvider extends InheritedWidget {
  const _InheritedProvider({@required this.data, @required Widget child})
      : super(child: child);

  final ProvidedControllers data;

  @override
  bool updateShouldNotify(_InheritedProvider oldWidget) =>
      oldWidget.data != data;

  @override
  InheritedElement createElement() => _DisposeAfterNotifyElement(this);
}

/// An [Element] that disposes its [_oldData] on the frame after after
/// Notifying clients of a data change.
///
/// This allows clients to unregister listeners from the old data before it is
/// disposed, and avoid exceptions caused by unregistering from disposed
/// listeners.
class _DisposeAfterNotifyElement extends InheritedElement {
  _DisposeAfterNotifyElement(_InheritedProvider widget) : super(widget);

  @override
  _InheritedProvider get widget => super.widget;

  ProvidedControllers _oldData;

  @override
  void updated(_InheritedProvider oldWidget) {
    if (oldWidget.data != widget.data) {
      _oldData = oldWidget.data;
      super.updated(oldWidget);
    }
  }

  @override
  void notifyClients(_InheritedProvider oldWidget) {
    super.notifyClients(oldWidget);
    // For stateful widgets that depend on Controllers.of(context) to subscribe
    // directly, we don't need a postframe callback and we can just  dispose the
    // old data.
    // For ValueListenableBuilder widgets, we need the postframe callback to
    // wait until the builders have a chance to build and update their
    // listeners.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _oldData?.dispose();
    });
  }
}
