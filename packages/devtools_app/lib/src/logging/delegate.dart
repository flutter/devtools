import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:table/raw.dart';

import '../common_widgets.dart';
import '../theme.dart';
import '../ui/colors.dart';
import '../utils.dart';
import 'logging_controller.dart';

class LoggingTableDelegate extends RawTableDelegate {
  LoggingTableDelegate({this.controller, this.onRowSelected});

  static const double _defaultPadding = 8.0;

  static const List<EdgeInsets> _columnPadding = [
    EdgeInsets.only(left: 2 * _defaultPadding, right: _defaultPadding),
    EdgeInsets.only(left: _defaultPadding, right: _defaultPadding),
    EdgeInsets.only(left: _defaultPadding, right: 2 * _defaultPadding),
  ];

  static const List<String> _columnTitles = [
    'When',
    'Kind',
    'Message',
  ];

  @override
  Widget buildCell(BuildContext context, int column, int row) {
    Widget child;
    if (row == 0) {
      child =  Text(_columnTitles[column]);
    } else {
      final LogData item = logs[row - 1];
      switch (column) {
        case 0:
          child = _WhenCell(item: item);
          break;
        case 1:
          child = _KindCell(item: item);
          break;
        case 2:
          child = _MessageCell(item: item);
          break;
      }
    }
    assert(child != null);

    child = Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: _columnPadding[column],
        child: child,
      ),
    );

    if (row == 0) {
      child = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            // TODO: implement sorting here; does that even make sense for this table?
          },
          child: child,
        ),
      );
    }

    return child;
  }

  @override
  RawTableBand buildColumnSpec(int column) {
    switch (column) {
      case 0:
        return const RawTableBand(
          extent: FixedRawTableBandExtent(120.0 + 3 * _defaultPadding),
        );
      case 1:
        return const RawTableBand(
          extent: FixedRawTableBandExtent(155.0 + 2 * _defaultPadding),
        );
      case 2:
        return const RawTableBand(
          extent: MaxRawTableBandExtent(
            FixedRawTableBandExtent(300.0 + 3 * _defaultPadding),
            RemainingRawTableBandExtent(),
          ),
        );
    }
    assert(false);
    return null;
  }

  static const double defaultRowHeight = 32.0;
  static const double headerRowHeight = 36.0;

  @override
  RawTableBand buildRowSpec(int row) {
    if (row == 0) {
      return RawTableBand(
        backgroundDecoration: RawTableBandDecoration(
          color: themeData.titleSolidBackgroundColor,
        ),
        extent: const FixedRawTableBandExtent(headerRowHeight),
      );
    }

    // TODO(goderbauer): How to do the ink splash?
    // TODO(goderbauer): Animate the transition to hover color?
    return RawTableBand(
      backgroundDecoration: RawTableBandDecoration(
        color: _rowColor(row),
      ),
      extent: const FixedRawTableBandExtent(defaultRowHeight),
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        _hovered = row;
        notifyListeners();
      },
      onExit: (_) {
        _hovered = null;
        notifyListeners();
      },
      recognizerFactories: {
        TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (TapGestureRecognizer instance) => instance.onTap = () {
            if (onRowSelected != null) {
              onRowSelected(row - 1);
            }
          },
        ),
      },
    );
  }

  Color _rowColor(int row) {
    final LogData rowData = logs[row -1];
    final bool isSelected = selected == rowData;
    Color color = isSelected ? _themeData.selectedRowColor : alternatingColorForIndex(row - 1, themeData.colorScheme);
    if (_hovered == row) {
      color = color.brighten(0.2);
    }
    if (searchMatches?.contains(rowData) ?? false) {
      color = Color.alphaBlend(
        activeSearchMatch == rowData
          ? activeSearchMatchColorOpaque
          : searchMatchColorOpaque,
        color,
      );
    }
    return color;
  }

  int _hovered;

  @override
  int get numberOfColumns => 3;

  @override
  int get numberOfRows => logs.length + 1;

  @override
  int get numberOfStickyRows => 1;

  final ScrollController controller;
  final ValueChanged<int> onRowSelected;

  List<LogData> get logs => _logs;
  List<LogData> _logs;
  set logs(List<LogData> value) {
    if (value == _logs) {
      return;
    }

    // Schedule autoscroll to bottom if we have more logs
    if (logs != null && controller != null
        && value.length > _logs.length
        && controller.hasClients && controller.position.hasContentDimensions
        && controller.position.pixels == controller.position.maxScrollExtent
    ) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        controller.jumpTo(controller.position.maxScrollExtent);
      });
    }

    _logs = value;
    notifyListeners();
  }

  ThemeData get themeData => _themeData;
  ThemeData _themeData;
  set themeData(ThemeData value) {
    if (value == _themeData) {
      return;
    }
    _themeData = value;
    notifyListeners();
  }

  LogData get selected => _selected;
  LogData _selected;
  set selected(LogData value) {
    if (value == _selected) {
      return;
    }
    _selected = value;
    notifyListeners();
  }

  LogData get activeSearchMatch => _activeSearchMatch;
  LogData _activeSearchMatch;
  set activeSearchMatch(LogData value) {
    if (_activeSearchMatch == value) {
      return;
    }
    _activeSearchMatch = value;
    notifyListeners();
    // scroll it into view, if necessary.
    // TODO(goderbauer): There should be an easier API to just scroll a row into view.
    final int index = logs.indexOf(value);
    if (index != -1) {
      final double expectedScrollOffset = index * defaultRowHeight;
      final bool isInView = expectedScrollOffset > controller.offset && expectedScrollOffset + defaultRowHeight < controller.offset + controller.position.extentInside - headerRowHeight;
      if (!isInView) {
        controller.animateTo(
          expectedScrollOffset,
          duration: defaultDuration,
          curve: defaultCurve,
        );
      }
    }
  }

  List<LogData> get searchMatches => _searchMatches;
  List<LogData> _searchMatches;
  set searchMatches(List<LogData> value) {
    if (_searchMatches == value) {
      return;
    }
    _searchMatches = value;
    notifyListeners();
  }

  @override
  bool shouldRebuild(RawTableDelegate oldDelegate) => true;
}

class _WhenCell extends StatelessWidget {
  const _WhenCell({Key key, @required this.item}) : super(key: key);

  final LogData item;

  @override
  Widget build(BuildContext context) {
    final value = item.timestamp == null
        ? ''
        : timeFormat.format(DateTime.fromMillisecondsSinceEpoch(item.timestamp));
    return Text(
      value,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).fixedFontStyle,
      maxLines: 1,
    );
  }
}


class _KindCell extends StatelessWidget {
  const _KindCell({Key key, @required this.item}) : super(key: key);

  final LogData item;

  @override
  Widget build(BuildContext context) {
    final String kind = item.kind;

    Color color = const Color.fromARGB(0xff, 0x61, 0x61, 0x61);

    if (kind == 'stderr' || item.isError || kind == 'flutter.error') {
      color = const Color.fromARGB(0xff, 0xF4, 0x43, 0x36);
    } else if (kind == 'stdout') {
      color = const Color.fromARGB(0xff, 0x78, 0x90, 0x9C);
    } else if (kind.startsWith('flutter')) {
      color = const Color.fromARGB(0xff, 0x00, 0x91, 0xea);
    } else if (kind == 'gc') {
      color = const Color.fromARGB(0xff, 0x42, 0x42, 0x42);
    }

    // Use a font color that contrasts with the colored backgrounds.
    final textStyle = Theme.of(context).fixedFontStyle;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3.0),
      ),
      child: Text(
        kind,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      ),
    );
  }
}

class _MessageCell extends StatelessWidget {
  const _MessageCell({Key key, @required this.item}) : super(key: key);

  final LogData item;

  @override
  Widget build(BuildContext context) {
    final String displayValue =  item.summary ?? item.details;
    final TextStyle textStyle = Theme.of(context).fixedFontStyle;

    if (item.kind == 'flutter.frame') {
      const Color color = Color.fromARGB(0xff, 0x00, 0x91, 0xea);
      final Text text = Text(
        displayValue,
        overflow: TextOverflow.ellipsis,
        style: textStyle,
      );

      double frameLength = 0.0;
      try {
        final int micros = jsonDecode(item.details)['elapsed'];
        frameLength = micros * 3.0 / 1000.0;
      } catch (e) {
        // ignore
      }

      return Row(
        children: <Widget>[
          text,
          Flexible(
            child: Container(
              height: 12.0,
              width: frameLength,
              decoration: const BoxDecoration(color: color),
            ),
          ),
        ],
      );
    } else if (item.kind == 'stdout') {
      return RichText(
        text: TextSpan(
          children: processAnsiTerminalCodes(
            // TODO(helin24): Recompute summary length considering ansi codes.
            //  The current summary is generally the first 200 chars of details.
            displayValue,
            textStyle,
          ),
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    } else {
      return Container();
    }
  }
}
