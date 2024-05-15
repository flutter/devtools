import 'dart:async';

import 'package:async/async.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import 'logging_controller_v2.dart';

class LoggingTableModel extends ChangeNotifier {
  LoggingTableModel();
  final TextStyle _detailsStyle = const TextStyle();
  final TextStyle _metaDataStyle = const TextStyle();
  final double _additionalHeight =
      10.0; // TODO: find out where this extra 10.0 is coming from

  final List<LogDataV2> _logs = [];
  final List<LogDataV2> _filteredLogs = [];
  final Set<int> _selectedLogs = <int>{};

  final Map<int, double> cachedHeights = {};
  final Map<int, double> cachedOffets = {};

  CancelableOperation? _getAllRowHeightsOp;

  set tableWidth(double width) {
    _tableWidth = width;
    cachedHeights.clear();
    cachedOffets.clear();
    unawaited(_preFetchRowHeights());
  }

  double _tableWidth = 0.0;

  int get logCount => _filteredLogs.length;

  void add(LogDataV2 log) {
    _logs.add(log);
    _filteredLogs.add(log);
    notifyListeners();
  }

  Size _textSize(
    TextSpan textSpan, {
    double width = double.infinity,
  }) {
    final TextPainter textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    return textPainter.size;
  }

  double getRowOffset(int index) {
    throw 'Implement this when needed';
  }

  Widget? buildRow(BuildContext context, int index) {
    final row = _filteredLogs.elementAt(index);
    Color? color = alternatingColorForIndex(
      index,
      Theme.of(context).colorScheme,
    );

    if (_selectedLogs.contains(index)) {
      color = Colors.blueGrey;
    }

    return Container(
      decoration: BoxDecoration(color: color),
      child: ValueListenableBuilder(
        valueListenable: row.needsComputing,
        builder: (context, _, __) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(text: _detailsSpan(row.prettyPrinted() ?? '<fetching>')),
              Row(
                children: [
                  RichText(
                    text: _metadataSpan('Some METADATA'),
                  ),
                  const SizedBox(width: 20.0),
                  RichText(
                    text: _metadataSpan('Goes Here'),
                  ),
                ],
              ),
              const Divider(
                height: 10.0,
                color: Colors.black,
              ),
            ],
          );
        },
      ),
    );
  }

  TextSpan _detailsSpan(String text) {
    return TextSpan(
      text: text,
      style: _detailsStyle,
    );
  }

  TextSpan _metadataSpan(String text) {
    return TextSpan(
      text: text,
      style: _metaDataStyle,
    );
  }

  double getRowHeight(int index) {
    // TODO cached height
    final cachedHeight = cachedHeights[index];
    if (cachedHeight != null) return cachedHeight;

    final log = _logs[index];
    final text = log.prettyPrinted() ?? '';

    final row1 = _textSize(_detailsSpan(text), width: _tableWidth);

    // TODO: Improve row2 height by manually flowing metadas into another row
    // if theyoverflow.
    final row2 = _textSize(
      _metadataSpan('always a single line of text'),
      width: _tableWidth,
    );
    final newHeight = row1.height + row2.height + _additionalHeight;
    cachedHeights[index] = newHeight;
    return newHeight;
  }

  Future<void> _preFetchRowHeights() async {
    if (_getAllRowHeightsOp != null) {
      await _getAllRowHeightsOp!.cancel();
    }

    Future<void> fetchAllRows() async {
      for (var i = 0; i < _logs.length; i++) {
        getRowHeight(i);
      }
    }

    _getAllRowHeightsOp = CancelableOperation.fromFuture(fetchAllRows());
  }
}
