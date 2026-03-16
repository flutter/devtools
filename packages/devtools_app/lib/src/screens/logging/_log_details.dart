// Copyright 2019 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/globals.dart';
import '../../shared/preferences/preferences.dart';
import '../../shared/ui/common_widgets.dart';
import '../../shared/ui/search.dart';
import '../../shared/ui/search_highlighter.dart';
import 'log_details_controller.dart';
import 'logging_controller.dart';

class LogDetails extends StatefulWidget {
  const LogDetails({super.key, required this.log, required this.controller});

  final LogData? log;
  final LogDetailsController controller;

  @override
  State<LogDetails> createState() => _LogDetailsState();

  static const copyToClipboardButtonKey = Key(
    'log_details_copy_to_clipboard_button',
  );
}

class _LogDetailsState extends State<LogDetails>
    with AutoDisposeMixin<LogDetails>, SingleTickerProviderStateMixin {
  String? _lastDetails;
  late final ScrollController scrollController;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    addAutoDisposeListener(preferences.logging.detailsFormat);
    unawaited(_computeLogDetails());
  }

  @override
  void didUpdateWidget(LogDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.log != oldWidget.log) {
      unawaited(_computeLogDetails());
    }
    if (widget.controller != oldWidget.controller) {
      cancelListeners();
      addAutoDisposeListener(preferences.logging.detailsFormat);
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
        format: preferences.logging.detailsFormat.value,
        controller: widget.controller,
      ),
      child: Scrollbar(
        controller: scrollController,
        child: SingleChildScrollView(
          controller: scrollController,
          child:
              preferences.logging.detailsFormat.value ==
                      LoggingDetailsFormat.text ||
                  (log?.encodedDetails ?? '').isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(denseSpacing),
                  child: SelectionArea(
                    child: _SearchableLogDetailsText(
                      text: log?.prettyPrinted() ?? '',
                      controller: widget.controller,
                    ),
                  ),
                )
              : JsonViewer(encodedJson: log!.encodedDetails),
        ),
      ),
    );
  }
}

class _LogDetailsHeader extends StatelessWidget {
  const _LogDetailsHeader({
    required this.log,
    required this.format,
    required this.controller,
  });

  final LogData? log;
  final LoggingDetailsFormat format;
  final LogDetailsController controller;

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
      tall: true,
      actions: [
        // Only supporting search for the text format now since supporting this
        // for the expandable JSON viewer would require a more complicated
        // refactor of that shared component.
        if (format == LoggingDetailsFormat.text)
          _LogDetailsSearchField(controller: controller, log: log),
        LogDetailsFormatButton(format: format),
        const SizedBox(width: densePadding),
        CopyToClipboardControl(
          dataProvider: dataProvider,
          buttonKey: LogDetails.copyToClipboardButtonKey,
        ),
      ],
    );
  }
}

/// An animated search field for the log details view that toggles between an icon
/// and a full [SearchField].
class _LogDetailsSearchField extends StatefulWidget {
  const _LogDetailsSearchField({required this.controller, required this.log});

  final LogDetailsController controller;
  final LogData? log;

  @override
  State<_LogDetailsSearchField> createState() => _LogDetailsSearchFieldState();
}

class _LogDetailsSearchFieldState extends State<_LogDetailsSearchField>
    with AutoDisposeMixin {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.controller.search.isNotEmpty;
    addAutoDisposeListener(widget.controller.searchFieldFocusNode, () {
      final hasFocus =
          widget.controller.searchFieldFocusNode?.hasFocus ?? false;
      if (hasFocus != _isExpanded) {
        setState(() {
          _isExpanded = hasFocus;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: defaultDuration,
      curve: defaultCurve,
      width: _isExpanded ? mediumSearchFieldWidth : defaultButtonHeight,
      child: OverflowBox(
        minWidth: 0.0,
        maxWidth: mediumSearchFieldWidth,
        child: _isExpanded
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: densePadding),
                child: SearchField<LogDetailsController>(
                  searchController: widget.controller,
                  searchFieldEnabled:
                      widget.log != null && widget.log!.details != null,
                  shouldRequestFocus: true,
                  searchFieldWidth: mediumSearchFieldWidth,
                ),
              )
            : ToolbarAction(
                icon: Icons.search,
                tooltip: 'Search details',
                size: defaultIconSize,
                onPressed: () {
                  setState(() {
                    _isExpanded = true;
                  });
                  widget.controller.searchFieldFocusNode?.requestFocus();
                },
              ),
      ),
    );
  }
}

/// A text widget for the log details view that highlights search matches.
class _SearchableLogDetailsText extends StatelessWidget {
  const _SearchableLogDetailsText({
    required this.text,
    required this.controller,
  });

  final String text;
  final LogDetailsController controller;

  @override
  Widget build(BuildContext context) {
    return MultiValueListenableBuilder(
      listenables: [controller.searchMatches, controller.activeSearchMatch],
      builder: (context, values, _) {
        final theme = Theme.of(context);

        final matches = (values[0] as List<LogDetailsMatch>)
            .map((m) => m.range)
            .toList();
        final activeMatch = (values[1] as LogDetailsMatch?)?.range;

        return Text.rich(
          SearchHighlighter.highlight(
            text,
            matches,
            activeMatch: activeMatch,
            colorScheme: theme.colorScheme,
            style: theme.regularTextStyle,
          ),
        );
      },
    );
  }
}

@visibleForTesting
class LogDetailsFormatButton extends StatelessWidget {
  const LogDetailsFormatButton({super.key, required this.format});

  final LoggingDetailsFormat format;

  static const viewAsJsonTooltip = 'View as JSON';
  static const viewAsRawTextTooltip = 'View as raw text';

  @override
  Widget build(BuildContext context) {
    final currentlyUsingTextFormat = format == LoggingDetailsFormat.text;
    final tooltip = currentlyUsingTextFormat
        ? viewAsJsonTooltip
        : viewAsRawTextTooltip;
    void togglePreference() =>
        preferences.logging.detailsFormat.value = format.opposite();

    return currentlyUsingTextFormat
        ? Padding(
            // This padding aligns this button with the copy button.
            padding: const EdgeInsets.only(bottom: borderPadding),
            child: SmallAction(
              tooltip: tooltip,
              onPressed: togglePreference,
              child: Text(' { } ', style: Theme.of(context).regularTextStyle),
            ),
          )
        : ToolbarAction(
            icon: Icons.text_fields,
            tooltip: tooltip,
            onPressed: togglePreference,
            size: defaultIconSize,
          );
  }
}
