import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../primitives/auto_dispose_mixin.dart';

enum AnalysisStatus {
  NotStarted,
  Ongoing,

  /// The process is complete and we want user to see the result.
  ShowingResult,

  /// The process is complete and we want user to acknowledge the error.
  ShowingError,
}

Duration _showingResultDelay = const Duration(seconds: 3);
Duration _delayForUiToHandleState = const Duration(milliseconds: 5);

/// Describes status of the ongoing process.
class AnalysisStatusController {
  ValueNotifier<AnalysisStatus> status =
      ValueNotifier<AnalysisStatus>(AnalysisStatus.NotStarted);

  ValueNotifier<String> message = ValueNotifier('');

  void reset() {
    status.value = AnalysisStatus.NotStarted;
    message.value = '';
  }
}

class AnalysisStatusView extends StatefulWidget {
  const AnalysisStatusView({
    Key? key,
    required this.controller,
    required this.processStarter,
  }) : super(key: key);
  final AnalysisStatusController controller;
  final Widget processStarter;

  @override
  State<AnalysisStatusView> createState() => _AnalysisStatusViewState();
}

class _AnalysisStatusViewState extends State<AnalysisStatusView>
    with AutoDisposeMixin {
  @override
  void initState() {
    super.initState();
    _handleStatusUpdate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    addAutoDisposeListener(widget.controller.status, _handleStatusUpdate);
    addAutoDisposeListener(widget.controller.message, () async {
      setState(() {});
      await Future.delayed(_delayForUiToHandleState);
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _handleStatusUpdate() async {
    setState(() {});

    if (widget.controller.status.value == AnalysisStatus.ShowingResult) {
      await Future.delayed(_showingResultDelay);
      setState(
        () => widget.controller.reset(),
      );
    }
    // We need this delay, because analysis may include heavy computations,
    // and we want to give a space for UI thread to show status.
    await Future.delayed(_delayForUiToHandleState);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    if (c.status.value == AnalysisStatus.NotStarted) {
      return widget.processStarter;
    }

    return Column(
      children: [
        Text(c.message.value),
        if (c.status.value == AnalysisStatus.ShowingError)
          Row(
            children: [
              MaterialButton(
                child: const Icon(Icons.copy),
                onPressed: () async => await Clipboard.setData(
                  ClipboardData(text: c.message.value),
                ),
              ),
              MaterialButton(
                child: const Text('OK'),
                onPressed: () => setState(() => c.reset()),
              ),
            ],
          )
      ],
    );
  }
}
