// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import '../../../../../../shared/common_widgets.dart';
import '../../../../shared/heap/model.dart';
import '../../controller/simple_controllers.dart';

class RetainingPathView extends StatelessWidget {
  const RetainingPathView({
    super.key,
    required this.path,
    required this.controller,
  });

  final ClassOnlyHeapPath path;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PathControlPane(
          controller: controller,
          path: path,
        ),
        Expanded(child: _PathView(path: path, controller: controller)),
      ],
    );
  }
}

class _PathControlPane extends StatefulWidget {
  const _PathControlPane({required this.controller, required this.path});

  final ClassOnlyHeapPath path;
  final RetainingPathController controller;

  @override
  State<_PathControlPane> createState() => _PathControlPaneState();
}

class _PathControlPaneState extends State<_PathControlPane> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CopyToClipboardControl(
          dataProvider: () => widget.path.asLongString(),
        ),
      ],
    );
  }
}

class _PathView extends StatelessWidget {
  const _PathView({required this.path, required this.controller});

  final ClassOnlyHeapPath path;
  final RetainingPathController controller;

  @override
  Widget build(BuildContext context) {
    return Text(path.asLongString());
  }
}
