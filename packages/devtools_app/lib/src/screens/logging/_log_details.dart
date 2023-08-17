// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import '../../shared/console/console.dart';
import 'logging_controller.dart';

class LogDetails extends StatefulWidget {
  const LogDetails({Key? key, required this.log}) : super(key: key);

  final LogData? log;

  @override
  State<LogDetails> createState() => _LogDetailsState();

  static const copyToClipboardButtonKey =
      Key('log_details_copy_to_clipboard_button');
}

class _LogDetailsState extends State<LogDetails>
    with SingleTickerProviderStateMixin {
  String? _lastDetails;
  late final ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    unawaited(_computeLogDetails());
  }

  @override
  void didUpdateWidget(LogDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.log != oldWidget.log) {
      unawaited(_computeLogDetails());
    }
  }

  Future<void> _computeLogDetails() async {
    if (widget.log?.needsComputing ?? false) {
      await widget.log!.compute();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _buildContent(context, widget.log),
    );
  }

  Widget _buildContent(BuildContext context, LogData? log) {
    // TODO(#1370): Handle showing flutter errors in a structured manner.
    return Stack(
      children: [
        _buildSimpleLog(context, log),
        if (log != null && log.needsComputing)
          const CenteredCircularProgressIndicator(),
      ],
    );
  }

  Widget _buildSimpleLog(BuildContext context, LogData? log) {
    final details = log?.details;
    if (details != _lastDetails) {
      if (scrollController.hasClients) {
        // Make sure we change the scroll if the log details shown have changed.
        scrollController.jumpTo(0);
      }
      _lastDetails = details;
    }

    final theme = Theme.of(context);
    return RoundedOutlinedBorder(
      clip: true,
      child: ConsoleFrame(
        title: _LogDetailsHeader(log: log),
        child: Padding(
          padding: const EdgeInsets.all(denseSpacing),
          child: SingleChildScrollView(
            controller: scrollController,
            child: SelectableText(
              log?.prettyPrinted() ?? '',
              textAlign: TextAlign.left,
              style: theme.fixedFontStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _LogDetailsHeader extends StatelessWidget {
  const _LogDetailsHeader({required this.log});

  final LogData? log;

  @override
  Widget build(BuildContext context) {
    String? Function()? dataProvider;
    if (log?.details != null && log!.details!.isNotEmpty) {
      dataProvider = log!.prettyPrinted;
    }
    return AreaPaneHeader(
      title: const Text('Details'),
      includeTopBorder: false,
      roundedTopBorder: false,
      actions: [
        CopyToClipboardControl(
          dataProvider: dataProvider,
          buttonKey: LogDetails.copyToClipboardButtonKey,
        ),
      ],
    );
  }
}
