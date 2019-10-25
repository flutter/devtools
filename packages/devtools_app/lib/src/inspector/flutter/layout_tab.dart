import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../inspector/inspector_text_styles.dart' as inspector_text_styles;
import '../diagnostics_node.dart';
import '../inspector_tree.dart';

class InspectorDetailsTabController extends StatelessWidget {
  const InspectorDetailsTabController({this.detailsTree, Key key})
    : super(key: key);

  final Widget detailsTree;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          const TabBar(
            tabs: [
              Tab(text: 'Details Tree'),
              Tab(text: 'Layout Details'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                detailsTree,
                Container(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// TODO(albertusangga): Remove this linter ignore
// ignore: must_be_immutable
class StoryOfYourFlexWidget extends StatelessWidget {
  StoryOfYourFlexWidget(this.node, {
    Key key,
  }) : super(key: key) {
    properties = FlexProperties.fromJson(node.diagnostic.flexDetails);
  }

  final InspectorTreeNode node;

  // Deserialized information about Flex elements
  FlexProperties properties;

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [
      for (RemoteDiagnosticsNode child in node.diagnostic.childrenNow)
        Expanded(
          flex: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Theme
                .of(context)
                .backgroundColor,
              border: Border.all(
                color: Theme
                  .of(context)
                  .primaryColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme
                    .of(context)
                    .primaryColor,
                  offset: Offset.zero,
                  blurRadius: 10.0,
                )
              ],
            ),
            child: Center(
              child: Text(child.description),
            )),
        )
    ];
    final Widget flexWidget = properties.type == Row
      ? Row(children: children)
      : Column(children: children);
    final String flexWidgetName = properties.type.toString();
    return Dialog(
      child: Container(
        margin: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                'Story of the flex layout of your $flexWidgetName widget',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20.0,
                )),
            ),
            Expanded(
              child: Container(
                color: Theme
                  .of(context)
                  .primaryColor,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        flexWidgetName,
                        style: inspector_text_styles.regularBold,
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(16.0),
                          child: flexWidget)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@immutable
class FlexProperties {
  const FlexProperties({
                         this.direction,
                         this.mainAxisAlignment,
                         this.mainAxisSize,
                         this.crossAxisAlignment,
                         this.textDirection,
                         this.verticalDirection,
                         this.textBaseline,
                         this.size,
                       });

  final Axis direction;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection textDirection;
  final VerticalDirection verticalDirection;
  final TextBaseline textBaseline;
  final Size size;

  // TODO(albertusangga): Research better way to serialzie & deserialize enum value in Dart
  static Object enumFromString(List<Object> enumValues,
                               String enumToStringValue) {
    return enumValues.firstWhere(
        (enumValue) => enumValue.toString() == enumToStringValue,
      orElse: () => null,
    );
  }

  /// Deserialize Flex properties from DiagnosticsNode to actual object
  static FlexProperties fromJson(Map<String, Object> data) {
    final Map<String, dynamic> sizeJson = data['size'];
    final Size size =
    sizeJson == null || sizeJson['height'] == null || sizeJson['width'] == null
      ? null
      : Size(sizeJson['width'], sizeJson['height']);
    return FlexProperties(
      direction: enumFromString(Axis.values, data['direction']),
      mainAxisAlignment: enumFromString(
        MainAxisAlignment.values, data['mainAxisAlignment']),
      mainAxisSize: enumFromString(MainAxisSize.values, data['mainAxisSize']),
      crossAxisAlignment: enumFromString(
        CrossAxisAlignment.values, data['crossAxisAlignment']),
      textDirection: enumFromString(
        TextDirection.values, data['textDirection']),
      verticalDirection: enumFromString(
        VerticalDirection.values, data['verticalDirection']),
      textBaseline: enumFromString(TextBaseline.values, data['textBaseline']),
      size: size,
    );
  }

  Type get type => direction == Axis.horizontal ? Row : Column;
}

