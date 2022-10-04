// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import '../../shared/console.dart';
import '../../shared/theme.dart';
import 'logging_controller.dart';

class LogDetails extends StatefulWidget {
  const LogDetails({Key? key, required this.log}) : super(key: key);

  final LogData? log;

  @override
  _LogDetailsState createState() => _LogDetailsState();

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
    _computeLogDetails();
  }

  @override
  void didUpdateWidget(LogDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.log != oldWidget.log) {
      _computeLogDetails();
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
    String? Function()? _dataProvider;
    if (log?.details != null && log!.details!.isNotEmpty) {
      _dataProvider = log.prettyPrinted;
    }

    final details = log?.details;
    if (details != _lastDetails) {
      if (scrollController.hasClients) {
        // Make sure we change the scroll if the log details shown have changed.
        scrollController.jumpTo(0);
      }
      _lastDetails = details;
    }

    return OutlineDecoration(
      child: ConsoleFrame(
        title: AreaPaneHeader(
          title: const Text('Details'),
          needsTopBorder: false,
          actions: [
            CopyToClipboardControl(
              dataProvider: _dataProvider,
              buttonKey: LogDetails.copyToClipboardButtonKey,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(denseSpacing),
          child: SingleChildScrollView(
            controller: scrollController,
            child: SelectableText(
              log?.prettyPrinted() ?? '',
              textAlign: TextAlign.left,
              style: Theme.of(context).fixedFontStyle,
            ),
          ),
        ),
      ),
    );
  }
}
