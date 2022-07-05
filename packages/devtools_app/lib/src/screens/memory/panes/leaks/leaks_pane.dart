import 'package:flutter/material.dart';

import '../../../../primitives/auto_dispose_mixin.dart';
import '../../../../primitives/utils.dart';
import '../../../../shared/globals.dart';
import 'instrumentation/model.dart';

// TODO(polinach): reference this constant in dart SDK, when it gets submitted
// there.
// https://github.com/flutter/devtools/issues/3951
const _extensionKindToRecieveLeaksSummary = 'memory_leaks_summary';

class LeaksPane extends StatefulWidget {
  const LeaksPane({Key? key}) : super(key: key);

  @override
  State<LeaksPane> createState() => _LeaksPaneState();
}

class _LeaksPaneState extends State<LeaksPane> with AutoDisposeMixin {
  LeakSummary? _lastLeakSummary;
  String _leakSummaryHistory = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    cancelStreamSubscriptions();
    _subscribeForMemoryLeaksSummary();
  }

  void _subscribeForMemoryLeaksSummary() {
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEventWithHistory.listen((event) async {
        if (event.extensionKind == _extensionKindToRecieveLeaksSummary) {
          final newSummary =
              LeakSummary.fromJson(event.json!['extensionData']!);
          if (newSummary.matches(_lastLeakSummary)) return;
          _lastLeakSummary = newSummary;
          final time = event.timestamp != null
              ? DateTime.fromMicrosecondsSinceEpoch(event.timestamp!)
              : DateTime.now();
          setState(() {
            _leakSummaryHistory =
                '${formatDateTime(time)}: ${newSummary.toMessage()}\n$_leakSummaryHistory';
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_leakSummaryHistory.isEmpty) const Text('No information yet.'),
        if (_leakSummaryHistory.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(child: Text(_leakSummaryHistory)),
          ),
      ],
    );
  }
}
