// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import '../shared/notifications.dart';
import '../shared/primitives/utils.dart';

double get _notificationHeight => scaleByFontFactor(175.0);
final _notificationWidth = _notificationHeight * goldenRatio;

/// Manager for notifications in the app.
class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => _Notifications(child: child),
          maintainState: true,
          opaque: true,
        ),
      ],
    );
  }
}

/// _Notifications is not combined with NotificationsView.
/// because we are calling Overlay.of(context) from lifecycle methods
/// in _NotificationsState, which would fail if the Overlay widget is defined
/// in _NotificationsState.build because there would be no Overlay in the tree
/// at the time Overlay.of(context) is called.
class _Notifications extends StatefulWidget {
  const _Notifications({required this.child});

  final Widget child;

  @override
  State<_Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<_Notifications> with AutoDisposeMixin {
  OverlayEntry? _overlayEntry;

  final _notifications = <_Notification>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        maintainState: true,
        builder: (_) => _NotificationOverlay(notifications: _notifications),
      );
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        Overlay.of(context).insert(_overlayEntry!);
      });

      addAutoDisposeListener(
        notificationService.newTasks,
        _processQueues,
      );
    }

    _processQueues();
  }

  void _processQueues() {
    while (notificationService.toDismiss.isNotEmpty) {
      _dismiss(notificationService.toDismiss.removeFirst().text);
    }
    while (notificationService.toPush.isNotEmpty) {
      _push(notificationService.toPush.removeFirst());
    }
  }

  @override
  void dispose() {
    _overlayEntry!.remove();
    super.dispose();
  }

  // TODO(peterdjlee): Support clickable links in notification text. See #2268.
  /// Pushes a notification [message], and returns whether the notification was
  /// successfully pushed.
  void _push(NotificationMessage message) {
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

  /// Dismisses all notifications with a matching message.
  void _dismiss(String message) {
    bool didDismiss = false;
    // Make a copy so we do not remove a notification from [_notifications]
    // while iterating over it.
    final notifications = List<_Notification>.of(_notifications);
    for (final notification in notifications) {
      if (notification.message.text == message) {
        _notifications.remove(notification);
        notificationService.markComplete(notification.message);
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
      notificationService.markComplete(notification.message);
      if (didRemove) {
        _overlayEntry?.markNeedsBuild();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _NotificationOverlay extends StatelessWidget {
  const _NotificationOverlay({
    required List<_Notification> notifications,
  }) : _notifications = notifications;

  final List<_Notification> _notifications;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        // Position the notifications in the lower right of the app window, and
        // high enough up that we don't obscure the status line.
        padding: EdgeInsets.only(
          right: defaultSpacing,
          bottom: statusLineHeight + defaultSpacing,
        ),
        child: SizedBox(
          width: _notificationWidth,
          child: SingleChildScrollView(
            reverse: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: _notifications,
            ),
          ),
        ),
      ),
    );
  }
}

class _Notification extends StatefulWidget {
  const _Notification({
    required this.message,
    required this.remove,
  });

  final NotificationMessage message;
  final void Function(_Notification) remove;

  @override
  _NotificationState createState() => _NotificationState();
}

class _NotificationState extends State<_Notification>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late CurvedAnimation curve;
  Timer? _dismissTimer;

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
    if (!widget.message.isDismissible) {
      _dismissTimer = Timer(widget.message.duration, () {
        controller.addStatusListener((status) {
          if (status == AnimationStatus.dismissed) {
            widget.remove(widget);
          }
        });
        controller.reverse();
      });
    }
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    _dismissTimer?.cancel();
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
      child: Card(
        color: theme.snackBarTheme.backgroundColor,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, densePadding),
        child: DefaultTextStyle(
          style: theme.snackBarTheme.contentTextStyle ??
              theme.textTheme.titleMedium!,
          child: Padding(
            padding: const EdgeInsets.all(denseSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                widget.message.isDismissible
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: _NotificationMessage(
                              widget: widget,
                            ),
                          ),
                          _DismissAction(
                            onPressed: () {
                              widget.remove(widget);
                            },
                          ),
                        ],
                      )
                    : _NotificationMessage(
                        widget: widget,
                      ),
                const SizedBox(height: defaultSpacing),
                _NotificationActions(widget: widget),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DismissAction extends StatelessWidget {
  const _DismissAction({
    required this.onPressed,
  });

  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: IconButton(
        icon: const Icon(
          Icons.close,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.widget,
  });

  final _Notification widget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.regularTextStyle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        denseSpacing,
        denseSpacing,
        denseSpacing,
        0,
      ),
      child: Text(
        widget.message.text,
        style: widget.message.isError
            ? textStyle.copyWith(color: theme.colorScheme.error)
            : textStyle,
        overflow: TextOverflow.visible,
        maxLines: 10,
      ),
    );
  }
}

class _NotificationActions extends StatelessWidget {
  const _NotificationActions({
    required this.widget,
  });

  final _Notification widget;

  @override
  Widget build(BuildContext context) {
    final actions = widget.message.actions;
    if (actions.isEmpty) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: actions.joinWith(const SizedBox(width: denseSpacing)),
    );
  }
}
