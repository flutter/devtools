import 'package:flutter/material.dart';

/// A page in the DevTools App, including the scaffolding and navigation tabs
/// for navigating the app.
///
/// This widget is used by encapsulation instead of inheritance, so to add a
/// FooPage to the app, you'll create a FooPage widget like so:
///
/// ```dart
/// class FooPage extends StatelessWidget {
///   @override
///   Widget build(BuildContext context) {
///     return Page(
///       child: /* Build out the page content */,
///     )
///   }
/// }
/// ```
///
/// For a sample implementation, see [ConnectPage].
class Screen extends StatefulWidget {
  static const Key narrowWidth = Key('Narrow Page');
  static const Key fullWidth = Key('Full-width Page');

  /// The width where we need to treat the page as narrow-width.
  static const double narrowPageWidth = 800.0;
  const Screen({Key key, @required this.child})
      : assert(child != null),
        super(key: key);

  final Widget child;

  @override
  State<StatefulWidget> createState() => ScreenState();
}

class ScreenState extends State<Screen> with TickerProviderStateMixin {
  TabController controller;

  @override
  void initState() {
    super.initState();
    controller = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(),
      body: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: widget.child,
        ),
      ),
    );
  }

  /// Builds an [AppBar] with the [TabBar] placed on the side or the bottom,
  /// depending on the screen width.
  Widget buildAppBar() {
    final tabs = TabBar(
      controller: controller,
      isScrollable: true,
      tabs: <Widget>[
        Tab(
          text: 'Flutter Inspector',
          icon: Icon(Icons.map),
        ),
        Tab(
          text: 'Timeline',
          icon: Icon(Icons.timeline),
        ),
        Tab(
          text: 'Performance',
          icon: Icon(Icons.computer),
        ),
        Tab(
          text: 'Memory',
          icon: Icon(Icons.memory),
        ),
        Tab(
          text: 'Logging',
          icon: Icon(Icons.directions_run),
        ),
      ],
    );
    if (MediaQuery.of(context).size.width <= Screen.narrowPageWidth) {
      return AppBar(
        key: Screen.narrowWidth,
        title: const Text('Dart DevTools'),
        bottom: tabs,
      );
    }
    return AppBar(
      key: Screen.fullWidth,
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Dart DevTools'),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, left: 32.0, right: 32.0),
            child: tabs,
          ),
        ],
      ),
    );
  }
}
