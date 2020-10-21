// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'common_widgets.dart';
import 'status_line.dart' as status_line;
import 'theme.dart';
import 'utils.dart';

const _notificationHeight = 175.0;
final _notificationWidth = _notificationHeight * goldenRatio;

/// Interface for pushing notifications in the app.
///
/// Use this interface in controllers that need to show notifications.
///
/// Using the interface instead of the [NotificationsState] implementation
/// will allow you to write unit tests for the controller that consumes it
/// instead of widget tests.
abstract class NotificationService {
  /// Pushes a notification [message].
  void push(String message);
}

/// Manager for notifications in the app.
///
/// Must be inside of an [Overlay].
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
    final provider =
        context.dependOnInheritedWidgetOfExactType<_InheritedNotifications>();
    return provider?.data;
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

class NotificationsState extends State<_NotificationsProvider>
    implements NotificationService {
  OverlayEntry _overlayEntry;

  final List<_Notification> _notifications = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        maintainState: true,
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

  // TODO(peterdjlee): Support clickable links in notification text. See #2268.
  /// Pushes a notification [message], and returns whether the notification was
  /// successfully pushed.
  @override
  bool push(
    String message, {
    List<Widget> actions = const [],
    Duration duration = Notifications.defaultDuration,
    bool allowDuplicates = true,
  }) {
    if (!allowDuplicates &&
        _notifications.isNotEmpty &&
        _notifications.where((n) => n.message == message).isNotEmpty) {
      return false;
    }
    setState(() {
      _notifications.add(
        _Notification(
          message: message,
          actions: actions,
          remove: _removeNotification,
          duration: duration,
        ),
      );
      _overlayEntry?.markNeedsBuild();
    });
    return true;
  }

  /// Dismisses all notifications with a matching message.
  void dismiss(String message) {
    bool didDismiss = false;
    // Make a copy so we do not remove a notification from [_notifications]
    // while iterating over it.
    final notifications = List.from(_notifications);
    for (final notification in notifications) {
      if (notification.message == message) {
        _notifications.remove(notification);
        didDismiss = true;
      }
    }
    if (didDismiss) {
      setState(() {
        _overlayEntry?.markNeedsBuild();
      });
    }
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
      child: Padding(
        // Position the notifications in the lower right of the app window, and
        // high enough up that we don't obscure the status line.
        padding: const EdgeInsets.only(
          right: defaultSpacing,
          bottom: status_line.statusLineHeight + defaultSpacing,
        ),
        child: SizedBox(
          width: _notificationWidth,
          child: SingleChildScrollView(
            reverse: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _notifications,
            ),
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
    this.actions = const [],
    this.duration = Notifications.defaultDuration,
    @required this.remove,
  })  : assert(message != null),
        assert(remove != null),
        assert(duration != null),
        super(key: key);

  final Duration duration;
  final String message;
  final List<Widget> actions;
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
        return Opacity(
          opacity: curve.value,
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          color: theme.snackBarTheme.backgroundColor,
          child: DefaultTextStyle(
            style: theme.snackBarTheme.contentTextStyle ??
                theme.primaryTextTheme.subtitle1,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessage(),
                  const SizedBox(height: defaultSpacing),
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessage() {
    return Text(
      widget.message,
      style: Theme.of(context).textTheme.bodyText1,
      overflow: TextOverflow.visible,
      maxLines: 6,
    );
  }

  Widget _buildActions() {
    if (widget.actions.isEmpty) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: widget.actions.joinWith(const SizedBox(width: denseSpacing)),
    );
  }
}

class NotificationAction extends StatelessWidget {
  const NotificationAction(this.label, this.onAction, {this.isPrimary = false});

  final String label;

  final VoidCallback onAction;

  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(label);
    return isPrimary
        ? RaisedButton(
            onPressed: onAction,
            child: labelText,
          )
        : OutlineButton(
            onPressed: onAction,
            child: labelText,
          );
  }
}
