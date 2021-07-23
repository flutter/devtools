// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../table.dart';
import '../theme.dart';
import '../vm_service_utils.dart';

Widget stringValueBuilder<T>(BuildContext context, dynamic value) {
  final theme = Theme.of(context);
  return SelectableText(
    value?.toString() ?? '--',
    style: theme.fixedFontStyle,
  );
}

/// A convenience widget used to create non-scrollable information cards.
///
/// `title` is displayed as the header of the card and is required.
///
/// `rowKeyValues` takes a list of key-value pairs that are to be displayed as
/// individual rows. These rows will have an alternating background color.
///
/// `table` is a widget (typically a table) that is to be displayed after the
/// rows specified for `rowKeyValues`.
class VMInfoCard extends StatelessWidget {
  const VMInfoCard({
    @required this.title,
    this.rowKeyValues = const [],
    this.table,
  });

  final String title;
  final List<MapEntry> rowKeyValues;
  final Widget table;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: VMInfoList(
        title: title,
        rowKeyValues: rowKeyValues,
        table: table,
      ),
    );
  }
}

class VMInfoList extends StatelessWidget {
  const VMInfoList({
    @required this.title,
    this.rowKeyValues = const [],
    this.table,
  });

  final String title;
  final List<MapEntry> rowKeyValues;
  final Widget table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Row>[];

    for (final row in rowKeyValues) {
      final value = row?.value;
      Widget rowValue;
      if (value is Reference) {
        rowValue = value?.build(context);
      } else if (value is List<Reference>) {
        rowValue = Row(
          children: [
            for (final e in value) e.build(context),
          ],
        );
      } else {
        rowValue = SelectableText(
          value?.toString() ?? '--',
          style: theme.fixedFontStyle,
        );
      }
      rows.add(
        Row(
          children: [
            SelectableText(
              '${row.key.toString()}:',
              style: theme.fixedFontStyle,
            ),
            const SizedBox(width: denseSpacing),
            Flexible(child: rowValue),
          ],
        ),
      );
    }

    return Column(
      children: [
        AreaPaneHeader(
          title: Text(title),
          needsTopBorder: false,
        ),
        if (rowKeyValues != null)
          ..._prettyRows(
            context,
            rows,
          ),
        if (table != null) table,
      ],
    );
  }

  Widget valueBuilder(BuildContext context, dynamic value) {
    print(value.runtimeType);
    if (value is Iterable) {
      final elements = [for (final e in value) valueBuilder(context, e)];
      final separated = <Widget>[];
      const Text separator = Text(',');
      for (int i = 0; i < elements.length; ++i) {
        separated.add(elements[i]);
        if (i + 1 != elements.length) {
          separated.add(separator);
        }
      }
      return Row(
        children: separated,
      );
    } else if (value is Reference) {
      return value.build(context);
    } else {
      return stringValueBuilder(context, value);
    }
  }

  List<Widget> _prettyRows(BuildContext context, List<Row> rows) {
    return [
      for (int i = 0; i < rows.length; ++i)
        _buildAlternatingRow(context, i, rows[i]),
    ];
  }

  Widget _buildAlternatingRow(BuildContext context, int index, Widget row) {
    return Container(
      color: alternatingColorForIndex(index, Theme.of(context).colorScheme),
      height: defaultRowHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: defaultSpacing,
      ),
      child: row,
    );
  }
}

typedef ReferenceTapCallback = void Function(dynamic);

abstract class Reference<T> {
  const Reference({@required this.object, this.onTap});

  final T object;
  final ReferenceTapCallback onTap;

  Widget build(BuildContext context);

  Widget _buildStyledText(BuildContext context, String text) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SelectableText(
      text,
      style: theme.fixedFontStyle.apply(
        color: colorScheme.devtoolsLink,
        decoration: TextDecoration.underline,
      ),
      onTap: () {
        if (onTap != null) {
          onTap(object);
        }
      },
    );
  }
}

class ScriptReference extends Reference<Script> {
  const ScriptReference(
    this.script,
    this.clazz, {
    ReferenceTapCallback onTap,
  }) : super(
          object: script,
          onTap: onTap,
        );
  final Script script;
  final Class clazz;

  @override
  Widget build(BuildContext context) {
    final sourceInfo =
        SourcePosition.calculatePosition(script, clazz.location.tokenPos);
    return _buildStyledText(
      context,
      '${script.uri}:${sourceInfo.line}:${sourceInfo.column}',
    );
  }
}

class ClassReference extends Reference<ClassRef> {
  const ClassReference(
    this.clazz, {
    ReferenceTapCallback onTap,
  }) : super(
          object: clazz,
          onTap: onTap,
        );
  final ClassRef clazz;

  @override
  Widget build(BuildContext context) {
    return _buildStyledText(context, clazz.name);
  }
}

class LibraryReference extends Reference<LibraryRef> {
  const LibraryReference(
    this.library, {
    ReferenceTapCallback onTap,
  }) : super(
          object: library,
          onTap: onTap,
        );

  final LibraryRef library;

  @override
  Widget build(BuildContext context) {
    return _buildStyledText(context, library.name);
  }
}

class TypeReference extends Reference<InstanceRef> {
  const TypeReference(
    this.type, {
    ReferenceTapCallback onTap,
  }) : super(
          object: type,
          onTap: onTap,
        );
  final InstanceRef type;

  @override
  Widget build(BuildContext context) {
    return _buildStyledText(context, type.name);
  }
}

class MixinReference extends Reference<InstanceRef> {
  const MixinReference(
    this.mixin, {
    ReferenceTapCallback onTap,
  }) : super(
          object: mixin,
          onTap: onTap,
        );
  final InstanceRef mixin;

  @override
  Widget build(BuildContext context) {
    return _buildStyledText(context, mixin.name);
  }
}
