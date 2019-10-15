// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_widgets/flutter_widgets.dart';

/// Convenience [Divider] with [Padding] that provides a good divider in forms.
class PaddedDivider extends StatelessWidget {
  const PaddedDivider({
    Key key,
    this.padding = const EdgeInsets.only(bottom: 10.0),
  }) : super(key: key);

  /// The padding to place around the divider.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Divider(thickness: 1.0),
    );
  }
}

/// A [TaggedText] with builtin DevTools-specific text styling.
///
/// This widget is a wrapper around Flutter's [RichText]. It's an alternative
/// to that for richly-formatted text. The performance is roughly the same,
/// and it will throw assertion errors in any cases where the text isn't
/// parsed properly.
///
/// The xml styling is much easier to read than creating multiple [TextSpan]s
/// in a [RichText].  For example, the following are equivalent text
/// presentations:
///
/// ```dart
/// var taggedText = DefaultTaggedText(
///   '<bold>bold text</bold>\n'
///   'normal text',
/// );
///
/// var richText = RichText(
///   style
///   text: TextSpan(
///     text: '',
///     style: DefaultTextStyle.of(context)
///     children: [
///       TextSpan(
///         text: 'bold text',
///         style: DefaultTextStyle.of(context).copyWith(fontWeight: FontWeight.w600),
///       ),
///       TextSpan(
///         text: '\nnormal text',
///       )
///     ],
///   ),
/// );
/// ```
///
/// The [TaggedText] abstraction separates the styling from the content
/// of the rich strings we show in the UI.
///
/// The [TaggedText] also has the benefit of being localizable by a
/// human translator. The content is passed in to Flutter as a single
/// string, and the xml markup is understood by many translators.
class DefaultTaggedText extends StatelessWidget {
  const DefaultTaggedText(
    this.content, {
    this.textAlign = TextAlign.start,
    Key key,
  }) : super(key: key);

  /// The XML-markup string to show.
  final String content;

  /// See [TaggedText.textAlign].
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = DefaultTextStyle.of(context).style;
    final _tagToTextSpanBuilder = {
      'bold': (text) => TextSpan(
            text: text,
            style: defaultTextStyle.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
      'primary-color': (text) => TextSpan(
            text: text,
            style: defaultTextStyle.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.w400,
            ),
          ),
      'primary-color-light': (text) => TextSpan(
            text: text,
            style: defaultTextStyle.copyWith(
              color: theme.primaryColorLight,
              fontWeight: FontWeight.w300,
            ),
          ),
    };
    return TaggedText(
      content: content,
      tagToTextSpanBuilder: _tagToTextSpanBuilder,
      overflow: TextOverflow.visible,
      textAlign: textAlign,
      style: defaultTextStyle,
    );
  }
}

abstract class CollapsingData {
  const CollapsingData();

  List<CollapsingData> get children;

  /// The depth of this data in the nested hierarchy.
  int get depth;

  void sort(int Function(CollapsingData d1, CollapsingData d2) comparator) {
    children.sort(comparator);
    for (var c in children) {
      c.sort(comparator);
    }
  }
}

class CollapsingTableColumn<T extends CollapsingData> {
  const CollapsingTableColumn(
      {@required this.buildHeader,
      @required this.build,
      @required this.comparator});

  final Widget Function(BuildContext context, Widget sortIndicator) buildHeader;
  final Widget Function(BuildContext context, T data) build;
  final int Function(T data1, T data2) comparator;
}

class CollapsingTable<T extends CollapsingData> extends StatefulWidget {
  const CollapsingTable({Key key, this.columns, this.data}) : super(key: key);

  final List<CollapsingTableColumn<T>> columns;
  final List<T> data;

  @override
  CollapsingTableState<T> createState() => CollapsingTableState<T>();
}

class CollapsingTableState<T extends CollapsingData>
    extends State<CollapsingTable<T>> {
  bool sortDescending = true;
  int sortColumn = 0;

  void _updateSorting(int column) {
    setState(() {
      if (column != sortColumn) {
        sortDescending = true;
        sortColumn = column;
      } else {
        sortDescending = !sortDescending;
      }
    });
    sort();
  }

  void sort() {
    setState(() {
      for (T element in widget.data) {
        final comparator = widget.columns[sortColumn].comparator;
        element.sort(
          sortDescending ? comparator : (d1, d2) => comparator(d2, d1),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final headerColumns = <Widget>[];
    for (var i = 0; i < widget.columns.length; i++) {
      final column = widget.columns[i];
      Widget sortIndicator = const SizedBox();
      if (i == sortColumn) {
        sortIndicator = sortDescending
            ? Icon(Icons.arrow_drop_down)
            : Icon(Icons.arrow_drop_up);
      }
      headerColumns.add(
        Expanded(
          child: InkWell(
            onTap: () => _updateSorting(i),
            child: column.buildHeader(context, sortIndicator),
          ),
        ),
      );
    }
    final header = Material(
      child: Row(
        children: headerColumns,
      ),
    );
    return Column(children: [
      header,
      ListView.builder(
        itemBuilder: (context, index) => _buildRow(context, widget.data[index]),
        itemCount: widget.data.length,
        shrinkWrap: true,
      ),
    ]);
  }

  Widget _buildRow(BuildContext context, T item) {
    return CollapsingListItem(
      content: Material(
        key: ValueKey(item),
        child: Row(children: [
          for (var column in widget.columns) column.build(context, item)
        ]),
      ),
      children: [for (var child in item.children) _buildRow(context, child)],
    );
  }
}

class CollapsingListItem extends StatefulWidget {
  const CollapsingListItem(
      {Key key, @required this.content, this.children = const []})
      : super(key: key);

  final Widget content;
  final List<Widget> children;
  @override
  CollapsingListItemState createState() => CollapsingListItemState();
}

class CollapsingListItemState extends State<CollapsingListItem>
    with TickerProviderStateMixin {
  bool collapsed = true;
  AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    controller.dispose();
  }

  void toggle() {
    setState(() {
      collapsed = !collapsed;
      if (!collapsed) {
        controller.forward();
      } else {
        controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          child: widget.content,
          onTap: toggle,
        ),
        SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: controller,
            curve: Curves.easeInOutCubic,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.children,
          ),
        ),
      ],
    );
  }
}
