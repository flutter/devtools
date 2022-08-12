import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../devtools_app.dart';

class RefreshNotifier {
  RefreshNotifier();

  final _controller = StreamController<void>();
  Stream<void> get stream => _controller.stream;

  void refresh() => _controller.add(null);
}

@visibleForTesting
final refreshNotifierProvider = Provider(
  (ref) => RefreshNotifier(),
  name: 'refreshNotifierProvider',
);

final refreshProvider = StreamProvider(
  (ref) => ref.read(refreshNotifierProvider).stream,
  name: 'refreshProvider',
);

class RefreshStateButton extends ConsumerWidget {
  const RefreshStateButton({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Tooltip(
      message: 'Refresh selected provider value',
      child: OutlinedIconButton(
        icon: Icons.refresh,
        onPressed: () {
          ref.read(refreshNotifierProvider).refresh();
        },
      ),
    );
  }
}
