// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../primitives/auto_dispose_mixin.dart';
import '../primitives/notifications.dart';
import '../primitives/utils.dart';
import '../shared/common_widgets.dart';
import '../shared/globals.dart';
import '../shared/status_line.dart' as status_line;
import '../shared/theme.dart';
import '../shared/utils.dart';

double get _notificationHeight => scaleByFontFactor(175.0);
final _notificationWidth = _notificationHeight * goldenRatio;

/// Manager for notifications in the app.
///
/// Must be inside of an [Overlay].
class NotificationsView extends StatelessWidget {
  const NotificationsView({Key? key, required this.child}) : super(key: key);

  final Widget child;

  /// The default duration for notifications to show.
  static const Duration defaultDuration = Duration(seconds: 7);

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

class NotificationController implements NotificationService {
  final toPush = ValueNotifier<NotificationMessage>(NotificationMessage(''));
  final toDismiss = ValueNotifier<NotificationMessage>(NotificationMessage(''));

  @visibleForTesting
  final inProcess = <NotificationMessage>[];

  /// Pushes a notification [message].
  @override
  bool push(String message) => smartPush(NotificationMessage(message));

  /// Pushes a notification [message].
  @override
  bool smartPush(
    NotificationMessage message, {
    bool allowDuplicates = true,
  }) {
    if (!allowDuplicates &&
        inProcess.containsWhere((m) => m.text == message.text)) {
      return false;
    }
    inProcess.add(message);
    toPush.value = message;
    return true;
  }

  /// Dismisses all notifications with a matching message.
  @override
  void dismiss(String message) =>
      toDismiss.value = NotificationMessage(message);

  /// Marks the message as complete, so that the messages not
  /// allowing duplicates,
  /// with the same text, do not get rejected.
  void markComplete(NotificationMessage message) {
    inProcess.removeWhere((element) => element == message);
  }

  void dispose() {
    toPush.dispose();
    toDismiss.dispose();
  }
}

class _Notifications extends StatefulWidget {
  const _Notifications({Key? key, required this.child}) : super(key: key);

  final Widget child;

  @override
  State<_Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<_Notifications> with AutoDisposeMixin {
  OverlayEntry? _overlayEntry;

  final List<_Notification> _notifications = [];
  late NotificationController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    controller = notificationService as NotificationController;

    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        maintainState: true,
        builder: _buildOverlay,
      );
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        Overlay.of(context)!.insert(_overlayEntry!);
      });
    }

    addAutoDisposeListener(
      controller.toPush,
      () => _push(controller.toPush.value),
    );

    addAutoDisposeListener(
      controller.toDismiss,
      () => _dismiss(controller.toDismiss.value.text),
    );
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
    print('dismiss invoked');
    bool didDismiss = false;
    // Make a copy so we do not remove a notification from [_notifications]
    // while iterating over it.
    final notifications = List.from(_notifications).cast<_Notification>();
    for (final notification in notifications) {
      if (notification.message.text == message) {
        print('dismiss invoked - notification found');
        _notifications.remove(notification);
        controller.markComplete(notification.message);
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
      controller.markComplete(notification.message);
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
        padding: EdgeInsets.only(
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
    return widget.child;
  }
}

class _Notification extends StatefulWidget {
  const _Notification({
    Key? key,
    required this.message,
    required this.remove,
  }) : super(key: key);

  final NotificationMessage message;
  final void Function(_Notification) remove;

  @override
  _NotificationState createState() => _NotificationState();
}

class _NotificationState extends State<_Notification>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late CurvedAnimation curve;
  late Timer _dismissTimer;

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
    _dismissTimer = Timer(widget.message.duration, () {
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
        padding: const EdgeInsets.all(denseSpacing),
        child: Card(
          color: theme.snackBarTheme.backgroundColor,
          child: DefaultTextStyle(
            style: theme.snackBarTheme.contentTextStyle ??
                theme.primaryTextTheme.subtitle1!,
            child: Padding(
              padding: const EdgeInsets.all(denseSpacing),
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
      widget.message.text,
      style: Theme.of(context).textTheme.bodyText1,
      overflow: TextOverflow.visible,
      maxLines: 6,
    );
  }

  Widget _buildActions() {
    if (widget.message.actions.isEmpty) return const SizedBox();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children:
          widget.message.actions.joinWith(const SizedBox(width: denseSpacing)),
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
        ? ElevatedButton(
            onPressed: onAction,
            child: labelText,
          )
        : OutlinedButton(
            onPressed: onAction,
            child: labelText,
          );
  }
}
