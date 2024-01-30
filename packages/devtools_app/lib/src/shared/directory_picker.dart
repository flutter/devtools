// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

class DirectoryPicker extends StatefulWidget {
  const DirectoryPicker({
    required this.onDirectoryPicked,
    this.enabled = true,
    super.key,
  });

  final bool enabled;

  final ValueChanged<String> onDirectoryPicked;

  @override
  State<DirectoryPicker> createState() => _DirectoryPickerState();
}

class _DirectoryPickerState extends State<DirectoryPicker> {
  final TextEditingController controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Flexible(
          flex: 4,
          fit: FlexFit.tight,
          child: RoundedOutlinedBorder(
            child: Container(
              height: defaultTextFieldHeight,
              padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
              child: TextField(
                controller: controller,
                enabled: widget.enabled,
                onSubmitted: (String path) {
                  widget.onDirectoryPicked(path.trim());
                },
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Enter path to a Flutter project here',
                ),
                style: Theme.of(context).regularTextStyle,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }
}
