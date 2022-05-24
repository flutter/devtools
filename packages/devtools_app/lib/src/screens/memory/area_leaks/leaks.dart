import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../primitives/auto_dispose_mixin.dart';
import '../../../shared/eval_on_dart_library.dart';
import '../../../shared/globals.dart';

class LeaksArea extends StatefulWidget {
  const LeaksArea({Key? key}) : super(key: key);

  @override
  State<LeaksArea> createState() => _LeaksAreaState();
}

class _LeaksAreaState extends State<LeaksArea> with AutoDisposeMixin {
  var _leaksSummary = 'Not received.';
  var _leaksDetails = 'Not received.';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeForMemoryLeaks();
  }

  void _subscribeForMemoryLeaks() {
    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEventWithHistory.listen((event) {
        if (event.extensionKind == 'MemoryLeaks') {
          setState(() {
            final json = event.json!['extensionData']!;
            _leaksDetails = json['details'].toString();
            _leaksSummary = json['summary'].toString();
          });
        }
      }),
    );

    autoDisposeStreamSubscription(
      serviceManager.service!.onExtensionEventWithHistory.listen((event) {
        if (event.extensionKind == 'TrackedObject') {
          // final json = event.json!['extensionData']!;
          // final hash = json['hash'] as int;
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_leaksSummary),
        MaterialButton(
          child: const Text('Copy Details to Clipboard'),
          onPressed: () =>
              Clipboard.setData(ClipboardData(text: _leaksDetails)),
        ),
        MaterialButton(
          child: const Text('Evaluate'),
          onPressed: () async {
            final eval = EvalOnDartLibrary(
              'package:flutter_leaks/test_lib.dart',
              serviceManager.service!,
            );
            final result =
                await eval.safeEval('getObject(27182)', isAlive: null);
            print('evaluated: ${result.id!}, ${result.valueAsString}');

            final path = await serviceManager.service!.getRetainingPath(
              eval.isolate!.id!,
              result.id!,
              100,
            );

            print('path: $path');
          },
        ),
      ],
    );
  }
}
