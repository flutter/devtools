// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../notification_provider.dart';

const _notificationWidth = 360.0;
const _notificationHeight = 160.0;

/// Manager for notifications in the app.
class Notifications extends StatefulWidget {
  const Notifications({Key key, this.child}) : super(key: key);

  final Widget child;

  @override
  NotificationsState createState() => NotificationsState();

  static NotificationsState of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_InheritedNotifications>()
        .data;
  }
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

class NotificationsState extends State<Notifications>
    implements NotificationProvider {
  OverlayEntry _overlayEntry;

  final List<_Notification> _notifications = [];

  @override
  void initState() {
    super.initState();
  }

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
  @override
  void push(String message) {
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
  const _Notification(
      {Key key,
      @required this.message,
      this.callback = _noop,
      this.duration = _defaultDuration,
      @required this.remove})
      : assert(message != null),
        assert(callback != null),
        assert(remove != null),
        assert(duration != null),
        super(key: key);

  static const Duration _defaultDuration = Duration(seconds: 7);

  final Duration duration;
  final VoidCallback callback;
  final String message;
  final void Function(_Notification) remove;

  static void _noop() {}

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
        duration: const Duration(milliseconds: 400), vsync: this);
    curve = CurvedAnimation(parent: controller, curve: Curves.easeInOutCirc);
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
          color: Theme.of(context).snackBarTheme.backgroundColor,
          child: DefaultTextStyle(
            style: Theme.of(context).snackBarTheme.contentTextStyle ??
                Theme.of(context).primaryTextTheme.subhead,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Text(
                  widget.message,
                  style: Theme.of(context).textTheme.body1,
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
