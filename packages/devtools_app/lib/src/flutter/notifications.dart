// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:flutter_test/flutter_test.dart' show fail;

import 'common_widgets.dart';

const _notificationHeight = 160.0;
final _notificationWidth = _notificationHeight * goldenRatio;

/// Manager for notifications in the app.
///
/// Must be inside of an [Overlay].
///
class Notifications extends StatelessWidget {
  const Notifications({Key key, @required this.child}) : super(key: key);

  final Widget child;

  /// The default duration for notifications to show.
  static const Duration defaultDuration = Duration(seconds: 7);

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [
      OverlayEntry(
        builder: (context) => _NotificationsProvider(child: child),
        maintainState: true,
        opaque: true,
      ),
    ]);
  }

  static NotificationsState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedNotifications>()
        .data;
  }
}

class _NotificationsProvider extends StatefulWidget {
  const _NotificationsProvider({Key key, this.child}) : super(key: key);

  final Widget child;

  @override
  NotificationsState createState() => NotificationsState();
}

class _InheritedNotifications extends InheritedWidget {
  const _InheritedNotifications({this.data, Widget child})
      : super(child: child);

  final NotificationsState data;

  @override
  bool updateShouldNotify(_InheritedNotifications oldWidget) {
    return oldWidget.data != data;
  }
}

class NotificationsState extends State<_NotificationsProvider> {
  OverlayEntry _overlayEntry;

  final List<_Notification> _notifications = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        maintainState: true,
        opaque: false,
        builder: _buildOverlay,
      );
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        Overlay.of(context).insert(_overlayEntry);
      });
    }
  }

  @override
  void dispose() {
    _overlayEntry.remove();
    super.dispose();
  }

  /// Pushes a notification [message].
  void push(String message) {
    // fail('Showing message $message');
    setState(() {
      _notifications.add(
        _Notification(
          message: message,
          remove: _removeNotification,
        ),
      );
      _overlayEntry?.markNeedsBuild();
    });
  }

  void _removeNotification(_Notification notification) {
    setState(() {
      final didRemove = _notifications.remove(notification);
      if (didRemove) {
        _overlayEntry?.markNeedsBuild();
      }
    });
  }

  Widget _buildOverlay(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: SizedBox(
        width: _notificationWidth,
        child: SingleChildScrollView(
          reverse: true,
          scrollDirection: Axis.vertical,
          child: Column(
            verticalDirection: VerticalDirection.down,
            mainAxisSize: MainAxisSize.min,
            children: _notifications,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _InheritedNotifications(data: this, child: widget.child);
  }
}

class _Notification extends StatefulWidget {
  const _Notification({
    Key key,
    @required this.message,
    this.duration = Notifications.defaultDuration,
    @required this.remove,
  })  : assert(message != null),
        assert(remove != null),
        assert(duration != null),
        super(key: key);

  final Duration duration;
  final String message;
  final void Function(_Notification) remove;

  @override
  _NotificationState createState() => _NotificationState();
}

class _NotificationState extends State<_Notification>
    with SingleTickerProviderStateMixin {
  AnimationController controller;
  CurvedAnimation curve;
  Timer _dismissTimer;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    curve = CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOutCirc,
    );
    // Set up a timer that reverses the entrance animation, and tells the widget
    // to remove itself when the exit animation is completed.
    // We can do this because the NotificationsState is directly controlling
    // the life cycle of each _Notification widget presented in the overlay.
    _dismissTimer = Timer(widget.duration, () {
      controller.addStatusListener((status) {
        if (status == AnimationStatus.dismissed) {
          widget.remove(widget);
        }
      });
      controller.reverse();
    });
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    _dismissTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return SizedBox(
          height: _notificationHeight * curve.value,
          child: Opacity(
            opacity: curve.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          color: theme.snackBarTheme.backgroundColor,
          child: DefaultTextStyle(
            style: theme.snackBarTheme.contentTextStyle ??
                theme.primaryTextTheme.subhead,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  widget.message,
                  style: theme.textTheme.body1,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 6,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
