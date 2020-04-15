// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../globals.dart';
import 'banner_messages.dart';

/// Container for controllers that should outlive individual screens of the app.
///
/// Note that [dispose] should only be called when nothing will be using this
/// particular [ProvidedCommonControllers] instance again.
///
/// To get a [ProvidedCommonControllers] instance, use [CommonControllers.of].
@immutable
class ProvidedCommonControllers {
  const ProvidedCommonControllers({
    @required this.bannerMessages,
  });

  /// Builds the default providers for the app.
  factory ProvidedCommonControllers.defaults() {
    return ProvidedCommonControllers(
      bannerMessages: BannerMessagesController(),
    );
  }

  final BannerMessagesController bannerMessages;
}

/// Provider for controllers that should outlive individual screens of the app.
///
/// [Initializer] builds a [CommonControllers] after it has a connection to the VM
/// service and it has loaded [ensureInspectorDependencies].
///
/// See [CommonControllers.of] for how to retrieve a [ProvidedCommonControllers] instance.
class CommonControllers extends StatefulWidget {
  const CommonControllers({Key key, Widget child})
      : this._(key: key, child: child);

  @visibleForTesting
  const CommonControllers.overridden(
      {Key key, this.child, this.overrideProviders});

  const CommonControllers._({Key key, this.child, this.overrideProviders})
      : super(key: key);

  /// Callback that overrides [ProvidedCommonControllers.defaults].
  final ProvidedCommonControllers Function() overrideProviders;

  final Widget child;

  @override
  _CommonControllersState createState() => _CommonControllersState();

  /// Provides a [ProvidedCommonControllers].
  ///
  /// Note that this method cannot be called during [State.initState] or
  /// [State.dispose]. To retrieve [ProvidedCommonControllers] that you want to use
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
  static ProvidedCommonControllers of(BuildContext context) {
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
class _CommonControllersState extends State<CommonControllers> {
  ProvidedCommonControllers data;

  @override
  void initState() {
    super.initState();
    // Everything depends on the serviceManager being available.
    assert(serviceManager != null);

    _initializeProviderData();
  }

  @override
  void didUpdateWidget(CommonControllers oldWidget) {
    super.didUpdateWidget(oldWidget);
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
      data = ProvidedCommonControllers.defaults();
    }
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

  final ProvidedCommonControllers data;

  @override
  bool updateShouldNotify(_InheritedProvider oldWidget) =>
      oldWidget.data != data;
}

/// Superclass for all DevTools controller providers.
///
/// For an example implementation, see `src/example/provided_controller.dart`.
abstract class ControllerProvider extends StatefulWidget {
  const ControllerProvider({Key key, this.child}) : super(key: key);
  final Widget child;
}
