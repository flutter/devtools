// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../shared/common_widgets.dart';
import '../../../shared/primitives/utils.dart';

class ProjectRootTextField extends StatefulWidget {
  const ProjectRootTextField({
    required this.onValidatePressed,
    this.enabled = true,
    super.key,
  });

  final bool enabled;

  final void Function(String) onValidatePressed;

  @override
  State<ProjectRootTextField> createState() => _ProjectRootTextFieldState();
}

class _ProjectRootTextFieldState extends State<ProjectRootTextField>
    with AutoDisposeMixin {
  final controller = TextEditingController();

  late String currentText;

  @override
  void initState() {
    super.initState();
    currentText = controller.text;
    addAutoDisposeListener(controller, () {
      setState(() {
        currentText = controller.text.trim();
      });
    });
  }

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
          child: Container(
            height: defaultTextFieldHeight,
            padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
            child: DevToolsClearableTextField(
              controller: controller,
              enabled: widget.enabled,
              onSubmitted: (String path) {
                widget.onValidatePressed(path.trim());
              },
              labelText: 'Path to Flutter project',
              roundedBorder: true,
            ),
          ),
        ),
        const SizedBox(width: defaultSpacing),
        _ValidateDeepLinksButton(
          projectRoot: currentText.isEmpty ? null : currentText,
          onValidatePressed: widget.onValidatePressed,
        ),
        const Spacer(),
      ],
    );
  }
}

class ProjectRootsDropdown extends StatefulWidget {
  ProjectRootsDropdown({
    required this.projectRoots,
    required this.onValidatePressed,
    super.key,
  }) : assert(projectRoots.isNotEmpty);

  final List<Uri> projectRoots;

  final void Function(String) onValidatePressed;

  @override
  State<ProjectRootsDropdown> createState() => _ProjectRootsDropdownState();
}

class _ProjectRootsDropdownState extends State<ProjectRootsDropdown> {
  Uri? selectedUri;

  @override
  void initState() {
    super.initState();
    selectedUri = widget.projectRoots.safeFirst;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RoundedDropDownButton<Uri>(
          value: selectedUri,
          items: [
            for (final uri in widget.projectRoots) _buildMenuItem(uri),
          ],
          onChanged: (uri) => setState(() {
            selectedUri = uri;
          }),
        ),
        const SizedBox(width: defaultSpacing),
        _ValidateDeepLinksButton(
          projectRoot: selectedUri?.path.trim(),
          onValidatePressed: widget.onValidatePressed,
        ),
      ],
    );
  }

  DropdownMenuItem<Uri> _buildMenuItem(Uri uri) {
    return DropdownMenuItem<Uri>(
      value: uri,
      child: Text(uri.path),
    );
  }
}

class _ValidateDeepLinksButton extends StatelessWidget {
  const _ValidateDeepLinksButton({
    required this.projectRoot,
    required this.onValidatePressed,
  });

  final String? projectRoot;
  final void Function(String) onValidatePressed;

  @override
  Widget build(BuildContext context) {
    return DevToolsButton(
      elevated: true,
      label: 'Validate deep links',
      onPressed:
          projectRoot == null ? null : () => onValidatePressed(projectRoot!),
    );
  }
}
