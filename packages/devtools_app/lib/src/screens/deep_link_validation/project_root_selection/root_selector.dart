// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../../shared/common_widgets.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/utils.dart';

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
    return _FlexibleProjectSelectionView(
      selectedProjectRoot: currentText.isEmpty ? null : currentText,
      onValidatePressed: widget.onValidatePressed,
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
    return _FlexibleProjectSelectionView(
      selectedProjectRoot: selectedUri?.path.trim(),
      onValidatePressed: widget.onValidatePressed,
      child: RoundedDropDownButton<Uri>(
        isDense: true,
        isExpanded: true,
        value: selectedUri,
        items: [
          for (final uri in widget.projectRoots) _buildMenuItem(uri),
        ],
        onChanged: (uri) => setState(() {
          selectedUri = uri;
        }),
      ),
    );
  }

  DropdownMenuItem<Uri> _buildMenuItem(Uri uri) {
    return DropdownMenuItem<Uri>(
      value: uri,
      child: DevToolsTooltip(
        message: uri.path,
        waitDuration: tooltipWaitExtraLong,
        child: Text(
          uri.path,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _FlexibleProjectSelectionView extends StatelessWidget {
  const _FlexibleProjectSelectionView({
    required this.selectedProjectRoot,
    required this.onValidatePressed,
    required this.child,
  });

  final String? selectedProjectRoot;
  final void Function(String) onValidatePressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = ScreenSize(context).width;
    final showButtonInRow = screenWidth > MediaSize.xs;

    final button = _ValidateDeepLinksButton(
      projectRoot: selectedProjectRoot,
      onValidatePressed: onValidatePressed,
    );

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Flexible(
          flex: 8,
          fit: FlexFit.tight,
          child: child,
        ),
        if (showButtonInRow) ...[
          const SizedBox(width: defaultSpacing),
          button,
        ],
        const Spacer(),
      ],
    );

    // If the button is not in the [content] [Row], place the button below
    // [content] in a [Column].
    if (!showButtonInRow) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          content,
          const SizedBox(height: defaultSpacing),
          button,
        ],
      );
    }

    return content;
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
