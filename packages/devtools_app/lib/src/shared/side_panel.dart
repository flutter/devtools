// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'config_specific/launch_url/launch_url.dart';
import 'primitives/utils.dart';

class SidePanelViewer extends StatefulWidget {
  const SidePanelViewer({
    super.key,
    required this.controller,
    this.title,
    this.textIfMarkdownDataEmpty,
    this.child,
  });

  final SidePanelController controller;
  final String? title;
  final String? textIfMarkdownDataEmpty;
  final Widget? child;

  @override
  SidePanelViewerState createState() => SidePanelViewerState();
}

class SidePanelViewerState extends State<SidePanelViewer>
    with AutoDisposeMixin, SingleTickerProviderStateMixin {
  static const maxViewerWidth = 600.0;

  /// Animation controller for animating the opening and closing of the viewer.
  late AnimationController visibilityController;

  /// A curved animation that matches [visibilityController].
  late Animation<double> visibilityAnimation;

  String? markdownData;

  late bool isVisible;

  @override
  void initState() {
    super.initState();

    visibilityController = longAnimationController(this);
    visibilityAnimation =
        Tween<double>(begin: 1.0, end: 0).animate(visibilityController);

    _initListeners();
  }

  @override
  void didUpdateWidget(SidePanelViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.isVisible.value != isVisible ||
        oldWidget.controller.markdown.value != markdownData) {
      cancelListeners();
      _initListeners();
    }
  }

  void _initListeners() {
    isVisible = widget.controller.isVisible.value;

    addAutoDisposeListener(widget.controller.isVisible, () {
      setState(() {
        isVisible = widget.controller.isVisible.value;
        if (isVisible) {
          visibilityController.forward();
        } else {
          visibilityController.reverse();
        }
      });
    });

    markdownData = widget.controller.markdown.value;
    addAutoDisposeListener(widget.controller.markdown, () {
      setState(() {
        markdownData = widget.controller.markdown.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return Material(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widthForSmallScreen = constraints.maxWidth - 2 * densePadding;
          final width = min(
            SidePanelViewerState.maxViewerWidth,
            widthForSmallScreen,
          );
          return Stack(
            children: [
              if (child != null) child,
              SidePanel(
                sidePanelController: widget.controller,
                visibilityAnimation: visibilityAnimation,
                title: widget.title,
                markdownData: markdownData,
                textIfMarkdownDataEmpty: widget.textIfMarkdownDataEmpty,
                width: width,
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    visibilityController.dispose();
    super.dispose();
  }
}

class SidePanel extends AnimatedWidget {
  const SidePanel({
    super.key,
    required this.sidePanelController,
    required Animation<double> visibilityAnimation,
    this.title,
    this.markdownData,
    this.textIfMarkdownDataEmpty,
    required this.width,
  }) : super(listenable: visibilityAnimation);

  final SidePanelController sidePanelController;

  final String? title;
  final String? markdownData;
  final String? textIfMarkdownDataEmpty;
  final double width;

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final theme = Theme.of(context);
    final displacement = width * animation.value;
    final right = densePadding - displacement;
    return Positioned(
      top: densePadding,
      bottom: densePadding,
      right: right,
      width: width,
      child: Card(
        elevation: defaultElevation,
        color: theme.scaffoldBackgroundColor,
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
          side: BorderSide(
            color: theme.focusColor,
          ),
        ),
        child: Column(
          children: [
            AreaPaneHeader(
              title: Text(title ?? ''),
              includeTopBorder: false,
              actions: [
                IconButton(
                  padding: const EdgeInsets.all(0.0),
                  onPressed: () => sidePanelController.toggleVisibility(false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            markdownData.isNullOrEmpty
                ? Text(textIfMarkdownDataEmpty ?? '')
                : Expanded(
                    child: Markdown(
                      data: markdownData!,
                      onTapLink: (text, url, title) =>
                          unawaited(launchUrl(url!)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class SidePanelController {
  final markdown = ValueNotifier<String?>(null);

  ValueListenable<bool> get isVisible => _isVisible;

  final _isVisible = ValueNotifier<bool>(false);

  void toggleVisibility(bool visible) {
    _isVisible.value = visible;
  }
}
