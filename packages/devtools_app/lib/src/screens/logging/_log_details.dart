// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/common_widgets.dart';
import 'logging_controller.dart';

class LogDetails extends StatefulWidget {
  const LogDetails({super.key, required this.log});

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

  // TODO(kenz): store this as a setting in logging preferences instead of in
  // this state class.
  bool showDetailsAsText = true;

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
    final log = widget.log;
    // TODO(#1370): Handle showing flutter errors in a structured manner.
    return Stack(
      children: [
        _buildSimpleLog(log),
        if (log != null && log.needsComputing)
          const CenteredCircularProgressIndicator(),
      ],
    );
  }

  Widget _buildSimpleLog(LogData? log) {
    final details = log?.details;
    if (details != _lastDetails) {
      if (scrollController.hasClients) {
        // Make sure we change the scroll if the log details shown have changed.
        scrollController.jumpTo(0);
      }
      _lastDetails = details;
    }

    return DevToolsAreaPane(
      header: _LogDetailsHeader(
        log: log,
        showDetailsAsText: showDetailsAsText,
        onDetailsFormatPressed: (value) {
          setState(() {
            showDetailsAsText = value;
          });
        },
      ),
      child: Scrollbar(
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          child: showDetailsAsText
              ? Padding(
                  padding: const EdgeInsets.all(denseSpacing),
                  child: SelectableText(
                    log?.prettyPrinted() ?? '',
                    textAlign: TextAlign.left,
                  ),
                )
              : JsonViewer(encodedJson: log?.encodedDetails ?? ''),
        ),
      ),
    );
  }
}

class _LogDetailsHeader extends StatelessWidget {
  const _LogDetailsHeader({
    required this.log,
    required this.showDetailsAsText,
    required this.onDetailsFormatPressed,
  });

  final LogData? log;
  final bool showDetailsAsText;
  final void Function(bool) onDetailsFormatPressed;

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
        LogDetailsFormatButton(
          showDetailsAsText: showDetailsAsText,
          onPressed: onDetailsFormatPressed,
        ),
        const SizedBox(width: densePadding),
        CopyToClipboardControl(
          dataProvider: dataProvider,
          buttonKey: LogDetails.copyToClipboardButtonKey,
        ),
      ],
    );
  }
}

@visibleForTesting
class LogDetailsFormatButton extends StatelessWidget {
  const LogDetailsFormatButton({
    super.key,
    required this.showDetailsAsText,
    required this.onPressed,
  });

  final bool showDetailsAsText;
  final void Function(bool) onPressed;

  static const viewAsJsonTooltip = 'View as JSON';
  static const viewAsRawTextTooltip = 'View as raw text';

  @override
  Widget build(BuildContext context) {
    final tooltip =
        showDetailsAsText ? viewAsJsonTooltip : viewAsRawTextTooltip;
    return showDetailsAsText
        ? Padding(
            // This padding aligns this button with the copy button.
            padding: const EdgeInsets.only(bottom: borderPadding),
            child: SmallAction(
              tooltip: tooltip,
              onPressed: () => onPressed(!showDetailsAsText),
              child: Text(
                ' { } ',
                style: Theme.of(context).regularTextStyle,
              ),
            ),
          )
        : ToolbarAction(
            icon: Icons.text_fields,
            tooltip: tooltip,
            onPressed: () => onPressed(!showDetailsAsText),
            size: defaultIconSize,
          );
  }
}
