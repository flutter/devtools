import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../inspector/inspector_text_styles.dart' as inspector_text_styles;
import '../diagnostics_node.dart';
import 'inspector_tree_flutter.dart';
import 'layout_models.dart';

class InspectorDetailsTabController extends StatelessWidget {
  const InspectorDetailsTabController(
      {this.detailsTree, this.controller, Key key})
      : super(key: key);

  final InspectorTreeControllerFlutter controller;
  final Widget detailsTree;

  @override
  Widget build(BuildContext context) {
    final enableStoryOfLayout =
        controller?.isExperimentalStoryOfLayoutEnabled ?? false;
    final tabs = <Widget>[
      const Tab(text: 'Details Tree'),
      if (enableStoryOfLayout) const Tab(text: 'Layout Details')
    ];
    final tabViews = <Widget>[
      detailsTree,
      if (enableStoryOfLayout) Container(),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: <Widget>[
          TabBar(
            isScrollable: false,
            labelPadding: const EdgeInsets.only(right: 10.0, left: 10.0),
            tabs: tabs,
          ),
          Expanded(
            child: TabBarView(
              children: tabViews,
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
class StoryOfYourFlexWidget extends StatelessWidget {
  const StoryOfYourFlexWidget({
    this.diagnostic,
    this.properties,
    Key key,
  }) : super(key: key);

  final RemoteDiagnosticsNode diagnostic;

  // Information about Flex elements that has been deserialize
  final FlexProperties properties;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<Widget> children = [
      for (var child in diagnostic.childrenNow)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              border: Border.all(
                color: theme.primaryColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor,
                  offset: Offset.zero,
                  blurRadius: 10.0,
                )
              ],
            ),
            child: Center(
              child: Text(child.description),
            ),
          ),
        ),
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
                color: Theme.of(context).primaryColor,
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
                            child: flexWidget),
                      ),
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
