import 'package:flutter/widgets.dart';

import '../controller/diff_pane_controller.dart';

/// Base widget that simplifies access to diff data for the code in widget state.
abstract class DiffWidget extends StatefulWidget {
  const DiffWidget({Key? key, required this.diffController}) : super(key: key);

  final DiffPaneController diffController;
}

abstract class DiffWidgetState<T extends DiffWidget> extends State<T> {
  late CoreData diffCore;
  late DerivedData diffDerived;
  late DiffPaneController diffController;

  @override
  void initState() {
    super.initState();
    _initWidget();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diffController != widget.diffController) _initWidget();
  }

  void _initWidget() {
    diffController = widget.diffController;
    diffCore = widget.diffController.data.core;
    diffDerived = widget.diffController.data.derived;
  }
}
